# Експерименти до тез (ВІТІ, 02.12.2026)

Запуск із `server/`, кожен скрипт працює на копії бази, а не на робочій.

```bash
.venv/bin/python scripts/seed_sandbox.py --users 50 --seed 42 --reset    # з KOPIYKA_DATABASE_PATH=<копія>
KOPIYKA_DATABASE_PATH=<копія> .venv/bin/python -I ../docs/viti-2026/experiments/replay_fraud.py out.json
KOPIYKA_DATABASE_PATH=<копія> CRITICAL_MONEY_RATE_LIMIT=10000 .venv/bin/python -I ../docs/viti-2026/experiments/attacks.py attacks_api.json api
KOPIYKA_DATABASE_PATH=<копія> .venv/bin/python -I ../docs/viti-2026/experiments/attacks.py attacks_chain.json chain
```

- `replay_fraud.py` - ретроспективне відтворення: переказ оцінюється на стані бази без пізніших операцій, годинник антифроду зафіксовано на моменті переказу; шари l1, l1+l2, l1+l2+l3.
- `attacks.py api` - повтор запиту, гонка за залишок, перебір пароля, перевірка хеш-ланцюга після реальних переказів; `chain` - 998 підмін історії.
- Налагоджувальна вибірка: `--users 50 --seed 42`, тестова: `--users 100 --seed 7`. Підсумки - `fraud_replay_summary.json`, `attacks_*.json`.
