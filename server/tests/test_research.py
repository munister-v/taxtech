"""Тести дослідницького API (/api/research/*).

LLM-тести НЕ ходять у мережу: SDK `anthropic` підміняється фейковим клієнтом.
"""
from __future__ import annotations

import logging
import random
import statistics
from datetime import datetime
from types import SimpleNamespace

import pytest


def _rand_uid() -> str:
    return ''.join(str(random.randint(0, 9)) for _ in range(7))


def _register(client):
    uid = _rand_uid()
    r = client.post('/api/auth/register', json={
        'full_name': f'Research User {uid}',
        'phone': f'+38097{uid}',
        'email': f'research-{uid}@test.ua',
        'password': 'qwerty',
    })
    data = r.get_json()
    assert data.get('ok'), data.get('error', 'register failed')
    return data['data']['token'], data['data']['user']['bank_account_number']


@pytest.fixture
def auth(client):
    token, account_number = _register(client)
    return {'Authorization': f'Bearer {token}'}, account_number


def _assert_server_ms(payload: dict):
    assert isinstance(payload['server_ms'], float)
    assert payload['server_ms'] >= 0


# ── ping ──────────────────────────────────────────────────────────────────────

def test_ping_no_auth(client):
    r = client.get('/api/research/ping')
    assert r.status_code == 200
    data = r.get_json()
    assert data['ok'] is True
    datetime.fromisoformat(data['server_time'])   # валідний ISO-8601
    _assert_server_ms(data)


# ── echo ──────────────────────────────────────────────────────────────────────

def test_echo_counts_raw_bytes(client):
    body = random.randbytes(1024 * 1024 + 17)
    r = client.post('/api/research/echo', data=body,
                    headers={'Content-Type': 'application/octet-stream'})
    assert r.status_code == 200
    data = r.get_json()
    assert data['ok'] is True
    assert data['bytes_received'] == len(body)
    _assert_server_ms(data)


def test_echo_empty_body(client):
    data = client.post('/api/research/echo').get_json()
    assert data['bytes_received'] == 0


def test_echo_accepts_exactly_5mb(client):
    body = b'\x00' * (5 * 1024 * 1024)
    r = client.post('/api/research/echo', data=body)
    assert r.status_code == 200
    assert r.get_json()['bytes_received'] == len(body)


def test_echo_rejects_over_5mb(client):
    body = b'\x00' * (5 * 1024 * 1024 + 1)
    r = client.post('/api/research/echo', data=body)
    assert r.status_code == 413
    data = r.get_json()
    assert data['ok'] is False
    _assert_server_ms(data)


# ── fraud/score ───────────────────────────────────────────────────────────────

def test_fraud_score_requires_auth(client):
    r = client.post('/api/research/fraud/score', json={'amount': 100, 'balance': 1000})
    assert r.status_code == 401


def test_fraud_score_validation(client, auth):
    h, _ = auth
    assert client.post('/api/research/fraud/score', json={}, headers=h).status_code == 400
    assert client.post('/api/research/fraud/score', json={'amount': -5}, headers=h).status_code == 400
    bad = client.post('/api/research/fraud/score',
                      json={'amount': 10, 'layers': ['l9']}, headers=h)
    assert bad.status_code == 400
    assert bad.get_json()['ok'] is False


def test_fraud_score_full_default_runs_all_layers(client, auth):
    h, _ = auth
    r = client.post('/api/research/fraud/score', json={
        'amount': 120, 'balance': 10_000, 'description': 'Кава',
    }, headers=h)
    assert r.status_code == 200
    data = r.get_json()
    assert data['ok'] is True
    for key in ('score', 'level', 'flags', 'details', 'confidence', 'layers_run'):
        assert key in data
    assert data['layers_run'] == ['l1', 'l2', 'l3']
    assert 'fraud_mode' not in data['details']   # SQLite більше не «lite»
    _assert_server_ms(data)


def test_fraud_score_l1_only_matches_device_equivalent(client, auth):
    h, _ = auth
    r = client.post('/api/research/fraud/score', json={
        'amount': 9_900, 'balance': 100_000, 'description': 'терміново crypto',
        'layers': ['l1'],
    }, headers=h)
    data = r.get_json()
    assert data['layers_run'] == ['l1']
    assert 'structuring' in data['flags']
    assert 'suspicious_description' in data['flags']
    assert 'new_sender_account' not in data['flags']   # це правило Layer 2


def test_fraud_layer2_rules_work_on_sqlite(client, auth, caplog):
    """Швидка серія вихідних переказів має ловитися Layer 2 і на SQLite."""
    h, _ = auth
    from backend.repositories.account_repository import AccountRepository
    from backend.repositories.user_repository import UserRepository
    token = h['Authorization'].split()[1]
    user = UserRepository().get_user_by_token(token)
    repo = AccountRepository()
    account = repo.get_account_by_user_id(user['id'])
    for i in range(7):
        repo.add_transaction(account['id'], 'transfer', 'out', 300 + i, 'Серія', 'KP-999999')

    body = {'amount': 310, 'balance': 50_000, 'recipient_account': 'KP-999999'}
    with caplog.at_level(logging.WARNING):
        full = client.post('/api/research/fraud/score', json=body, headers=h).get_json()
    assert not [rec for rec in caplog.records if 'fraud rule' in rec.getMessage()], \
        'жодне правило не повинно падати на SQLite'
    assert 'rapid_succession' in full['flags']
    assert 'velocity_elevated' in full['flags']

    l1 = client.post('/api/research/fraud/score', json={**body, 'layers': ['l1']}, headers=h).get_json()
    assert 'rapid_succession' not in l1['flags']
    assert full['score'] >= l1['score']


def test_fraud_score_resolves_recipient_by_number(client, auth):
    h, _ = auth
    _, other_account = _register(client)
    data = client.post('/api/research/fraud/score', json={
        'amount': 500, 'balance': 5_000, 'recipient_account': other_account,
    }, headers=h).get_json()
    assert data['ok'] is True
    # отримувач щойно зареєстрований → правило «новий отримувач + новий рахунок»
    assert 'new_recipient_new_account' in data['flags']


def test_fraud_engine_default_behaviour_unchanged():
    """Без параметра layers assess() запускає всі шари (як у payment_core)."""
    from backend.services.fraud_engine import FraudEngine
    risk = FraudEngine().assess(0, None, 50.0, balance=1000.0)
    assert risk.layers_run == ['l1', 'l2', 'l3']
    assert set(risk.to_dict()) == {'score', 'level', 'flags', 'details', 'confidence'}


def test_python_stats_match_postgres_semantics():
    from backend.services.fraud_engine import _percentile_cont, _stddev_samp
    values = [10.0, 20.0, 30.0, 40.0, 1000.0]
    assert _stddev_samp(values) == pytest.approx(statistics.stdev(values))
    # PERCENTILE_CONT(0.25) для [10,20,30,40,1000] = 20, (0.75) = 40
    assert _percentile_cont(values, 0.25) == pytest.approx(20.0)
    assert _percentile_cont(values, 0.75) == pytest.approx(40.0)
    assert _percentile_cont([1.0, 2.0], 0.5) == pytest.approx(1.5)


# ── llm (SDK замоковано) ──────────────────────────────────────────────────────

class _FakeMessages:
    def __init__(self, exc=None):
        self.calls = []
        self.exc = exc

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if self.exc:
            raise self.exc
        return SimpleNamespace(
            content=[SimpleNamespace(type='thinking', thinking=''),
                     SimpleNamespace(type='text', text='Вердикт: підозріло')],
            model=kwargs['model'],
            stop_reason='end_turn',
            usage=SimpleNamespace(input_tokens=42, output_tokens=7),
        )


@pytest.fixture
def fake_llm(monkeypatch):
    from backend.routes import research_routes
    fake = SimpleNamespace(messages=_FakeMessages())
    monkeypatch.setattr(research_routes.llm_service, '_client', fake)
    return fake


def test_llm_requires_auth(client):
    r = client.post('/api/research/llm', json={'task': 'support', 'prompt': 'hi', 'tier': 'small'})
    assert r.status_code == 401


@pytest.mark.parametrize('tier,model', [('small', 'claude-haiku-5-5'), ('large', 'claude-sonnet-5-5')])
def test_llm_tiers_use_pinned_models(client, auth, fake_llm, tier, model):
    h, _ = auth
    r = client.post('/api/research/llm', json={
        'task': 'scam_check', 'prompt': 'Вам виграш! Надішліть код з SMS', 'tier': tier,
    }, headers=h)
    assert r.status_code == 200
    data = r.get_json()
    assert data['ok'] is True
    assert data['text'] == 'Вердикт: підозріло'
    assert data['model'] == model
    assert data['input_tokens'] == 42
    assert data['output_tokens'] == 7
    _assert_server_ms(data)

    call = fake_llm.messages.calls[-1]
    assert call['model'] == model
    assert 'temperature' not in call          # API 2026-10-21 його не приймає
    assert call['output_config'] == {'effort': 'low'}
    assert 'шахрайств' in call['system']
    assert call['messages'] == [{'role': 'user', 'content': 'Вам виграш! Надішліть код з SMS'}]


def test_llm_validation(client, auth, fake_llm):
    h, _ = auth
    url = '/api/research/llm'
    assert client.post(url, json={'task': 'poem', 'prompt': 'x', 'tier': 'small'}, headers=h).status_code == 400
    assert client.post(url, json={'task': 'support', 'prompt': 'x', 'tier': 'xl'}, headers=h).status_code == 400
    assert client.post(url, json={'task': 'support', 'prompt': '  ', 'tier': 'small'}, headers=h).status_code == 400
    assert fake_llm.messages.calls == []


def test_llm_without_api_key_returns_503(client, auth, monkeypatch):
    from backend.routes import research_routes
    from backend.services import research_service
    monkeypatch.setattr(research_service, 'ANTHROPIC_API_KEY', '')
    monkeypatch.setattr(research_routes.llm_service, '_client', None)
    h, _ = auth
    r = client.post('/api/research/llm', json={'task': 'support', 'prompt': 'Як поповнити рахунок?', 'tier': 'small'}, headers=h)
    assert r.status_code == 503
    data = r.get_json()
    assert data['ok'] is False
    assert 'ANTHROPIC_API_KEY' in data['error']
    _assert_server_ms(data)


def test_llm_builds_sdk_client_without_retries(client, auth, monkeypatch):
    """Реальний шлях створення клієнта, але клас anthropic.Anthropic підмінено."""
    import anthropic
    from backend.routes import research_routes
    from backend.services import research_service

    created = {}

    class _FakeAnthropic:
        def __init__(self, **kwargs):
            created.update(kwargs)
            self.messages = _FakeMessages()

    monkeypatch.setattr(anthropic, 'Anthropic', _FakeAnthropic)
    monkeypatch.setattr(research_service, 'ANTHROPIC_API_KEY', 'test-key-not-real')
    monkeypatch.setattr(research_routes.llm_service, '_client', None)
    h, _ = auth
    r = client.post('/api/research/llm', json={'task': 'receipt', 'prompt': 'АТБ 12.10.2026 Хліб 25.50', 'tier': 'small'}, headers=h)
    assert r.status_code == 200
    assert created['api_key'] == 'test-key-not-real'
    assert created['max_retries'] == 0


def test_llm_sdk_timeout_maps_to_504(client, auth, monkeypatch):
    import anthropic
    import httpx2
    from backend.routes import research_routes
    req = httpx2.Request('POST', 'https://api.anthropic.com/v1/messages')
    fake = SimpleNamespace(messages=_FakeMessages(exc=anthropic.APITimeoutError(request=req)))
    monkeypatch.setattr(research_routes.llm_service, '_client', fake)
    h, _ = auth
    r = client.post('/api/research/llm', json={'task': 'support', 'prompt': 'Привіт', 'tier': 'large'}, headers=h)
    assert r.status_code == 504
    assert r.get_json()['ok'] is False
