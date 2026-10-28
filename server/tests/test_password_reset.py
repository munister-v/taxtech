"""Тести відновлення пароля одноразовим кодом."""
from __future__ import annotations

import pytest


def _register(client, email='reset@example.com', phone='+380997770001', password='oldpass123'):
    r = client.post('/api/auth/register', json={
        'full_name': 'Відновлення Тест', 'phone': phone, 'email': email, 'password': password,
    })
    assert r.status_code == 200
    return r.get_json()['data']['token']


@pytest.fixture
def reset_on(app):
    app.config['AUTH_RESET_SHOW_CODE'] = True
    return app


def test_forgot_disabled_by_default(client):
    _register(client, email='off@example.com', phone='+380997770003')
    r = client.post('/api/auth/password/forgot', json={'identity': 'off@example.com'})
    assert r.status_code == 503
    assert 'вимкнене' in r.get_json()['error']


def test_reset_flow_changes_password_and_ends_old_sessions(reset_on, client):
    old_token = _register(client)
    r = client.post('/api/auth/password/forgot', json={'identity': 'RESET@example.com'})
    assert r.status_code == 200
    d = r.get_json()['data']
    assert len(d['demo_code']) == 6 and d['sent_to'].endswith('@example.com')

    r = client.post('/api/auth/password/reset', json={
        'reset_id': d['reset_id'], 'code': d['demo_code'], 'new_password': 'newpass456'})
    assert r.status_code == 200
    new_token = r.get_json()['data']['token']
    assert new_token and new_token != old_token

    # стара сесія закрита, нова працює
    assert client.get('/api/auth/me', headers={'Authorization': f'Bearer {old_token}'}).status_code == 401
    assert client.get('/api/auth/me', headers={'Authorization': f'Bearer {new_token}'}).status_code == 200
    # вхід лише новим паролем
    assert client.post('/api/auth/login', json={'identity': 'reset@example.com', 'password': 'oldpass123'}).status_code == 401
    assert client.post('/api/auth/login', json={'identity': 'reset@example.com', 'password': 'newpass456'}).status_code == 200
    # код одноразовий
    again = client.post('/api/auth/password/reset', json={
        'reset_id': d['reset_id'], 'code': d['demo_code'], 'new_password': 'another789'})
    assert again.status_code == 400


def test_wrong_code_burns_after_five_attempts(reset_on, client):
    _register(client, email='burn@example.com', phone='+380997770002')
    d = client.post('/api/auth/password/forgot', json={'identity': 'burn@example.com'}).get_json()['data']
    wrong = '000000' if d['demo_code'] != '000000' else '111111'
    for i in range(4):
        r = client.post('/api/auth/password/reset', json={'reset_id': d['reset_id'], 'code': wrong, 'new_password': 'newpass456'})
        assert r.status_code == 400 and 'Лишилось спроб' in r.get_json()['error']
    r = client.post('/api/auth/password/reset', json={'reset_id': d['reset_id'], 'code': wrong, 'new_password': 'newpass456'})
    assert 'Забагато' in r.get_json()['error']
    # навіть правильний код після блокування не діє
    r = client.post('/api/auth/password/reset', json={'reset_id': d['reset_id'], 'code': d['demo_code'], 'new_password': 'newpass456'})
    assert r.status_code == 400


def test_unknown_identity(reset_on, client):
    r = client.post('/api/auth/password/forgot', json={'identity': 'nobody@example.com'})
    assert r.status_code == 404
