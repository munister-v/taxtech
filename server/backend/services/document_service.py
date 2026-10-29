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
            body = (f'<div class="seal bad">✕</div><h1>Документ не знайдено</h1>'
                    f'<p class="muted">Код <b>{escape(norm)}</b> не відповідає жодному документу TaxTech.</p>')
            return _page('Документ не знайдено', body), 404
        kind = 'Квитанція' if v['kind'] == KIND_RECEIPT else 'Виписка'
        status = ('<div class="seal ok">✓</div><h1>Документ дійсний</h1>'
                  '<p class="muted">Відбиток збігається з реєстром TaxTech.</p>') if v['intact'] else (
                  '<div class="seal bad">!</div><h1>Дані змінилися</h1>'
                  '<p class="muted">Відбиток документа більше не збігається з реєстром.</p>')
        rows = [('Вид', kind), ('Код', v['code']), ('Видано', v['issued_at'] + ' UTC'),
                ('Власник', v['holder']), ('Рахунок', v['account'])]
        meta = v['meta']
        if v['kind'] == KIND_RECEIPT:
            sign = '+' if v['direction'] == 'in' else '−'
            rows.insert(1, ('Сума', f"{sign}{(v['amount'] or 0):,.2f} TAX".replace(',', ' ')))
            if meta.get('tx_type'):
                rows.insert(2, ('Операція', meta['tx_type']))
        else:
            rows.insert(1, ('Період', meta.get('period') or '—'))
            rows.insert(2, ('Операцій', str(meta.get('count', '—'))))
            rows.insert(3, ('Надійшло', f"{float(meta.get('total_in') or 0):,.2f} TAX".replace(',', ' ')))
            rows.insert(4, ('Витрачено', f"{float(meta.get('total_out') or 0):,.2f} TAX".replace(',', ' ')))
        table = ''.join(f'<div class="row"><span>{escape(k)}</span><b>{escape(str(val))}</b></div>' for k, val in rows)
        body = (f'{status}<div class="card">{table}'
                f'<div class="row hash"><span>Відбиток SHA-256</span><code>{escape(v["digest"])}</code></div></div>'
                f'<p class="muted small">Навчальний документ TaxTech: токени TAX не є грошима. '
                f'Особисті дані приховано.</p>')
        return _page(f'{kind} {v["code"]}', body), 200


def _page(title: str, body: str) -> str:
    return f"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<title>{escape(title)} · TaxTech</title><style>
:root{{color-scheme:dark}}*{{box-sizing:border-box}}
body{{margin:0;min-height:100vh;background:#000;color:#f5f5f7;font:16px/1.45 -apple-system,BlinkMacSystemFont,'SF Pro Text',Segoe UI,Roboto,sans-serif;
display:flex;justify-content:center;padding:28px 16px}}
main{{width:100%;max-width:460px;text-align:center}}
.brand{{letter-spacing:.32em;font-size:11px;color:#FFD400;font-weight:700;margin:6px 0 26px}}
.seal{{width:84px;height:84px;margin:0 auto 14px;border-radius:50%;display:grid;place-items:center;font-size:38px;font-weight:700;
border:1.5px solid currentColor;background:radial-gradient(circle at 30% 25%,rgba(255,255,255,.14),transparent 70%),repeating-radial-gradient(circle,transparent 0 5px,rgba(255,255,255,.07) 5px 6px)}}
.seal.ok{{color:#4fd18b}}.seal.bad{{color:#ff6b6b}}
h1{{font-size:26px;margin:0 0 6px;letter-spacing:-.4px}}.muted{{color:#8e8e93;margin:0 0 22px}}.small{{font-size:12.5px;margin-top:18px}}
.card{{text-align:left;background:linear-gradient(160deg,rgba(255,212,0,.08),transparent 55%),#1c1c1e;border:1px solid rgba(255,212,0,.3);border-radius:22px;padding:6px 18px}}
.row{{display:flex;justify-content:space-between;gap:14px;padding:13px 0;border-top:1px solid rgba(255,255,255,.07);font-size:14.5px}}
.row:first-child{{border-top:0}}.row span{{color:#8e8e93}}.row b{{font-weight:600;text-align:right;overflow-wrap:anywhere}}
.hash{{flex-direction:column}}code{{font:11px/1.5 ui-monospace,Menlo,monospace;color:#c9c9ce;word-break:break-all}}
</style></head><body><main><div class="brand">TAXTECH · STATE TAX UNIVERSITY</div>{body}</main></body></html>"""
