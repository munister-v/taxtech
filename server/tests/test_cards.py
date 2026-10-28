"""Тести API карток."""
from __future__ import annotations

import random

import pytest


@pytest.fixture
def card_auth_headers(client):
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    r = client.post('/api/auth/register', json={
        'full_name': 'Користувач Картки',
        'phone': f'+38095{uid}',
        'email': f'cards-{uid}@test.ua',
        'password': 'qwerty',
    }, headers={'Content-Type': 'application/json'})
    data = r.get_json()
    assert data.get('ok'), data.get('error', 'register failed')
    token = data['data']['token']
    return {'Authorization': f'Bearer {token}'}


def _issue_card(client, headers, design='gold'):
    r = client.post('/api/cards', json={'card_type': 'virtual', 'design': design}, headers=headers)
    assert r.status_code in (200, 201)
    payload = r.get_json()
    assert payload['ok'] is True
    return payload['data']


def test_update_card_design_success(client, card_auth_headers):
    card = _issue_card(client, card_auth_headers, design='gold')
    card_id = card['id']

    update = client.patch(f'/api/cards/{card_id}/design', json={'design': 'rose'}, headers=card_auth_headers)
    assert update.status_code == 200
    data = update.get_json()
    assert data['ok'] is True
    assert data['data']['design'] == 'rose'
    assert data['data']['id'] == card_id

    listed = client.get('/api/cards', headers=card_auth_headers).get_json()['data']
    target = next(c for c in listed if c['id'] == card_id)
    assert target['design'] == 'rose'


def test_update_card_design_rejects_invalid_design(client, card_auth_headers):
    card = _issue_card(client, card_auth_headers, design='gold')
    card_id = card['id']

    update = client.patch(f'/api/cards/{card_id}/design', json={'design': 'ultra-neon'}, headers=card_auth_headers)
    assert update.status_code == 400
    data = update.get_json()
    assert data['ok'] is False
    assert 'Непідтримуваний дизайн' in data['error']


def test_update_card_design_rejects_closed_card(client, card_auth_headers):
    card = _issue_card(client, card_auth_headers, design='gold')
    card_id = card['id']

    close = client.patch(f'/api/cards/{card_id}/close', headers=card_auth_headers)
    assert close.status_code == 200
    assert close.get_json()['ok'] is True

    update = client.patch(f'/api/cards/{card_id}/design', json={'design': 'navy'}, headers=card_auth_headers)
    assert update.status_code == 400
    data = update.get_json()
    assert data['ok'] is False
    assert 'Закрита картка' in data['error']



def test_issued_card_number_is_clearly_fake(client, card_auth_headers):
    """Номер віртуальної картки: префікс 0000 і навмисно невалідна контрольна цифра Луна."""
    from backend.services.card_service import CardService, _luhn_checksum
    card_id = _issue_card(client, card_auth_headers)["id"]
    token = card_auth_headers['Authorization'].split()[1]
    from backend.services.auth_service import AuthService
    user = AuthService().get_user_by_token(token)
    number = CardService().reveal_card(user['id'], card_id)['card_number'].replace(' ', '')
    assert number.startswith('0000') and len(number) == 16
    assert _luhn_checksum(number) != 0


def test_card_style_saved_listed_and_reset(client, card_auth_headers):
    card_id = _issue_card(client, card_auth_headers)['id']
    style = {'material': 'metal', 'color': 'navy', 'pattern': 'guilloche', 'emblem': 'seal', 'name': '  Подорожі  '}
    r = client.patch(f'/api/cards/{card_id}/style', json={'style': style}, headers=card_auth_headers)
    assert r.status_code == 200
    assert r.get_json()['data']['style']['name'] == 'Подорожі'

    listed = client.get('/api/cards', headers=card_auth_headers).get_json()['data']
    target = next(c for c in listed if c['id'] == card_id)
    assert target['style'] == {'material': 'metal', 'color': 'navy', 'pattern': 'guilloche', 'emblem': 'seal', 'name': 'Подорожі'}

    reset = client.patch(f'/api/cards/{card_id}/style', json={'style': None}, headers=card_auth_headers)
    assert reset.status_code == 200
    listed = client.get('/api/cards', headers=card_auth_headers).get_json()['data']
    assert next(c for c in listed if c['id'] == card_id)['style'] is None


@pytest.mark.parametrize('bad', [
    {'material': 'plastic', 'color': 'navy', 'pattern': 'none', 'emblem': 'none'},
    {'material': 'solid', 'color': '#ff0000', 'pattern': 'none', 'emblem': 'none'},
    {'material': 'solid', 'color': 'navy', 'pattern': 'none', 'emblem': 'none', 'name': 'х' * 25},
    {'material': 'solid', 'color': 'navy', 'pattern': 'none', 'emblem': 'none', 'script': '<b>'},
    'metal',
])
def test_card_style_rejects_bad_values(client, card_auth_headers, bad):
    card_id = _issue_card(client, card_auth_headers)['id']
    r = client.patch(f'/api/cards/{card_id}/style', json={'style': bad}, headers=card_auth_headers)
    assert r.status_code == 400
    assert r.get_json()['ok'] is False


def test_card_style_other_user_card_not_found(client, card_auth_headers):
    card_id = _issue_card(client, card_auth_headers)['id']
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    other = client.post('/api/auth/register', json={
        'full_name': 'Інший', 'phone': f'+38096{uid}', 'email': f'other-{uid}@test.ua', 'password': 'qwerty',
    }).get_json()['data']['token']
    r = client.patch(f'/api/cards/{card_id}/style', json={'style': None}, headers={'Authorization': f'Bearer {other}'})
    assert r.status_code == 400
