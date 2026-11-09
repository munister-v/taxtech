"""Валютні рахунки: IBAN, обмін зі спредом, перекази на IBAN, довідки."""
import random
import uuid

from backend.services import fx_service as fx


def _login(client):
    uid = ''.join(str(random.randint(0, 9)) for _ in range(7))
    r = client.post('/api/auth/register', json={
        'full_name': f'Fx User {uid}', 'phone': f'+38067{uid}', 'email': f'fx-{uid}@test.ua', 'password': 'qwerty'})
    return {'Authorization': f"Bearer {r.get_json()['data']['token']}"}


def _fund(client, h, amount=10000.0):
    r = client.post('/api/transactions/topup', json={'amount': amount, 'description': 'fx'},
                    headers={**h, 'Idempotency-Key': uuid.uuid4().hex})
    assert r.status_code == 200, r.get_json()


def test_iban_is_valid_and_detects_typos():
    iban = fx.make_iban('USD', 3, 7)
    assert len(iban) == 29 and iban.startswith('UA') and fx.valid_iban(iban)
    assert fx.valid_iban(fx.pretty_iban(iban))
    typo = iban[:-1] + str((int(iban[-1]) + 1) % 10)
    assert not fx.valid_iban(typo)
    assert fx.valid_iban('UA213223130000026007233566001')


def test_spread_round_trip_costs_money():
    there = fx.convert('TAX', 'USD', 4150.0)
    back = fx.convert('USD', 'TAX', there['to_amount'])
    assert back['to_amount'] < 4150.0
    assert there['spread_tax'] > 0


def test_exchange_moves_money_and_opens_wallet(client):
    h = _login(client)
    _fund(client, h)
    before = client.get('/api/fx/accounts', headers=h).get_json()['data']
    tax0 = before['accounts'][0]['balance']
    assert len(before['accounts']) == 1 and before['accounts'][0]['iban'].startswith('UA')
    r = client.post('/api/fx/exchange', json={'from': 'TAX', 'to': 'EUR', 'amount': 4520}, headers=h)
    assert r.status_code == 200, r.get_json()
    got = r.get_json()['data']['to_amount']
    assert 95 < got < 100
    after = client.get('/api/fx/accounts', headers=h).get_json()['data']
    eur = [a for a in after['accounts'] if a['currency'] == 'EUR'][0]
    assert eur['balance'] == got and after['accounts'][0]['balance'] == round(tax0 - 4520, 2)
    assert fx.valid_iban(eur['iban'])
    # у виписці основного рахунку є рядок обміну
    hist = client.get('/api/transactions/history', headers=h).get_json()['data']
    assert any((t['description'] or '').startswith('FX TAX') for t in hist)
    # недостатньо коштів
    assert client.post('/api/fx/exchange', json={'from': 'EUR', 'to': 'TAX', 'amount': 99999}, headers=h).status_code == 409
    assert client.post('/api/fx/exchange', json={'from': 'EUR', 'to': 'EUR', 'amount': 1}, headers=h).status_code == 400


def test_transfer_between_users_by_iban_and_external(client):
    a, b = _login(client), _login(client)
    for h in (a, b):
        client.post('/api/fx/wallets', json={'currency': 'USD'}, headers=h)
    wb = [x for x in client.get('/api/fx/accounts', headers=b).get_json()['data']['accounts'] if x['currency'] == 'USD'][0]
    wa = [x for x in client.get('/api/fx/accounts', headers=a).get_json()['data']['accounts'] if x['currency'] == 'USD'][0]
    assert client.post(f"/api/fx/wallets/{wa['id']}/topup", json={'amount': 500}, headers=a).status_code == 200
    r = client.post('/api/fx/transfer', json={'from_currency': 'USD', 'iban': wb['iban_pretty'], 'amount': 120, 'beneficiary': 'B'}, headers=a)
    assert r.status_code == 200 and r.get_json()['data']['internal'] is True and r.get_json()['data']['fee'] == 0
    assert [x for x in client.get('/api/fx/accounts', headers=b).get_json()['data']['accounts'] if x['currency'] == 'USD'][0]['balance'] == 120
    ext = client.post('/api/fx/transfer', json={'from_currency': 'USD', 'iban': 'UA213223130000026007233566001', 'amount': 100, 'beneficiary': 'Ext'}, headers=a)
    d = ext.get_json()['data']
    assert ext.status_code == 200 and d['internal'] is False and d['fee'] == 1.0 and d['rail'] == 'SWIFT'
    assert client.post('/api/fx/transfer', json={'from_currency': 'USD', 'iban': 'UA213223130000026007233566002', 'amount': 1, 'beneficiary': 'X'}, headers=a).status_code == 400
    assert client.get(f"/api/fx/wallets/{wa['id']}/transactions", headers=b).status_code == 404


def test_certificates_issue_verify_and_pdf(client):
    h = _login(client)
    _fund(client, h, 1000)
    r = client.post('/api/fx/certificates', json={'type': 'balance', 'currency': 'TAX'}, headers=h)
    assert r.status_code == 200, r.get_json()
    doc = r.get_json()['data']
    assert doc['kind'] == 'certificate' and doc['meta']['balance'] == 1000.0
    pub = client.get(f"/api/verify/{doc['code']}").get_json()['data']
    assert pub['intact'] is True and 'Fx User' not in str(pub)
    assert client.get(f"/v/{doc['code']}").status_code == 200
    pdf = client.get(f"/api/fx/certificates/{doc['code']}.pdf", headers=h)
    assert pdf.status_code == 200 and pdf.data.startswith(b'%PDF')
    t = client.post('/api/fx/certificates', json={'type': 'turnover', 'currency': 'TAX'}, headers=h).get_json()['data']
    assert t['meta']['credit'] == 1000.0
    assert client.post('/api/fx/certificates', json={'type': 'balance', 'currency': 'PLN'}, headers=h).status_code == 404
    assert client.post('/api/fx/certificates', json={'type': 'nope'}, headers=h).status_code == 400
    other = _login(client)
    assert client.get(f"/api/fx/certificates/{doc['code']}.pdf", headers=other).status_code == 404
