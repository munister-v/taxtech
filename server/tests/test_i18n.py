"""Мова документів: сторінка перевірки, PDF і повнота таблиці перекладів."""
import ast
import glob
import re

import json
import subprocess
import sys
from pathlib import Path

from backend.i18n import LANGS, _T, tr, tr_text
from tests.test_documents import _first_tx, _login


def test_every_wrapped_label_has_all_translations():
    cyr = re.compile('[А-Яа-яІіЇїЄєҐґ]')
    missing = []
    for path in glob.glob('backend/services/*.py') + glob.glob('backend/repositories/*.py'):
        for node in ast.walk(ast.parse(open(path).read())):
            if (isinstance(node, ast.Call) and getattr(node.func, 'id', '') == 'tr' and node.args
                    and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str)
                    and cyr.search(node.args[0].value) and node.args[0].value not in _T):
                missing.append((path, node.args[0].value))
    assert not missing, missing
    assert all(len(v) == len(LANGS) - 1 and all(v) for v in _T.values())


def test_verify_page_follows_accept_language_and_query(client):
    h = _login(client)
    code = client.get(f'/api/documents/receipt/{_first_tx(client, h)}', headers=h).get_json()['data']['code']

    uk = client.get(f'/v/{code}').get_data(as_text=True)
    assert 'Документ дійсний' in uk and 'lang="uk"' in uk

    en = client.get(f'/v/{code}', headers={'Accept-Language': 'en-US,en;q=0.9'}).get_data(as_text=True)
    assert 'The document is valid' in en and 'Документ' not in en and 'lang="en"' in en

    de = client.get(f'/v/{code}?lang=de', headers={'Accept-Language': 'en'}).get_data(as_text=True)
    assert 'Das Dokument ist gültig' in de

    # невідома мова - українська, як і раніше
    assert 'Документ дійсний' in client.get(f'/v/{code}', headers={'Accept-Language': 'fr'}).get_data(as_text=True)


def test_receipt_pdf_renders_in_other_languages(client):
    h = _login(client)
    tx_id = _first_tx(client, h)
    for lang in ('en', 'ru', 'de', 'it'):
        r = client.get(f'/api/transactions/{tx_id}/receipt?lang={lang}', headers=h)
        assert r.status_code == 200 and r.data[:4] == b'%PDF'
        s = client.get(f'/api/transactions/statement?report_type=detailed&lang={lang}', headers=h)
        assert s.status_code == 200 and s.data[:4] == b'%PDF'


def test_tr_outside_a_request_is_ukrainian():
    assert tr('Квитанція') == 'Квитанція'


def test_tr_text_translates_stored_descriptions_inside_a_request(client):
    from flask import Flask
    app = Flask(__name__)
    with app.test_request_context('/', headers={'Accept-Language': 'en'}):
        assert tr_text('Поповнення на 410.00 TAX.') == 'Top-up of 410.00 TAX.'
        assert tr_text('Донат: Фонд') == 'Donation: Фонд'
        assert tr_text('something else') == 'something else'
    with app.test_request_context('/?lang=de'):
        assert tr_text('Переказ по картці') == 'Kartenüberweisung'
    with app.test_request_context('/'):
        assert tr_text('Переказ по картці') == 'Переказ по картці'


def test_server_messages_file_is_in_sync_with_the_app_table():
    path = Path('backend/i18n_messages.json')
    before = path.read_text()
    subprocess.run([sys.executable, 'scripts/sync_i18n.py'], check=True, capture_output=True)
    after = path.read_text()
    assert json.loads(before) == json.loads(after), 'run python scripts/sync_i18n.py and commit i18n_messages.json'
