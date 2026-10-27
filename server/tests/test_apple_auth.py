"""Вхід через Apple і видалення облікового запису."""
from __future__ import annotations

import hashlib
import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from backend.config import APPLE_CLIENT_ID
from backend.database import get_connection
from backend.services import apple_auth


@pytest.fixture(scope='module')
def apple_key():
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


@pytest.fixture(autouse=True)
def fake_apple_keys(monkeypatch, apple_key):
    """Замість JWKS Apple підставляємо відкритий ключ тестової пари."""
    monkeypatch.setattr(apple_auth, '_apple_key', lambda token: apple_key.public_key())


def make_token(key, *, sub='001234.abcdef', nonce='raw-nonce', email='user@privaterelay.appleid.com',
               aud=None, exp_in=600, iss=apple_auth.APPLE_ISSUER):
    now = int(time.time())
    claims = {'iss': iss, 'aud': aud or APPLE_CLIENT_ID, 'sub': sub, 'iat': now, 'exp': now + exp_in,
              'nonce': hashlib.sha256(nonce.encode()).hexdigest()}
    if email:
        claims['email'] = email
    return jwt.encode(claims, key, algorithm='RS256', headers={'kid': 'test'})


def login(client, key, **kw):
    nonce = kw.get('nonce', 'raw-nonce')
    return client.post('/api/auth/apple', json={
        'identity_token': make_token(key, **kw), 'nonce': nonce, 'full_name': 'Іван Тест'})


def test_first_login_registers_with_account(client, apple_key):
    r = login(client, apple_key, sub='new.user.1')
    assert r.status_code == 200
    data = r.get_json()['data']
    assert data['created'] is True
    assert data['token']
    assert data['user']['full_name'] == 'Іван Тест'
    assert data['user']['bank_account_number'].startswith('KP-')


def test_second_login_is_same_user(client, apple_key):
    first = login(client, apple_key, sub='same.user.2').get_json()['data']
    second = login(client, apple_key, sub='same.user.2').get_json()['data']
    assert second['created'] is False
    assert second['user']['id'] == first['user']['id']


def test_wrong_nonce_rejected(client, apple_key):
    r = client.post('/api/auth/apple', json={
        'identity_token': make_token(apple_key, nonce='one'), 'nonce': 'another'})
    assert r.status_code == 401


def test_wrong_audience_rejected(client, apple_key):
    assert login(client, apple_key, aud='com.someone.else').status_code == 401


def test_expired_token_rejected(client, apple_key):
    assert login(client, apple_key, exp_in=-60).status_code == 401


def test_foreign_signature_rejected(client):
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    assert login(client, other).status_code == 401


def test_missing_token_rejected(client):
    assert client.post('/api/auth/apple', json={}).status_code == 401


def test_existing_email_is_not_silently_linked(client, apple_key):
    client.post('/api/auth/register', json={
        'full_name': 'Власник', 'phone': '+380991110001', 'email': 'taken@example.com', 'password': 'secret123'})
    r = login(client, apple_key, sub='email.clash.3', email='taken@example.com')
    assert r.status_code == 200
    assert r.get_json()['data']['user']['email'] != 'taken@example.com'


def test_delete_account_removes_everything(client, apple_key):
    data = login(client, apple_key, sub='to.delete.4').get_json()['data']
    uid, headers = data['user']['id'], {'Authorization': f"Bearer {data['token']}"}
    client.post('/api/transactions/topup', json={'amount': 100}, headers={**headers, 'Idempotency-Key': 'k-del-1'})
    r = client.delete('/api/auth/account', headers=headers)
    assert r.status_code == 200
    assert client.get('/api/accounts/main', headers=headers).status_code == 401
    with get_connection() as conn:
        assert conn.execute('SELECT COUNT(*) AS n FROM users WHERE id = %s', (uid,)).fetchone()['n'] == 0
        assert conn.execute('SELECT COUNT(*) AS n FROM accounts WHERE user_id = %s', (uid,)).fetchone()['n'] == 0
