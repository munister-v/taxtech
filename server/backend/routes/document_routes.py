"""Єдине сховище документів: список, видача квитанції з кодом, QR і публічна перевірка.

  GET /api/documents                  — документи користувача (квитанції й виписки)
  GET /api/documents/receipt/<tx_id>  — код і посилання перевірки квитанції (створює, якщо ще немає)
  GET /api/verify/<код>               — публічна JSON-перевірка, без особистих даних
  GET /api/qr/<код>.svg               — QR із посиланням перевірки
  GET /v/<код>                        — публічна сторінка перевірки (її відкриває QR)
"""
from __future__ import annotations

from flask import Blueprint, Response, g, jsonify, request

from ..services.document_service import (
    DocumentService, KIND_RECEIPT, KIND_STATEMENT, normalize_code, qr_svg, verify_url,
)
from .helpers import api_error, auth_required

document_bp = Blueprint('documents', __name__)
verify_page_bp = Blueprint('verify_page', __name__)
_svc = DocumentService()


@document_bp.get('/documents')
@auth_required
def list_documents():
    kind = request.args.get('kind')
    limit = request.args.get('limit', 100, type=int)
    rows = _svc.list_for_user(g.current_user['id'], kind=kind, limit=limit)
    return jsonify({'ok': True, 'data': [_svc.present(r, request.url_root) for r in rows], 'total': len(rows)})


@document_bp.get('/documents/receipt/<int:tx_id>')
@auth_required
def receipt_document(tx_id: int):
    """Видає (або повертає наявний) документ-квитанцію без побудови PDF."""
    try:
        from ..services.statement_service import StatementService
        res = StatementService().generate_receipt_with_meta(g.current_user['id'], tx_id, verify_root=request.url_root)
        return jsonify({'ok': True, 'data': _svc.present(res['document'], request.url_root)})
    except Exception as exc:
        return api_error(str(exc))


@document_bp.get('/verify/<code>')
def verify_json(code: str):
    v = _svc.verification(code)
    if not v:
        return jsonify({'ok': False, 'error': 'Документ не знайдено.'}), 404
    return jsonify({'ok': True, 'data': {**v, 'verify_url': verify_url(v['code'], request.url_root)}})


@document_bp.get('/qr/<code>.svg')
def qr_image(code: str):
    norm = normalize_code(code)
    if not norm:
        return api_error('Невірний код.', 404)
    return Response(qr_svg(verify_url(norm, request.url_root)), mimetype='image/svg+xml',
                    headers={'Cache-Control': 'public, max-age=86400'})


@verify_page_bp.get('/v/<code>')
def verify_page(code: str):
    html, status = _svc.verification_page(code, request.url_root)
    return Response(html, status=status, mimetype='text/html',
                    headers={'Cache-Control': 'no-store', 'X-Robots-Tag': 'noindex'})
