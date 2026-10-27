"""Вхід через Apple: перевірка identity token (JWT, RS256) за публічними ключами Apple."""
from __future__ import annotations

import hashlib
from typing import Callable

import jwt
from jwt import PyJWKClient

APPLE_ISSUER = 'https://appleid.apple.com'
APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys'

_jwks: PyJWKClient | None = None


def _apple_key(token: str):
    """Ключ підпису з JWKS Apple; PyJWKClient кешує набір ключів на годину."""
    global _jwks
    if _jwks is None:
        _jwks = PyJWKClient(APPLE_JWKS_URL, cache_keys=True, lifespan=3600)
    return _jwks.get_signing_key_from_jwt(token).key


def verify_identity_token(
    token: str,
    raw_nonce: str,
    *,
    audience: str,
    key_resolver: Callable[[str], object] | None = None,
) -> dict:
    """Перевіряє підпис, видавця, одержувача (bundle id), строк дії й nonce.

    Клієнт кладе в запит Apple SHA-256 від випадкового nonce, а серверу шле сам nonce:
    так вкрадений токен не можна використати повторно в іншому запиті входу.
    Повертає claims (sub - стабільний ідентифікатор користувача, email - якщо Apple його дала).
    """
    if not token or not raw_nonce:
        raise ValueError('Не передано токен Apple.')
    try:
        claims = jwt.decode(
            token,
            (key_resolver or _apple_key)(token),
            algorithms=['RS256'],
            audience=audience,
            issuer=APPLE_ISSUER,
            options={'require': ['exp', 'iat', 'iss', 'aud', 'sub']},
        )
    except jwt.PyJWTError as exc:
        raise ValueError('Токен Apple не пройшов перевірку.') from exc
    except Exception as exc:  # мережа до Apple, невідомий kid тощо
        raise ValueError('Не вдалося перевірити токен Apple.') from exc

    expected = hashlib.sha256(raw_nonce.encode()).hexdigest()
    if claims.get('nonce') != expected:
        raise ValueError('Токен Apple не пройшов перевірку.')
    return claims
