"""Дослідницький сервіс: edge vs cloud для AI-задач персонального фінансового асистента.

Тут зосереджена логіка трьох «хмарних» вимірювань, які iOS-клієнт
порівнює з виконанням на пристрої:

  * FraudResearchService — серверний скоринг FraudEngine з вибором шарів
    (l1 ≈ те, що реально порахувати на iPhone; l1+l2+l3 — повний серверний);
  * LLMResearchService   — виклик Anthropic Messages API з ЗАФІКСОВАНИМИ
    моделями (small / large) для задач support / scam_check / receipt;
  * echo/ping не мають бізнес-логіки й живуть прямо в research_routes.

Гроші в пісочниці віртуальні (TAX), тож скоринг нічого не блокує —
це лише вимірювання.
"""
from __future__ import annotations

from typing import Optional

from ..config import (
    ANTHROPIC_API_KEY,
    LLM_EFFORT,
    LLM_MAX_PROMPT_CHARS,
    LLM_MAX_TOKENS,
    LLM_MODEL_LARGE,
    LLM_MODEL_SMALL,
    LLM_TIMEOUT_SECONDS,
)
from ..repositories.account_repository import AccountRepository
from .fraud_engine import ALL_LAYERS, FraudEngine


class ResearchError(Exception):
    """Помилка дослідницького API з HTTP-статусом для відповіді."""

    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


# ══ Fraud scoring ═════════════════════════════════════════════════════════════

class FraudResearchService:
    """Обгортка над FraudEngine для дослідницького ендпоінта /fraud/score."""

    def __init__(self) -> None:
        self.accounts = AccountRepository()
        self.engine = FraudEngine()

    @staticmethod
    def _parse_layers(raw) -> Optional[list[str]]:
        """None → усі шари; інакше список з {'l1','l2','l3'} без дублікатів."""
        if raw is None:
            return None
        if isinstance(raw, str):
            raw = [raw]
        if not isinstance(raw, (list, tuple)) or not raw:
            raise ResearchError("Поле layers має бути непорожнім масивом, наприклад [\"l1\"].")
        layers: list[str] = []
        for item in raw:
            name = str(item).strip().lower()
            if name not in ALL_LAYERS:
                raise ResearchError(f'Невідомий шар "{item}". Допустимі: l1, l2, l3.')
            if name not in layers:
                layers.append(name)
        return layers

    def score(self, user_id: int, data: dict) -> dict:
        """Оцінює гіпотетичний переказ з рахунку поточного користувача.

        Переказ НЕ виконується і НЕ записується — лише скоринг.
        Body: amount (обов'язково), balance (за замовчуванням — фактичний
        баланс рахунку), description, recipient_account, recipient_account_id,
        layers (за замовчуванням усі).
        """
        try:
            amount = float(data.get('amount'))
        except (TypeError, ValueError):
            raise ResearchError('Поле amount обов\'язкове і має бути числом.')
        if amount <= 0:
            raise ResearchError('Сума має бути більшою за нуль.')

        account = self.accounts.get_account_by_user_id(user_id)
        if not account:
            raise ResearchError('Рахунок користувача не знайдено.', 404)

        raw_balance = data.get('balance')
        try:
            balance = float(account['balance']) if raw_balance is None else float(raw_balance)
        except (TypeError, ValueError):
            raise ResearchError('Поле balance має бути числом.')

        description = str(data.get('description') or '')[:500]
        layers = self._parse_layers(data.get('layers'))

        # Отримувач: приймаємо номер рахунку і/або id; відсутнє доповнюємо з БД,
        # щоб правила Layer 3 (граф, money mule, новий отримувач) мали обидва.
        recipient_number = (str(data.get('recipient_account') or '').strip()) or None
        recipient_id: Optional[int] = None
        if data.get('recipient_account_id') not in (None, ''):
            try:
                recipient_id = int(data['recipient_account_id'])
            except (TypeError, ValueError):
                raise ResearchError('Поле recipient_account_id має бути цілим числом.')
        if recipient_number and recipient_id is None:
            rec = self.accounts.get_account_by_number(recipient_number)
            recipient_id = int(rec['id']) if rec else None
        elif recipient_id is not None and not recipient_number:
            rec = self.accounts.get_account_by_id(recipient_id)
            recipient_number = rec['account_number'] if rec else None

        risk = self.engine.assess(
            int(account['id']), recipient_number, amount,
            balance=balance,
            description=description,
            recipient_account_id=recipient_id,
            layers=layers,
        )
        payload = risk.to_dict()
        payload['layers_run'] = list(risk.layers_run)
        payload['layers_requested'] = list(layers) if layers is not None else list(ALL_LAYERS)
        return payload


# ══ LLM (Anthropic Messages API) ══════════════════════════════════════════════

# Короткі системні промпти для кожної задачі. Тексти зафіксовані: зміна
# промпта = нова серія вимірювань.
SYSTEM_PROMPTS: dict[str, str] = {
    'support': (
        'Ти — асистент підтримки навчального банку Kopiyka. Усі гроші в ньому '
        'віртуальні (токени TAX), це пісочниця для навчання. '
        'Відповідай українською, коротко (до 5 речень), по суті. Не проси паролі, '
        'PIN, CVV чи коди з SMS. Якщо питання не стосується фінансів — ввічливо скажи про це.'
    ),
    'scam_check': (
        'Ти аналізуєш повідомлення або опис платежу на ознаки шахрайства '
        '(фішинг, «терміново переказати», виманювання кодів, підробні виграші, '
        'інвестиційні піраміди). Відповідай українською у форматі з трьох рядків: '
        '«Вердикт: шахрайство | підозріло | безпечно», «Впевненість: 0–100», '
        '«Причина: одне речення».'
    ),
    'receipt': (
        'Ти розбираєш текст чека (OCR може містити помилки). Поверни ЛИШЕ JSON '
        'без пояснень: {"merchant": str|null, "date": "YYYY-MM-DD"|null, '
        '"total": number|null, "currency": str|null, "items": [{"name": str, '
        '"qty": number|null, "price": number|null}], "category": str|null}. '
        'Невідомі поля — null.'
    ),
}

TIERS = ('small', 'large')


def _model_for_tier(tier: str) -> str:
    return LLM_MODEL_SMALL if tier == 'small' else LLM_MODEL_LARGE


class LLMResearchService:
    """Виклик Claude через офіційний SDK `anthropic` з фіксованими параметрами.

    Відтворюваність: моделі закріплені (LLM_MODEL_SMALL / LLM_MODEL_LARGE),
    effort фіксований (LLM_EFFORT), max_tokens фіксований (LLM_MAX_TOKENS),
    повторні спроби SDK вимкнені (max_retries=0), щоб server_ms не містив
    прихованих ретраїв. Параметр temperature НЕ передається: поточна версія
    Messages API (2026-10-21) і SDK його більше не приймають — для моделей
    claude-haiku-5-5 / claude-sonnet-5-5 семплінг завжди дефолтний.
    """

    def __init__(self, client=None) -> None:
        # client можна підмінити в тестах; інакше створюємо ліниво при першому виклику
        self._client = client

    def _get_client(self):
        if self._client is None:
            import anthropic   # імпорт тут: решта сервера не залежить від SDK
            self._client = anthropic.Anthropic(
                api_key=ANTHROPIC_API_KEY,
                timeout=LLM_TIMEOUT_SECONDS,
                max_retries=0,
            )
        return self._client

    @staticmethod
    def validate(data: dict) -> tuple[str, str, str]:
        task = str(data.get('task') or '').strip().lower()
        if task not in SYSTEM_PROMPTS:
            raise ResearchError('Поле task має бути одним із: support, scam_check, receipt.')
        tier = str(data.get('tier') or 'small').strip().lower()
        if tier not in TIERS:
            raise ResearchError('Поле tier має бути small або large.')
        prompt = data.get('prompt')
        if not isinstance(prompt, str) or not prompt.strip():
            raise ResearchError('Поле prompt обов\'язкове (непорожній рядок).')
        if len(prompt) > LLM_MAX_PROMPT_CHARS:
            raise ResearchError(f'Prompt задовгий (максимум {LLM_MAX_PROMPT_CHARS} символів).', 413)
        return task, tier, prompt

    def complete(self, data: dict) -> dict:
        task, tier, prompt = self.validate(data)
        if not ANTHROPIC_API_KEY and self._client is None:
            raise ResearchError(
                'LLM недоступна: на сервері не задано ANTHROPIC_API_KEY. '
                'Додайте ключ у server/.env і перезапустіть сервер.',
                503,
            )

        import anthropic
        model = _model_for_tier(tier)
        try:
            response = self._get_client().messages.create(
                model=model,
                max_tokens=LLM_MAX_TOKENS,
                system=SYSTEM_PROMPTS[task],
                messages=[{'role': 'user', 'content': prompt}],
                output_config={'effort': LLM_EFFORT},
            )
        except anthropic.AuthenticationError:
            raise ResearchError('Anthropic API відхилив ключ (ANTHROPIC_API_KEY невірний).', 502)
        except anthropic.PermissionDeniedError:
            raise ResearchError('Ключ Anthropic API не має доступу до цієї моделі.', 502)
        except anthropic.NotFoundError:
            raise ResearchError(f'Модель {model} не знайдено в Anthropic API.', 502)
        except anthropic.RateLimitError:
            raise ResearchError('Anthropic API: перевищено ліміт запитів, спробуйте пізніше.', 429)
        except anthropic.BadRequestError as exc:
            raise ResearchError(f'Anthropic API відхилив запит: {exc.message}', 502)
        except anthropic.APITimeoutError:
            raise ResearchError('Anthropic API не відповів вчасно (таймаут).', 504)
        except anthropic.APIConnectionError:
            raise ResearchError('Немає з\'єднання з Anthropic API.', 504)
        except anthropic.APIStatusError as exc:
            raise ResearchError(f'Anthropic API повернув помилку {exc.status_code}.', 502)

        text = ''.join(
            getattr(block, 'text', '') for block in (response.content or [])
            if getattr(block, 'type', None) == 'text'
        )
        usage = response.usage
        return {
            'text': text,
            'model': response.model,
            'tier': tier,
            'task': task,
            'stop_reason': response.stop_reason,
            'input_tokens': int(getattr(usage, 'input_tokens', 0) or 0),
            'output_tokens': int(getattr(usage, 'output_tokens', 0) or 0),
        }
