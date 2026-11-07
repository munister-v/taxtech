"""Збирає серверні тексти (описи операцій, повідомлення) із таблиці перекладів застосунку.

Таблиця одна: ios/Kopiyka/Resources/translations.json. Скрипт бере з неї лише ті записи,
чий український текст справді є в коді сервера (рядок або шаблон f-рядка з %@), і кладе
у backend/i18n_messages.json - звідти `tr_text` перекладає описи операцій у PDF.

    python scripts/sync_i18n.py
"""
from __future__ import annotations

import ast
import glob
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TABLE = ROOT.parent / 'ios/Kopiyka/Resources/translations.json'
OUT = ROOT / 'backend/i18n_messages.json'
CYR = re.compile('[А-Яа-яІіЇїЄєҐґ]')


def _text(node: ast.AST) -> str | None:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.JoinedStr):
        return ''.join(v.value if isinstance(v, ast.Constant) else '%@' for v in node.values)
    return None


def server_strings() -> set[str]:
    found: set[str] = set()
    for path in glob.glob(str(ROOT / 'backend/**/*.py'), recursive=True):
        for node in ast.walk(ast.parse(Path(path).read_text())):
            s = _text(node) if isinstance(node, (ast.Constant, ast.JoinedStr)) else None
            if s and CYR.search(s) and len(s) < 400:
                found.add(s)
    return found


def main() -> None:
    table = json.loads(TABLE.read_text())
    out = {}
    for s in sorted(server_strings()):
        row = table.get(s)
        if row and all(row.get(k) for k in ('en', 'ru', 'de', 'it')):
            out[s] = [row['en'], row['ru'], row['de'], row['it']]
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=0) + '\n')
    print(f'{len(out)} messages -> {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
