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
import math
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
                rows.append(('Операція', meta['tx_type']))
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
            _sheet_head(f'{kind.upper()} · TAXTECH') + head_html + hero +
            f'<div class="perf"></div><div class="rows">{table}</div><div class="perf"></div>'
            f'<div class="hash"><span>Відбиток SHA-256</span><code>{d[:32]}<br>{d[32:]}</code></div>'
            f'<div class="qrrow"><div class="qr">{qr}</div>'
            '<p>QR веде на цю сторінку. Кожен документ має власний код: перевірка звіряє його з реєстром операцій '
            'і не показує особистих даних.</p></div>'
            f'<div class="checked">Перевірено {_when(datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S"))}</div>'
            + _sheet_end())
        return _page(f'{kind} {v["code"]}', body, ok=bool(v['intact'])), 200


# ── оформлення сторінки перевірки ────────────────────────────────────────────

_MONTHS = ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня',
           'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня']


def _money(v) -> str:
    return f'{float(v or 0):,.2f}'.replace(',', ' ').replace('.', ',')


def _when(ts: str) -> str:
    try:
        d = datetime.strptime(ts[:19], '%Y-%m-%d %H:%M:%S')
        return f'{d.day} {_MONTHS[d.month - 1]} {d.year}, {d:%H:%M} UTC'
    except ValueError:
        return f'{ts} UTC'


def _rosette(size: int, curves: int, lobes: int, pts: int = 120, depth: float = 0.26, width: float = 0.5) -> str:
    """Гільошна розетка: обертові копії рози з другою гармонікою, як на банкноті."""
    c, r0 = size / 2, size / 2 * 0.92
    paths = []
    for k in range(curves):
        ph = 2 * math.pi * k / curves
        pt = []
        for i in range(pts + 1):
            t = 2 * math.pi * i / pts
            r = r0 * (0.6 + depth * math.cos(lobes * t + ph) + 0.07 * math.cos(2 * lobes * t - ph))
            pt.append(f'{c + r * math.cos(t):.1f} {c + r * math.sin(t):.1f}')
        paths.append('M' + 'L'.join(pt) + 'Z')
    rings = ''.join(f'<circle cx="{c}" cy="{c}" r="{r0 * f:.1f}"/>' for f in (1.0, 0.97, 0.3, 0.27))
    return (f'<svg viewBox="0 0 {size} {size}" fill="none" stroke="currentColor" stroke-width="{width}" aria-hidden="true">'
            f'<path d="{" ".join(paths)}"/>{rings}</svg>')


def _wave_band(lines: int = 9) -> str:
    out = []
    for k in range(lines):
        ph = k * math.pi / lines
        pt = [f'{x:.1f} {15 + 12 * math.sin(2 * math.pi * 2 * x / 400 + ph):.2f}' for x in range(0, 401, 8)]
        out.append('M' + 'L'.join(pt))
    return ('<svg viewBox="0 0 400 30" preserveAspectRatio="none" fill="none" stroke="currentColor" stroke-width=".6" '
            f'aria-hidden="true"><path d="{" ".join(out)}"/></svg>')


def _medal(ok: bool, glyph: str = '') -> str:
    ticks = ''.join(
        f'<line x1="52" y1="3" x2="52" y2="{6 if i % 5 else 8}" transform="rotate({i * 6} 52 52)"/>' for i in range(60))
    if ok:
        mark = '<path d="M33 54l13 13 25-29" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
    elif glyph == '!':
        mark = '<path d="M52 32v26" stroke-width="7" stroke-linecap="round"/><circle cx="52" cy="71" r="4.2" stroke="none" fill="currentColor"/>'
    else:
        mark = '<path d="M44 42a8 8 0 1 1 11 7c-3 2-3 4-3 8" stroke-width="6" stroke-linecap="round" fill="none"/><circle cx="52" cy="71" r="4.2" stroke="none" fill="currentColor"/>'
    return (f'<div class="medal {"ok" if ok else "bad"}"><div class="ros">{_rosette(104, 18, 7, 80, 0.24, 0.45)}</div>'
            f'<svg class="face" viewBox="0 0 104 104" stroke="currentColor" aria-hidden="true">'
            f'<g stroke-width="1" opacity=".7">{ticks}</g><circle cx="52" cy="52" r="33" class="disc"/>{mark}</svg></div>')


def _sheet_head(label: str) -> str:
    return (f'<section class="sheet"><div class="bgros">{_rosette(360, 30, 9, 140, 0.28, 0.5)}</div>'
            f'<div class="ribbon">{_wave_band()}<span>{escape(label)}</span></div>')


def _sheet_end() -> str:
    micro = 'STATE TAX UNIVERSITY · TAXTECH · VIRTUAL FINANCE · ' * 8
    return f'<div class="micro">{micro}</div></section><p class="foot">Навчальний документ TaxTech: токени TAX не є грошима. Особисті дані приховано.</p>'


def _page(title: str, body: str, ok: bool = True) -> str:
    return f"""<!doctype html><html lang="uk"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex">
<meta name="theme-color" content="#000000"><title>{escape(title)} · TaxTech</title><style>
:root{{color-scheme:dark;--gold:#FFD400;--ok:#4fd18b;--bad:#ff6b6b;--mute:#8e8e93;--serif:ui-serif,'New York',Georgia,'Times New Roman',serif}}
*{{box-sizing:border-box}}
body{{margin:0;min-height:100vh;color:#f5f5f7;font:16px/1.45 -apple-system,BlinkMacSystemFont,'SF Pro Text',Segoe UI,Roboto,sans-serif;
background:radial-gradient(120% 60% at 50% -10%,rgba(255,212,0,.14),transparent 60%),#000;padding:26px 16px 40px;display:flex;justify-content:center}}
main{{width:100%;max-width:470px}}
.brand{{text-align:center;letter-spacing:.34em;font-size:10.5px;color:var(--gold);font-weight:700;margin:4px 0 20px}}
.sheet{{position:relative;overflow:hidden;text-align:center;padding:16px 22px 14px;border-radius:26px;
background:linear-gradient(165deg,rgba(255,212,0,.09),transparent 40%),#18181a;border:1px solid rgba(255,212,0,.42);
box-shadow:0 30px 70px rgba(0,0,0,.6),inset 0 1px 0 rgba(255,255,255,.07)}}
.sheet::after{{content:'';position:absolute;inset:6px;border-radius:21px;border:1px solid rgba(255,212,0,.14);pointer-events:none}}
.sheet>*{{position:relative}}
.bgros{{position:absolute!important;right:-120px;top:-90px;width:360px;height:360px;color:var(--gold);opacity:.09;pointer-events:none}}
.bgros svg,.ros svg{{width:100%;height:100%;display:block}}
.ribbon{{position:relative;height:30px;margin:2px -22px 10px;color:rgba(255,212,0,.6);display:grid;place-items:center;
-webkit-mask-image:linear-gradient(90deg,transparent,#000 14%,#000 86%,transparent);mask-image:linear-gradient(90deg,transparent,#000 14%,#000 86%,transparent)}}
.ribbon svg{{position:absolute;inset:0;width:100%;height:100%}}
.ribbon span{{position:relative;background:#18181a;border:1px solid rgba(255,212,0,.55);border-radius:99px;padding:4px 13px;
font-size:9.5px;font-weight:700;letter-spacing:.22em;color:var(--gold)}}
.medal{{position:relative;width:124px;height:124px;margin:10px auto 8px}}
.medal.ok{{color:var(--ok)}}.medal.bad{{color:var(--bad)}}
.medal .ros{{position:absolute;inset:0;opacity:.75}}
.medal .face{{position:absolute;inset:0;width:100%;height:100%}}
.medal .disc{{fill:rgba(0,0,0,.55);stroke-width:1.2}}
.medal::before{{content:'';position:absolute;inset:-6px;border-radius:50%;background:radial-gradient(circle,currentColor,transparent 68%);opacity:.18}}
h1{{font:600 27px/1.15 var(--serif);letter-spacing:-.3px;margin:6px 0 6px}}
.sub{{color:var(--mute);margin:0 0 12px;font-size:14.5px}}.sub.small{{font-size:12.5px}}
.amount{{font:600 46px/1.1 var(--serif);letter-spacing:-.5px;margin:12px 0 6px;font-variant-numeric:tabular-nums}}
.amount small{{font:700 12px/1 -apple-system,sans-serif;letter-spacing:.2em;color:var(--gold);margin-left:8px;vertical-align:.7em}}
.amount.in{{color:var(--ok)}}
.perf{{position:relative;height:0;border-top:1.5px dashed rgba(255,255,255,.16);margin:16px -22px}}
.perf::before,.perf::after{{content:'';position:absolute;top:-8px;width:16px;height:16px;border-radius:50%;background:#000;border:1px solid rgba(255,212,0,.42)}}
.perf::before{{left:-9px;clip-path:inset(0 0 0 50%)}}.perf::after{{right:-9px;clip-path:inset(0 50% 0 0)}}
.rows{{text-align:left}}
.row{{display:flex;align-items:baseline;gap:9px;padding:9px 0;font-size:14.5px}}
.row span{{color:var(--mute);flex-shrink:0}}
.row i{{flex:1;min-width:12px;border-bottom:1.5px dotted rgba(255,255,255,.2);transform:translateY(-3px)}}
.row b{{font-weight:600;text-align:right;overflow-wrap:anywhere;font-variant-numeric:tabular-nums}}
.mono{{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;letter-spacing:.04em}}
.hash{{text-align:left;background:rgba(0,0,0,.35);border:1px solid rgba(255,255,255,.07);border-radius:14px;padding:11px 14px;margin:0 0 14px}}
.hash span{{display:block;font-size:11px;letter-spacing:.14em;text-transform:uppercase;color:var(--mute);margin-bottom:5px}}
code{{font:11.5px/1.55 ui-monospace,Menlo,monospace;color:#d6d6db;word-break:break-all}}
.qrrow{{display:flex;gap:14px;align-items:center;text-align:left}}
.qr{{flex:0 0 92px;height:92px;background:#fff;border-radius:12px;padding:7px;box-shadow:0 6px 18px rgba(0,0,0,.4)}}
.qr svg{{width:100%;height:100%;display:block}}
.qrrow p{{margin:0;font-size:12.5px;color:var(--mute);line-height:1.45}}
.checked{{margin:14px 0 4px;font-size:11.5px;color:var(--mute);letter-spacing:.04em}}
.micro{{margin:10px -22px 0;white-space:nowrap;overflow:hidden;font:600 5.5px/1 ui-monospace,Menlo,monospace;letter-spacing:.1em;color:rgba(255,212,0,.42)}}
.foot{{text-align:center;color:#6c6c70;font-size:12px;margin:16px 8px 0}}
@media print{{body{{background:#fff}}}}
</style></head><body><main><div class="brand">TAXTECH · STATE TAX UNIVERSITY</div>{body}</main></body></html>"""
