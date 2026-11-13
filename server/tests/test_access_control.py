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
    """Адмінка, CRM, месенджер, push тощо прибрані — 404 навіть для admin.
    Магазин, 3-D Secure і passkey повернулися разом із мобільним застосунком."""
    uid, token = _register(client)
    UserRepository().update_role(uid, 'admin')
    h = {'Authorization': f'Bearer {token}'}
    for path in ('/api/admin/users', '/api/admin/stats', '/api/leads',
                 '/api/prospecting/categories', '/api/integrations',
                 '/api/messenger/conversations', '/api/marketplace/products',
                 '/api/admin/deposits', '/api/admin/credits', '/api/operator/queue',
                 '/api/platform/users', '/api/push/vapid-key', '/api/webhooks'):
        assert client.get(path, headers=h).status_code == 404, path


def test_api_catalog_lists_only_sandbox_routes(client):
    data = client.get('/api').get_json()
    assert data['ok'] is True
    assert data['currency'] == 'TAX'
    paths = {r['path'] for r in data['routes']}
    assert '/api/research/ping' in paths
    assert '/api/transactions/transfer' in paths
    assert not any(p.startswith(('/api/admin', '/api/leads', '/api/messenger'))
                   for p in paths)


def test_security_headers(client):
    h = client.get('/api/version').headers
    assert h['Strict-Transport-Security'].startswith('max-age=')
    assert "frame-ancestors 'none'" in h['Content-Security-Policy']
    assert "form-action 'self'" in h['Content-Security-Policy']
    assert 'camera=()' in h['Permissions-Policy']


def test_client_ip_ignores_spoofed_forwarded_for(app):
    from backend.routes.helpers import _client_ip
    # nginx: X-Real-IP = the connecting address, X-Forwarded-For = "<whatever the client sent>, <real>"
    with app.test_request_context(headers={'X-Real-IP': '203.0.113.7', 'X-Forwarded-For': '1.2.3.4, 203.0.113.7'}):
        assert _client_ip() == '203.0.113.7'
    with app.test_request_context(headers={'X-Forwarded-For': '1.2.3.4, 203.0.113.7'}):
        assert _client_ip() == '203.0.113.7'
