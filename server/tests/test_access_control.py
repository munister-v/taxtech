"""Регресійні тести розмежування доступу: публічна реєстрація НЕ повинна
робити користувача адміном, а адмін-панелі та CRM вихідного проєкту
у пісочниці Kopiyka відсутні взагалі (маршрути не зареєстровані)."""
from __future__ import annotations

import random

from backend.repositories.user_repository import UserRepository


def _rand_uid():
    return ''.join(str(random.randint(0, 9)) for _ in range(7))


def _register(client, uid=None):
    uid = uid or _rand_uid()
    r = client.post('/api/auth/register', json={
        'full_name': f'Тест {uid}', 'phone': f'+38093{uid}',
        'email': f'user-{uid}@test.ua', 'password': 'qwerty',
    })
    data = r.get_json()
    assert data.get('ok'), data.get('error', 'register failed')
    return data['data']['user']['id'], data['data']['token']


def test_public_registration_creates_plain_user_not_admin(client):
    """Реєстрант — звичайний клієнт пісочниці (роль 'user'), а не адмін."""
    _, token = _register(client)
    me = client.get('/api/auth/me', headers={'Authorization': f'Bearer {token}'}).get_json()
    assert me['data']['role'] == 'user'
    assert 'military_status' not in me['data']


def test_removed_admin_and_crm_routes_are_absent(client):
    """Адмінка, CRM, месенджер, маркетплейс, 3DS тощо прибрані — 404 навіть для admin."""
    uid, token = _register(client)
    UserRepository().update_role(uid, 'admin')
    h = {'Authorization': f'Bearer {token}'}
    for path in ('/api/admin/users', '/api/admin/stats', '/api/leads',
                 '/api/prospecting/categories', '/api/integrations',
                 '/api/messenger/conversations', '/api/marketplace/products',
                 '/api/admin/deposits', '/api/admin/credits', '/api/operator/queue',
                 '/api/platform/users', '/api/push/vapid-key', '/api/webhooks'):
        assert client.get(path, headers=h).status_code == 404, path
    assert client.post('/api/3ds/challenge', headers=h, json={}).status_code == 404


def test_api_catalog_lists_only_sandbox_routes(client):
    data = client.get('/api').get_json()
    assert data['ok'] is True
    assert data['currency'] == 'VUAH'
    paths = {r['path'] for r in data['routes']}
    assert '/api/research/ping' in paths
    assert '/api/transactions/transfer' in paths
    assert not any(p.startswith(('/api/admin', '/api/leads', '/api/messenger', '/api/3ds'))
                   for p in paths)
