"""Єдине сховище документів TaxTech: квитанції й виписки з кодом перевірки та QR.

Кожен документ (квитанція на операцію, виписка за період) має один запис у `documents`
й код вигляду TT-XXXX-XXXX-XXXX. Код виводиться з HMAC (SECRET_KEY) від виду, посилання й
власника, тому той самий документ завжди має той самий код, а підробити код без ключа не можна.
Код і QR із посиланням на /v/<код> друкуються в PDF. Публічна сторінка перевірки показує
лише знеособлені реквізити й звіряє відбиток документа з реєстром.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import datetime, timezone
from html import escape

from ..config import PUBLIC_BASE_URL, SECRET_KEY, USE_PG
from ..database import get_connection

KIND_RECEIPT = 'receipt'
KIND_STATEMENT = 'statement'
KINDS = (KIND_RECEIPT, KIND_STATEMENT)


def make_code(kind: str, ref: str, user_id: int) -> str:
    """TT-XXXX-XXXX-XXXX: 12 символів base32 від HMAC. Детермінований, тож повторний випуск дає той самий код."""
    mac = hmac.new(SECRET_KEY.encode(), f'{kind}|{ref}|{int(user_id)}'.encode(), hashlib.sha256).digest()
    raw = base64.b32encode(mac)[:12].decode()
    return f'TT-{raw[0:4]}-{raw[4:8]}-{raw[8:12]}'


def normalize_code(code: str) -> str:
    c = ''.join(ch for ch in (code or '').upper() if ch.isalnum())
    if c.startswith('TT'):
        c = c[2:]
    return f'TT-{c[0:4]}-{c[4:8]}-{c[8:12]}' if len(c) == 12 else ''


def base_url(request_root: str | None = None) -> str:
    return (PUBLIC_BASE_URL or request_root or 'https://bank.munister.com.ua').rstrip('/')


def verify_url(code: str, root: str | None = None) -> str:
    return f'{base_url(root)}/v/{code}'


def qr_drawing(url: str, size: float):
    """Малюнок reportlab із QR-кодом на білому тлі (для PDF і SVG)."""
    from reportlab.graphics.barcode.qr import QrCodeWidget
    from reportlab.graphics.shapes import Drawing, Rect
    from reportlab.lib import colors

    widget = QrCodeWidget(url, barLevel='M', barBorder=2)
    x0, y0, x1, y1 = widget.getBounds()
    w, h = x1 - x0, y1 - y0
    drawing = Drawing(size, size, transform=[size / w, 0, 0, size / h, -x0 * size / w, -y0 * size / h])
    drawing.add(Rect(x0, y0, w, h, fillColor=colors.white, strokeColor=None))
    drawing.add(widget)
    return drawing


def qr_svg(url: str, size: int = 240) -> str:
    from reportlab.graphics import renderSVG
    return renderSVG.drawToString(qr_drawing(url, size))


def _mask_name(name: str | None) -> str:
    parts = [p for p in (name or '').split() if p]
    return ' '.join(p[0] + '***' for p in parts) or '—'


class DocumentService:
    _ready = False

    def _ensure(self) -> None:
        if DocumentService._ready:
            return
        pk = 'SERIAL PRIMARY KEY' if USE_PG else 'INTEGER PRIMARY KEY'
        with get_connection() as conn:
            conn.execute(
                f"""CREATE TABLE IF NOT EXISTS documents (
                    id {pk},
                    user_id INTEGER NOT NULL,
                    kind TEXT NOT NULL,
                    ref TEXT NOT NULL,
                    code TEXT NOT NULL UNIQUE,
                    title TEXT NOT NULL,
                    amount REAL,
                    direction TEXT,
                    digest TEXT NOT NULL,
                    meta TEXT NOT NULL DEFAULT '{{}}',
                    created_at TEXT NOT NULL,
                    UNIQUE (user_id, kind, ref)
                )"""
            )
            conn.execute('CREATE INDEX IF NOT EXISTS idx_documents_user ON documents(user_id, created_at)')
        DocumentService._ready = True

    # ── запис і читання ──────────────────────────────────────────────────────
    def issue(self, user_id: int, kind: str, ref: str, title: str, digest: str,
              amount: float | None = None, direction: str | None = None, meta: dict | None = None) -> dict:
        """Створює документ або повертає наявний (код той самий); відбиток і метадані оновлює."""
        if kind not in KINDS:
            raise ValueError('Невідомий вид документа.')
        self._ensure()
        code = make_code(kind, ref, user_id)
        now = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
        payload = json.dumps(meta or {}, ensure_ascii=False, sort_keys=True)
        with get_connection() as conn:
            row = conn.execute('SELECT id FROM documents WHERE code = %s', (code,)).fetchone()
            if row:
                conn.execute('UPDATE documents SET title=%s, amount=%s, direction=%s, digest=%s, meta=%s WHERE id=%s',
                             (title, amount, direction, digest, payload, row['id']))
            else:
                conn.execute(
                    'INSERT INTO documents (user_id, kind, ref, code, title, amount, direction, digest, meta, created_at) '
                    'VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)',
                    (user_id, kind, ref, code, title, amount, direction, digest, payload, now))
        return self.by_code(code) or {}

    def by_code(self, code: str) -> dict | None:
        self._ensure()
        code = normalize_code(code)
        if not code:
            return None
        with get_connection() as conn:
            row = conn.execute('SELECT * FROM documents WHERE code = %s', (code,)).fetchone()
        return self._row(row) if row else None

    def list_for_user(self, user_id: int, kind: str | None = None, limit: int = 100) -> list[dict]:
        self._ensure()
        limit = max(1, min(int(limit), 300))
        sql = 'SELECT * FROM documents WHERE user_id = %s'
        params: list = [user_id]
        if kind in KINDS:
            sql += ' AND kind = %s'
            params.append(kind)
        sql += ' ORDER BY created_at DESC, id DESC LIMIT %s'
        params.append(limit)
        with get_connection() as conn:
            rows = conn.execute(sql, tuple(params)).fetchall()
        return [self._row(r) for r in rows]

    @staticmethod
    def _row(row: dict) -> dict:
        d = dict(row)
        try:
            d['meta'] = json.loads(d.get('meta') or '{}')
        except ValueError:
            d['meta'] = {}
        d['created_at'] = str(d.get('created_at') or '')
        return d

    @staticmethod
    def present(doc: dict, root: str | None = None) -> dict:
        """Подання для клієнтів: без внутрішніх полів, з посиланням перевірки."""
        url = verify_url(doc['code'], root)
        return {
            'id': doc['id'], 'kind': doc['kind'], 'ref': doc['ref'], 'code': doc['code'], 'title': doc['title'],
            'amount': doc.get('amount'), 'direction': doc.get('direction'), 'created_at': doc['created_at'],
            'meta': doc.get('meta') or {}, 'verify_url': url,
        }

    # ── публічна перевірка ───────────────────────────────────────────────────
    def verification(self, code: str) -> dict | None:
        """Знеособлені реквізити документа й результат звірки з реєстром."""
        doc = self.by_code(code)
        if not doc:
            return None
        from ..repositories.account_repository import AccountRepository
        from ..repositories.user_repository import UserRepository
        from .integrity_service import IntegrityService

        accounts, users = AccountRepository(), UserRepository()
        account = accounts.get_account_by_user_id(doc['user_id'])
        user = users.get_by_id(doc['user_id'])
        meta = doc.get('meta') or {}
        intact = False
        if account and doc['kind'] == KIND_RECEIPT:
            tx = accounts.get_transaction(int(doc['ref']), account['id'])
            if tx:
                tx = {**dict(tx), 'account_id': account['id']}
                intact = IntegrityService().hashes_for([tx]).get(int(tx['id'])) == doc['digest']
        elif account and doc['kind'] == KIND_STATEMENT:
            intact = self.statement_digest(accounts, account, meta) == doc['digest']
        acct_no = str((account or {}).get('account_number') or '')
        return {
            'code': doc['code'], 'kind': doc['kind'], 'title': doc['title'], 'amount': doc.get('amount'),
            'direction': doc.get('direction'), 'issued_at': doc['created_at'], 'digest': doc['digest'],
            'intact': intact, 'holder': _mask_name((user or {}).get('full_name')),
            'account': f'••{acct_no[-4:]}' if acct_no else '—', 'meta': meta,
        }

    @staticmethod
    def statement_digest(accounts, account: dict, meta: dict) -> str:
        """Відбиток виписки: SHA-256 хешів усіх її операцій у порядку видачі."""
        from .integrity_service import IntegrityService
        txs = accounts.list_transactions(account['id'], from_date=meta.get('from_date') or None,
                                         to_date=meta.get('to_date') or None, limit=1000)
        txs = [{**dict(t), 'account_id': account['id']} for t in txs]
        hashes = IntegrityService().hashes_for(txs)
        return hashlib.sha256(''.join(hashes[int(t['id'])] for t in txs).encode()).hexdigest()

    def verification_page(self, code: str, root: str | None = None) -> tuple[str, int]:
        v = self.verification(code)
        norm = normalize_code(code) or escape(code or '')
        if not v:
            body = (_sheet_head('ДОКУМЕНТ · TAXTECH') + _medal(False, '?') +
                    '<h1>Документ не знайдено</h1>'
                    f'<p class="sub">Код <b class="mono">{escape(norm)}</b> не відповідає жодному документу TaxTech.</p>'
                    '<p class="sub small">Перевірте код або скануйте QR із документа ще раз.</p>' + _sheet_end())
            return _page('Документ не знайдено', body, ok=False), 404

        receipt = v['kind'] == KIND_RECEIPT
        kind = 'Квитанція' if receipt else 'Виписка'
        meta = v['meta']
        if v['intact']:
            head_html = _medal(True) + '<h1>Документ дійсний</h1><p class="sub">Відбиток збігається з реєстром TaxTech.</p>'
        else:
            head_html = _medal(False, '!') + '<h1>Дані змінилися</h1><p class="sub">Відбиток документа більше не збігається з реєстром.</p>'

        hero = ''
        if receipt:
            sign, cls = ('+', 'in') if v['direction'] == 'in' else ('−', 'out')
            hero = f'<div class="amount {cls}">{sign}{_money(v["amount"])}<small>TAX</small></div>'
        elif meta.get('total_out') is not None:
            hero = f'<div class="amount out">−{_money(meta.get("total_out"))}<small>TAX</small></div>'

        rows = [('Вид', kind)]
        if receipt:
            if meta.get('tx_type'):
                rows.append(('Операція', _tx_label(meta['tx_type'])))
        else:
            rows += [('Період', meta.get('period') or '—'), ('Операцій', str(meta.get('count', '—'))),
                     ('Надійшло', f"{_money(meta.get('total_in'))} TAX"), ('Витрачено', f"{_money(meta.get('total_out'))} TAX")]
        rows += [('Код', v['code']), ('Видано', _when(v['issued_at'])), ('Власник', v['holder']), ('Рахунок', v['account'])]
        table = ''.join(
            f'<div class="row"><span>{escape(k)}</span><i></i><b{" class=mono" if k == "Код" else ""}>{escape(str(val))}</b></div>'
            for k, val in rows)

        d = v['digest']
        qr = qr_svg(verify_url(v['code'], root))
        qr = qr[qr.index('<svg'):]
        body = (
            _sheet_head(kind.upper()) + head_html + hero +
            f'<div class="perf"></div><div class="rows">{table}</div><div class="perf"></div>'
            f'<div class="hash"><span>Відбиток SHA-256</span><code>{d[:32]}<br>{d[32:]}</code></div>'
            f'<div class="qrbox"><div class="qr">{qr}</div><div class="qcode">{escape(v["code"])}</div>'
            '<p>Скануйте QR: сторінка звіряє документ з реєстром операцій і не показує особистих даних.</p></div>'
            f'<div class="checked">Перевірено {_when(datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"))}</div>'
            + _sheet_end())
        return _page(f'{kind} {v["code"]}', body, ok=bool(v['intact'])), 200


# ── оформлення сторінки перевірки ────────────────────────────────────────────

_MONTHS = ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня',
           'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня']


_TX_LABELS = {'marketplace_invoice': 'Оплата в магазині', 'marketplace': 'Магазин', 'transfer': 'Переказ',
              'topup': 'Поповнення', 'payment': 'Оплата', 'payout': 'Виплата', 'donation': 'Донат'}


def _tx_label(raw) -> str:
    raw = str(raw or '')
    return _TX_LABELS.get(raw) or raw.replace('_', ' ').capitalize() or 'Операція'


def _money(v) -> str:
    return f'{float(v or 0):,.2f}'.replace(',', ' ').replace('.', ',')


def _when(ts: str) -> str:
    try:
        d = datetime.strptime(ts[:19], '%Y-%m-%d %H:%M:%S')
        return f'{d.day} {_MONTHS[d.month - 1]} {d.year}, {d:%H:%M} UTC'
    except ValueError:
        return f'{ts} UTC'


# Знак TaxTech (з web/public/icons/mark-white.svg), колір береться з currentColor.
_MARK = ('<svg class="mark" viewBox="0 0 1650 1938" aria-hidden="true"><g transform="translate(0.000000,1938.000000) scale(0.100000,-0.100000)" fill="currentColor" stroke="none"> <path d="M7550 18974 c-264 -35 -474 -149 -788 -428 -125 -110 -5048 -5045 -5138 -5151 -38 -44 -108 -120 -155 -170 -47 -49 -113 -130 -147 -180 -35 -49 -105 -151 -157 -225 -52 -74 -107 -155 -121 -180 -15 -25 -44 -72 -64 -105 -128 -207 -333 -669 -374 -845 -9 -36 -27 -96 -41 -135 -13 -38 -25 -80 -25 -92 0 -13 -11 -52 -25 -88 -13 -35 -29 -100 -35 -143 -6 -44 -19 -109 -30 -145 -10 -37 -21 -93 -25 -124 -4 -32 -18 -132 -31 -222 -14 -92 -29 -251 -34 -365 -5 -110 -12 -253 -16 -316 -11 -197 21 -757 51 -883 8 -34 19 -102 25 -152 5 -49 18 -115 29 -146 10 -31 24 -88 30 -127 6 -38 19 -90 29 -114 11 -23 25 -67 32 -96 64 -270 305 -733 568 -1092 129 -175 818 -887 1485 -1534 143 -137 264 -257 270 -266 7 -8 64 -66 129 -128 140 -135 157 -140 236 -70 207 186 953 940 1096 1106 93 110 110 136 102 167 -4 14 -115 136 -249 272 -133 137 -301 311 -372 388 -71 77 -219 232 -329 345 -436 445 -498 515 -680 755 -131 174 -202 292 -276 460 -29 66 -66 149 -82 184 -15 35 -35 97 -44 137 -8 40 -22 90 -30 110 -35 83 -69 734 -47 879 7 44 17 136 23 205 6 86 17 148 35 199 14 41 25 87 25 103 0 146 283 731 467 967 116 148 218 267 378 440 61 65 157 172 215 237 57 66 341 355 630 644 289 289 1209 1211 2045 2050 835 839 1530 1533 1544 1542 42 28 101 23 152 -13 24 -18 339 -327 699 -688 361 -361 902 -901 1203 -1201 301 -300 627 -628 725 -729 443 -461 1066 -1092 1988 -2016 1098 -1099 1228 -1238 1366 -1460 184 -296 321 -628 348 -840 6 -49 20 -139 32 -200 29 -152 29 -364 0 -535 -12 -69 -26 -160 -32 -203 -5 -43 -19 -99 -30 -125 -10 -26 -24 -67 -30 -92 -21 -83 -74 -235 -91 -260 -9 -14 -22 -43 -29 -65 -11 -35 -78 -170 -172 -343 -94 -174 -322 -472 -605 -788 -45 -51 -662 -672 -1370 -1381 -1233 -1234 -2370 -2376 -2893 -2907 -284 -288 -307 -303 -401 -258 -23 10 -206 189 -470 457 -239 242 -705 710 -1036 1040 -616 614 -633 633 -633 707 0 90 -48 39 1717 1809 919 921 1706 1715 1749 1765 163 189 182 211 250 304 180 244 364 641 388 840 4 30 17 89 29 130 34 115 34 661 0 760 -12 36 -27 93 -33 128 -6 34 -19 82 -29 105 -10 23 -23 64 -30 90 -14 58 -112 256 -186 378 -124 204 -192 276 -1270 1359 -572 575 -1101 1107 -1174 1182 -74 75 -153 147 -175 159 -81 42 -72 49 -473 -354 -199 -199 -403 -409 -454 -466 -52 -58 -158 -170 -236 -251 -201 -209 -202 -203 16 -420 75 -74 231 -236 346 -359 116 -123 219 -231 230 -240 31 -27 604 -610 875 -891 135 -139 343 -355 463 -478 301 -310 320 -342 256 -433 -38 -54 -424 -435 -495 -488 -73 -56 -819 -818 -949 -970 -75 -88 -349 -364 -1892 -1908 -776 -777 -1450 -1455 -1497 -1508 -92 -103 -102 -131 -76 -201 15 -38 533 -566 1595 -1624 334 -333 995 -996 1468 -1474 474 -478 901 -901 948 -941 229 -191 447 -292 757 -350 l153 -29 127 23 c282 52 407 108 682 306 103 74 184 148 466 430 1903 1896 4895 4891 4928 4931 22 28 84 101 136 161 275 319 626 910 773 1298 62 167 89 242 113 315 13 41 33 100 43 130 11 30 20 65 21 77 0 12 12 58 26 103 14 45 31 120 39 168 8 48 23 130 34 182 12 52 21 118 21 145 0 28 7 75 15 105 56 199 59 951 5 1265 -10 61 -21 142 -24 181 -3 38 -15 97 -26 130 -11 32 -25 90 -31 129 -6 38 -18 86 -26 105 -8 19 -23 69 -33 110 -10 41 -34 118 -53 170 -20 52 -47 127 -61 165 -40 109 -162 344 -266 513 -200 324 -330 472 -935 1072 -478 474 -2335 2324 -4325 4310 -1617 1613 -1775 1768 -1880 1843 -177 126 -392 214 -586 241 -139 19 -162 19 -304 0z"/> </g></svg>')


def _status_icon(state: str) -> str:
    if state == 'ok':
        mark = '<path d="M7 12.5l3.2 3.2L17 8.8"/>'
    elif state == 'bad':
        mark = '<path d="M12 7v6.5"/><circle cx="12" cy="17" r=".6"/>'
    else:
        mark = '<path d="M9.6 9.4a2.5 2.5 0 1 1 3.6 2.2c-.8.5-1.2 1-1.2 2"/><circle cx="12" cy="17" r=".6"/>'
    return (f'<div class="status {state}"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" '
            f'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">{mark}</svg></div>')


def _medal(ok: bool, glyph: str = '') -> str:
    return _status_icon('ok' if ok else ('bad' if glyph == '!' else 'unknown'))


def _sheet_head(label: str) -> str:
    return (f'<section class="sheet"><div class="band"><div class="glow"></div>{_MARK}'
            '<div class="word">TaxTech</div><div class="uni">State Tax University</div>'
            f'<div class="tag">{escape(label)}</div></div><div class="body">')


def _sheet_end() -> str:
    return ('</div></section><p class="foot">Навчальний документ TaxTech: токени TAX не є грошима.<br>'
            'Особисті дані приховано.</p>')


def _page(title: str, body: str, ok: bool = True) -> str:
    return f"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<meta name="color-scheme" content="light dark"><title>{escape(title)} · TaxTech</title><style>
:root{{--bg:#ececea;--card:#fff;--ink:#111;--mute:#76767b;--line:#e9e9e7;--soft:#f6f6f4;--ok:#16a05a;--bad:#d64545;--notch:#ececea}}
@media (prefers-color-scheme:dark){{:root{{--bg:#08080a;--card:#16161a;--ink:#f4f4f5;--mute:#8d8d93;--line:#26262b;--soft:#1d1d22;--ok:#3ccf82;--bad:#ff6b6b;--notch:#08080a}}}}
*{{box-sizing:border-box}}
body{{margin:0;min-height:100vh;background:var(--bg);color:var(--ink);padding:30px 16px 44px;display:flex;justify-content:center;text-align:center;
font:15px/1.45 -apple-system,BlinkMacSystemFont,'SF Pro Text','Inter',Segoe UI,Roboto,sans-serif;-webkit-font-smoothing:antialiased}}
main{{width:100%;max-width:420px}}
.sheet{{position:relative;background:var(--card);border-radius:28px;overflow:hidden;
box-shadow:0 1px 0 rgba(255,255,255,.4) inset,0 2px 4px rgba(0,0,0,.05),0 24px 60px rgba(0,0,0,.14)}}
.band{{position:relative;padding:30px 20px 80px;background:#0d0d0f;color:#fff;overflow:hidden}}
.band::after{{content:'';position:absolute;left:0;right:0;bottom:-1px;height:34px;background:var(--card);border-radius:50% 50% 0 0/100% 100% 0 0}}
.glow{{position:absolute;left:50%;top:-40px;width:340px;height:240px;transform:translateX(-50%);
background:radial-gradient(closest-side,rgba(255,255,255,.2),transparent);pointer-events:none}}
.mark{{position:relative;width:34px;height:40px;display:block;margin:0 auto;color:#fff}}
.word{{position:relative;margin-top:12px;font-size:22px;font-weight:700;letter-spacing:-.02em}}
.uni{{position:relative;margin-top:4px;font-size:10px;font-weight:600;letter-spacing:.32em;text-transform:uppercase;color:rgba(255,255,255,.55)}}
.body{{position:relative;padding:0 26px 24px;margin-top:-62px}}
.tag{{position:relative;display:inline-block;margin-top:16px;padding:5px 14px;border:1px solid rgba(255,255,255,.28);border-radius:99px;
font-size:10.5px;font-weight:700;letter-spacing:.2em;color:rgba(255,255,255,.85)}}
.status{{position:relative;z-index:2;width:76px;height:76px;border-radius:50%;display:grid;place-items:center;margin:0 auto 16px;
background:var(--card);box-shadow:0 0 0 6px var(--card),0 10px 26px rgba(0,0,0,.18)}}
.status svg{{width:34px;height:34px}}
.status.ok{{color:var(--ok);background:color-mix(in srgb,var(--ok) 13%,var(--card))}}
.status.bad{{color:var(--bad);background:color-mix(in srgb,var(--bad) 13%,var(--card))}}
.status.unknown{{color:var(--mute);background:var(--soft)}}
h1{{font-size:26px;line-height:1.18;font-weight:700;letter-spacing:-.025em;margin:0 0 6px}}
.sub{{color:var(--mute);margin:0 auto;font-size:14px;max-width:300px}}.sub.small{{font-size:13px;margin-top:10px}}
.amount{{display:inline-block;margin:22px 0 0;padding:12px 22px;border-radius:18px;background:var(--soft);
font-size:36px;line-height:1.1;font-weight:700;letter-spacing:-.03em;font-variant-numeric:tabular-nums}}
.amount small{{font-size:12px;font-weight:700;letter-spacing:.1em;color:var(--mute);margin-left:7px}}
.amount.in{{color:var(--ok)}}
.perf{{position:relative;height:0;border-top:1.5px dashed var(--line);margin:24px -26px 8px}}
.perf::before,.perf::after{{content:'';position:absolute;top:-10px;width:20px;height:20px;border-radius:50%;background:var(--notch)}}
.perf::before{{left:-10px}}.perf::after{{right:-10px}}
.rows{{text-align:left}}
.row{{display:flex;justify-content:space-between;align-items:baseline;gap:16px;padding:11px 0;font-size:14px;border-bottom:1px solid var(--line)}}
.row:last-child{{border-bottom:0}}
.row span{{color:var(--mute);flex-shrink:0}}
.row i{{display:none}}
.row b{{font-weight:600;text-align:right;overflow-wrap:anywhere;font-variant-numeric:tabular-nums}}
.mono{{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.03em}}
.hash{{background:var(--soft);border-radius:14px;padding:13px 14px;margin:8px 0 24px}}
.hash span{{display:block;font-size:10.5px;font-weight:700;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);margin-bottom:7px}}
code{{font:11.5px/1.6 ui-monospace,Menlo,monospace;color:var(--ink);word-break:break-all}}
.qrbox{{display:flex;flex-direction:column;align-items:center}}
.qr{{width:132px;height:132px;background:#fff;border:1px solid var(--line);border-radius:16px;padding:9px}}
.qr svg{{width:100%;height:100%;display:block}}
.qcode{{margin-top:12px;font:700 14px ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.08em}}
.qrbox p{{margin:8px 0 0;max-width:280px;font-size:12.5px;color:var(--mute);line-height:1.5}}
.checked{{margin:22px 0 0;padding-top:16px;border-top:1px solid var(--line);font-size:12px;color:var(--mute)}}
.foot{{color:var(--mute);font-size:12px;line-height:1.5;margin:20px 12px 0}}
</style></head><body><main>{body}</main></body></html>"""
