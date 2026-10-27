"""Дослідницький API: де виконувати AI-задачу — на iPhone чи на сервері.

Усі ендпоінти за префіксом /api/research. Кожна відповідь має конверт
{"ok": true, ...} і поле server_ms — wall-time (float, мс), витрачений
усередині обробника. Клієнт віднімає server_ms від повного часу запиту,
щоб отримати мережеву складову (RTT + передача).

  GET  /ping         — без авторизації, для вимірювання RTT
  POST /echo         — без авторизації, сире тіло до 5 МБ, для оцінки пропускної здатності
  POST /fraud/score  — Bearer-токен; скоринг FraudEngine з вибором шарів l1/l2/l3
  POST /llm          — Bearer-токен; Anthropic Messages API, моделі small/large

Гроші пісочниці віртуальні (VUAH) — скоринг нічого не блокує і не записує.
"""
from __future__ import annotations

import time
from datetime import datetime, timezone

from flask import Blueprint, g, jsonify, request

from ..config import RESEARCH_ECHO_MAX_BYTES
from ..services.research_service import FraudResearchService, LLMResearchService, ResearchError
from .helpers import auth_required

research_bp = Blueprint('research', __name__, url_prefix='/api/research')
fraud_service = FraudResearchService()
llm_service = LLMResearchService()

_ECHO_CHUNK = 64 * 1024


def _elapsed_ms(started: float) -> float:
    """Мілісекунди з моменту started (time.perf_counter), округлені до мікросекунд."""
    return round((time.perf_counter() - started) * 1000.0, 3)


def _research_error(exc: ResearchError, started: float):
    resp = jsonify({'ok': False, 'error': str(exc), 'server_ms': _elapsed_ms(started)})
    return resp, exc.status


# ── RTT ───────────────────────────────────────────────────────────────────────

@research_bp.get('/ping')
def ping():
    """GET /api/research/ping — мінімальна відповідь для вимірювання RTT.

    server_time — UTC ISO-8601 з мілісекундами (для оцінки зсуву годинників).
    """
    started = time.perf_counter()
    now = datetime.now(timezone.utc).isoformat(timespec='milliseconds')
    return jsonify({'ok': True, 'server_time': now, 'server_ms': _elapsed_ms(started)})


# ── Пропускна здатність ───────────────────────────────────────────────────────

@research_bp.post('/echo')
def echo():
    """POST /api/research/echo — приймає сирі байти (будь-який Content-Type) до 5 МБ.

    Тіло читається потоково шматками по 64 КБ і не зберігається. Повертає
    кількість отриманих байтів. Понад RESEARCH_ECHO_MAX_BYTES — 413.
    """
    started = time.perf_counter()
    declared = request.content_length
    if declared is not None and declared > RESEARCH_ECHO_MAX_BYTES:
        return _research_error(ResearchError(
            f'Тіло завелике: {declared} байт (максимум {RESEARCH_ECHO_MAX_BYTES}).', 413), started)

    received = 0
    stream = request.stream
    while True:
        chunk = stream.read(_ECHO_CHUNK)
        if not chunk:
            break
        received += len(chunk)
        if received > RESEARCH_ECHO_MAX_BYTES:
            return _research_error(ResearchError(
                f'Тіло завелике (максимум {RESEARCH_ECHO_MAX_BYTES} байт).', 413), started)

    return jsonify({'ok': True, 'bytes_received': received, 'server_ms': _elapsed_ms(started)})


# ── Серверний fraud-скоринг ───────────────────────────────────────────────────

@research_bp.post('/fraud/score')
@auth_required
def fraud_score():
    """POST /api/research/fraud/score — скоринг гіпотетичного переказу.

    Body: { amount, balance?, description?, recipient_account?,
            recipient_account_id?, layers?: ["l1","l2","l3"] }
    Відповідь: { ok, score, level, flags, details, confidence,
                 layers_run, layers_requested, server_ms }
    """
    started = time.perf_counter()
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return _research_error(ResearchError('Очікується JSON-об\'єкт у тілі запиту.'), started)
    try:
        result = fraud_service.score(int(g.current_user['id']), data)
    except ResearchError as exc:
        return _research_error(exc, started)
    return jsonify({'ok': True, **result, 'server_ms': _elapsed_ms(started)})


# ── Хмарна LLM ────────────────────────────────────────────────────────────────

@research_bp.post('/llm')
@auth_required
def llm():
    """POST /api/research/llm — виклик Claude (Anthropic Messages API).

    Body: { task: "support"|"scam_check"|"receipt", prompt, tier: "small"|"large" }
    Відповідь: { ok, text, model, input_tokens, output_tokens, stop_reason,
                 task, tier, server_ms }
    Без ANTHROPIC_API_KEY на сервері — HTTP 503 з поясненням.
    """
    started = time.perf_counter()
    data = request.get_json(silent=True)
    if not isinstance(data, dict):
        return _research_error(ResearchError('Очікується JSON-об\'єкт у тілі запиту.'), started)
    try:
        result = llm_service.complete(data)
    except ResearchError as exc:
        return _research_error(exc, started)
    return jsonify({'ok': True, **result, 'server_ms': _elapsed_ms(started)})
