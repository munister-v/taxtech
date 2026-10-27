"""Deposit routes — навчальні строкові депозити (віртуальні гривні, VUAH).

Депозит — це заморожена сума на фіксований термін (term_months) з нарахуванням
відсотків по закінченні. Дострокове закриття (early=True) може спричинити
штраф (залежить від deposit_service). Наприкінці строку — auto_renew
автоматично продовжує депозит на той самий термін.

Користувач: list/create/get/close власних депозитів.
(Адмін-панель вихідного проєкту прибрано — у пісочниці лише клієнтський API.)
"""
from __future__ import annotations

from flask import Blueprint, jsonify, request, g

from ..services.deposit_service import DepositService  # вся бізнес-логіка строкових депозитів
from .helpers import api_error, auth_required          # авторизація і форматування помилок

deposit_bp = Blueprint('deposits', __name__, url_prefix='/api')
_svc = DepositService()   # stateless singleton


# ── Звичайний користувач ──────────────────────────────────────────────────────

@deposit_bp.get('/deposits')
@auth_required
def list_deposits():
    """GET /api/deposits — список депозитів поточного користувача.

    Повертає всі депозити (активні і закриті) для відображення в UI.
    """
    try:
        return jsonify({'ok': True, 'data': _svc.list_deposits(g.current_user['id'])})
    except Exception as exc:
        return api_error(str(exc))


@deposit_bp.post('/deposits')
@auth_required
def create_deposit():
    """POST /api/deposits — відкрити новий строковий депозит.

    Body:
      amount       (float)  — сума, яку заморожуємо (списується з рахунку)
      term_months  (int)    — термін у місяцях (1, 3, 6, 12 тощо)
      auto_renew   (bool)   — автоматично продовжувати після закінчення строку
      description  (str)    — довільна мітка (необов'язково)

    Повертає 201 Created з об'єктом новоствореного депозиту.
    """
    try:
        data         = request.get_json(force=True) or {}
        amount       = float(data.get('amount')      or 0)      # 0 -> сервіс відхилить як некоректне
        term_months  = int(data.get('term_months')   or 0)      # 0 -> сервіс відхилить
        auto_renew   = bool(data.get('auto_renew', False))      # дефолт: не продовжувати
        description  = str(data.get('description')   or '').strip()
        dep = _svc.create_deposit(
            g.current_user['id'], amount, term_months,
            auto_renew=auto_renew, description=description,
        )
        return jsonify({'ok': True, 'data': dep}), 201   # 201: ресурс створено
    except Exception as exc:
        return api_error(str(exc))


@deposit_bp.get('/deposits/<int:deposit_id>')
@auth_required
def get_deposit(deposit_id: int):
    """GET /api/deposits/{id} — деталі конкретного депозиту.

    Сервіс перевіряє, що депозит належить поточному користувачу;
    якщо ні — підніме виняток і повернемо 404.
    """
    try:
        return jsonify({'ok': True, 'data': _svc.get_deposit(deposit_id, g.current_user['id'])})
    except Exception as exc:
        return api_error(str(exc), 404)   # 404: не знайдено або чужий


@deposit_bp.post('/deposits/<int:deposit_id>/close')
@auth_required
def close_deposit(deposit_id: int):
    """POST /api/deposits/{id}/close — закрити депозит і повернути кошти на рахунок.

    Body:
      early (bool) — True = дострокове закриття (може бути штраф по відсотках)

    Сума + нараховані відсотки (або сума - штраф при достроковому закритті)
    повертаються на головний рахунок користувача.
    """
    try:
        data   = request.get_json(force=True) or {}
        early  = bool(data.get('early', False))   # дефолт: закриття по закінченні строку
        result = _svc.close_deposit(deposit_id, g.current_user['id'], early=early)
        return jsonify({'ok': True, 'data': result})
    except Exception as exc:
        return api_error(str(exc))

