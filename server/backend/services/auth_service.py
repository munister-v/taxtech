"""Сервіс автентифікації та реєстрації."""
from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timezone

from ..config import ACCOUNT_PREFIX, APPLE_CLIENT_ID, CURRENCY_LABEL
from . import apple_auth
from ..repositories.account_repository import AccountRepository
from ..repositories.feature_repository import FeatureRepository
from ..repositories.user_repository import UserRepository
from ..utils.security import (
    generate_token, hash_password, token_expiration_iso, verify_password
)
from ..utils.validators import require_fields, validate_email, validate_password, validate_phone


class AuthService:
    def __init__(self) -> None:
        self.users = UserRepository()
        self.accounts = AccountRepository()
        self.features = FeatureRepository()

    def _build_unique_account_number(self, user_id: int) -> str:
        base = f"{ACCOUNT_PREFIX}{100000 + int(user_id)}"
        if not self.accounts.get_account_by_number(base):
            return base
        for i in range(1, 1000):
            candidate = f"{base}-{i:03d}"
            if not self.accounts.get_account_by_number(candidate):
                return candidate
        raise ValueError('Не вдалося згенерувати унікальний номер рахунку.')

    def ensure_user_bank_account(self, user_id: int) -> tuple[dict, bool]:
        account = self.accounts.get_account_by_user_id(user_id)
        if account:
            return account, False

        account_number = self._build_unique_account_number(user_id)
        self.accounts.create_account(user_id, account_number)
        self.features.add_audit_log(
            user_id,
            'auto_account_link',
            f'Автоматично створено основний рахунок у пісочниці ({CURRENCY_LABEL}).',
        )
        account = self.accounts.get_account_by_user_id(user_id)
        if not account:
            raise ValueError('Не вдалося створити основний рахунок користувача.')
        return account, True

    # ── Реєстрація ────────────────────────────────────────────────────────────
    def register(self, data: dict, client_info: dict | None = None) -> dict:
        require_fields(data, ['full_name', 'phone', 'email', 'password'])
        validate_phone(data['phone'])
        validate_email(data['email'])
        validate_password(data['password'])

        phone = data['phone'].strip()
        email = data['email'].strip().lower()

        if self.users.get_by_phone_or_email(phone) or self.users.get_by_phone_or_email(email):
            raise ValueError('Користувач з таким телефоном або email вже існує.')

        user_id = self.users.create_user(
            full_name=data['full_name'].strip(),
            phone=phone,
            email=email,
            password_hash=hash_password(data['password']),
        )
        self.ensure_user_bank_account(user_id)
        self.features.add_audit_log(user_id, 'register', 'Створено обліковий запис та рахунок у пісочниці (віртуальні гривні).')
        return self.login({
            'identity': phone,
            'password': data['password'],
            'remember': data.get('remember', True),
        }, client_info=client_info)

    # ── Вхід ──────────────────────────────────────────────────────────────────
    def login(self, data: dict, client_info: dict | None = None) -> dict:
        require_fields(data, ['identity', 'password'])
        identity = data['identity'].strip()
        user = self.users.get_by_phone_or_email(identity)
        if not user or not verify_password(data['password'], user['password_hash']):
            raise ValueError('Невірні облікові дані.')

        return self._start_session(user, client_info, auth_method='password',
                                   remember=bool(data.get('remember', True)), audit='Успішний вхід у систему.')

    def _start_session(self, user, client_info: dict | None, *, auth_method: str, remember: bool, audit: str) -> dict:
        """Відкриває сесію для вже перевіреного користувача і формує відповідь входу."""
        # Видаляємо прострочені сесії цього користувача (cleanup)
        self.users.delete_expired_sessions(user['id'])
        account, auto_created = self.ensure_user_bank_account(user['id'])

        token = generate_token()
        client_info = client_info or {}
        self.users.create_session(
            user['id'],
            token,
            token_expiration_iso(),
            user_agent=client_info.get('user_agent', ''),
            ip_address=client_info.get('ip_address', ''),
            auth_method=auth_method,
            remembered=remember,
        )
        self.features.add_audit_log(user['id'], 'login', audit)

        bank_notice = None
        if auto_created:
            bank_notice = f'Рахунок у пісочниці створено автоматично ({CURRENCY_LABEL}).'
        return {
            'token': token,
            'user': {
                'id': user['id'],
                'full_name': user['full_name'],
                'phone': user['phone'],
                'email': user['email'],
                'role': user['role'],
                'bank_account_linked': bool(account),
                'bank_account_number': account.get('account_number') if account else None,
            },
            'bank_notice': bank_notice,
        }

    # ── Вхід і реєстрація через Apple ─────────────────────────────────────────
    def login_with_apple(self, data: dict, client_info: dict | None = None, *, key_resolver=None) -> dict:
        """Перший вхід через Apple створює користувача й рахунок у пісочниці, наступні - входять.

        Користувача впізнаємо за `sub` з токена Apple. Окремої колонки немає: `sub` лежить у
        phone як «apple:<sub>», пароль - випадковий і нікому не відомий.
        """
        claims = apple_auth.verify_identity_token(
            str(data.get('identity_token') or ''),
            str(data.get('nonce') or ''),
            audience=APPLE_CLIENT_ID,
            key_resolver=key_resolver,
        )
        key = f"apple:{claims['sub']}"
        user = self.users.get_by_phone_or_email(key)
        created = False
        if not user:
            email = str(claims.get('email') or '').strip().lower()
            if not email or self.users.get_by_phone_or_email(email):
                # Apple не віддала пошту або вона вже в іншому акаунті - не зв'язуємо акаунти мовчки
                email = f"apple-{hashlib.sha256(key.encode()).hexdigest()[:16]}@users.kopiyka.invalid"
            name = str(data.get('full_name') or '').strip()[:120] or 'Користувач Apple'
            user_id = self.users.create_user(
                full_name=name, phone=key, email=email,
                password_hash=hash_password(secrets.token_urlsafe(32)),
            )
            self.ensure_user_bank_account(user_id)
            self.features.add_audit_log(user_id, 'register', 'Створено обліковий запис через Apple та рахунок у пісочниці.')
            user = self.users.get_by_id(user_id)
            created = True
        payload = self._start_session(user, client_info, auth_method='apple', remember=True,
                                      audit='Вхід через Apple.')
        payload['created'] = created
        return payload

    # ── Видалення облікового запису ──────────────────────────────────────────
    def delete_account(self, user_id: int) -> None:
        """Видаляє користувача з усіма даними (рахунок, операції, картки, сесії) - вимога App Store."""
        self.users.delete_user(user_id)

    # ── Перевірка токену ──────────────────────────────────────────────────────
    def get_user_by_token(self, token: str):
        user = self.users.get_user_by_token(token)
        if not user:
            return None
        expires_at_raw = user.get('expires_at', '')
        try:
            # PostgreSQL повертає datetime об'єкт, SQLite — рядок ISO
            if isinstance(expires_at_raw, datetime):
                expires_at = expires_at_raw
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
            else:
                expires_at = datetime.fromisoformat(str(expires_at_raw))
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
        except (ValueError, TypeError):
            self.users.delete_session(token)
            return None
        if expires_at < datetime.now(timezone.utc):
            self.users.delete_session(token)
            return None
        return user

    # ── Автооновлення сесії ───────────────────────────────────────────────────
    def refresh_session(self, old_token: str, user_id: int) -> str | None:
        """Продовжує поточну сесію без ротації токена.

        Це прибирає race-condition для паралельних запитів одним токеном:
        один запит не інвалідує токен для іншого запиту в цей же момент.
        """
        try:
            expires_at = token_expiration_iso()
            ok = self.users.update_session_expiry(old_token, expires_at)
            return old_token if ok else None
        except Exception:
            return None

    # ── Вихід ─────────────────────────────────────────────────────────────────
    def logout(self, token: str) -> None:
        self.users.delete_session(token)

    def list_sessions(self, user_id: int, current_token: str) -> list:
        sessions = self.users.list_sessions(user_id)
        current_fingerprint = 'sha256:' + hashlib.sha256(current_token.encode('utf-8')).hexdigest()
        result = []
        for s in sessions:
            d = dict(s)
            d['is_current'] = d.get('token') in (current_token, current_fingerprint)
            d.pop('token', None)  # don't expose token
            result.append(d)
        return result

    def revoke_other_sessions(self, user_id: int, current_token: str) -> int:
        return self.users.delete_other_sessions(user_id, current_token)

    def revoke_session(self, session_id: int, user_id: int) -> None:
        ok = self.users.delete_session_by_id(session_id, user_id)
        if not ok:
            raise ValueError('Сесію не знайдено.')

    def change_password(self, user_id: int, old_password: str, new_password: str) -> None:
        validate_password(new_password)
        user = self.users.get_by_id(user_id)
        if not user:
            raise ValueError('Користувача не знайдено.')
        if not verify_password(old_password, user['password_hash']):
            raise ValueError('Поточний пароль невірний.')
        new_hash = hash_password(new_password)
        self.users.update_password(user_id, new_hash)
        self.features.add_audit_log(user_id, 'change_password', 'Пароль змінено.')
