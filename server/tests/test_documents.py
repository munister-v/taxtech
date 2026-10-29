"""Єдине сховище документів: код перевірки, QR, публічна перевірка квитанції й виписки."""
from backend.services.document_service import make_code, normalize_code


def test_code_is_stable_and_normalizes():
    a = make_code('receipt', '7', 1)
    assert a == make_code('receipt', '7', 1)
    assert a != make_code('receipt', '7', 2)
    assert a != make_code('statement', '7', 1)
    assert a.startswith('TT-') and len(a) == 17
    assert normalize_code(a.lower().replace('-', ' ')) == a
    assert normalize_code('nonsense') == ''


def _login(client):
    import random
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    r = client.post('/api/auth/register', json={
        'full_name': f'Doc User {uid}', 'phone': f'+38066{uid}', 'email': f'doc-{uid}@test.ua', 'password': 'qwerty'})
    return {'Authorization': f"Bearer {r.get_json()['data']['token']}"}


def _first_tx(client, headers):
    import uuid
    r = client.post('/api/transactions/topup', json={'amount': 410.0, 'description': 'Doc topup'},
                    headers={**headers, 'Idempotency-Key': uuid.uuid4().hex})
    assert r.status_code == 200, r.get_json()
    return int(client.get('/api/transactions/history', headers=headers).get_json()['data'][0]['id'])


def test_receipt_document_is_public_verifiable_without_personal_data(client):
    h = _login(client)
    tx_id = _first_tx(client, h)

    doc = client.get(f'/api/documents/receipt/{tx_id}', headers=h).get_json()['data']
    assert doc['kind'] == 'receipt' and doc['code'].startswith('TT-')
    assert doc['verify_url'].endswith(f"/v/{doc['code']}")
    # той самий документ - той самий код
    assert client.get(f'/api/documents/receipt/{tx_id}', headers=h).get_json()['data']['code'] == doc['code']

    pub = client.get(f"/api/verify/{doc['code']}")   # без токена
    body = pub.get_json()['data']
    assert pub.status_code == 200 and body['intact'] is True
    assert body['amount'] == 410.0 and body['direction'] == 'in'
    assert 'Doc User' not in pub.get_data(as_text=True) and '@test.ua' not in pub.get_data(as_text=True)

    page = client.get(f"/v/{doc['code']}")
    assert page.status_code == 200 and 'Документ дійсний' in page.get_data(as_text=True)
    assert client.get('/v/TT-AAAA-BBBB-CCCC').status_code == 404

    qr = client.get(f"/api/qr/{doc['code']}.svg")
    assert qr.status_code == 200 and qr.mimetype == 'image/svg+xml' and b'<svg' in qr.data


def test_documents_list_and_pdfs_register_documents(client):
    h = _login(client)
    tx_id = _first_tx(client, h)
    assert client.get(f'/api/transactions/{tx_id}/receipt', headers=h).status_code == 200
    assert client.get('/api/transactions/statement?report_type=detailed', headers=h).status_code == 200

    kinds = {d['kind'] for d in client.get('/api/documents', headers=h).get_json()['data']}
    assert kinds == {'receipt', 'statement'}
    st = [d for d in client.get('/api/documents?kind=statement', headers=h).get_json()['data']][0]
    v = client.get(f"/api/verify/{st['code']}").get_json()['data']
    assert v['kind'] == 'statement' and v['intact'] is True and v['meta']['count'] >= 1

    # чужий користувач не бачить цих документів у своєму списку
    other = _login(client)
    assert client.get('/api/documents', headers=other).get_json()['data'] == []
    assert client.get(f'/api/documents/receipt/{tx_id}', headers=other).get_json().get('ok') is False
