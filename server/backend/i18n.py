"""Мова документів, які формує сервер: PDF-квитанції, виписки й публічна сторінка перевірки.

Українська - основна: тексти в коді написані нею й слугують ключами. Мова береться із запиту:
`?lang=en` або заголовок Accept-Language (застосунок шле власну мову, браузер - свою).
Без запиту або з невідомою мовою залишається українська.
"""
from __future__ import annotations

import json
import re
from functools import lru_cache
from pathlib import Path

LANGS = ('uk', 'en', 'ru', 'de', 'it')


def _lang_from_request() -> str:
    try:
        from flask import has_request_context, request
    except ImportError:  # pragma: no cover
        return 'uk'
    if not has_request_context():
        return 'uk'
    explicit = (request.args.get('lang') or '').strip().lower()[:2]
    if explicit in LANGS:
        return explicit
    for part in (request.headers.get('Accept-Language') or '').split(','):
        tag = part.split(';')[0].strip().lower()[:2]
        if tag in LANGS:
            return tag
    return 'uk'


def current_lang() -> str:
    return _lang_from_request()


def tr(text: str) -> str:
    """Переклад українського тексту на мову поточного запиту; чого немає в таблиці - без змін."""
    lang = _lang_from_request()
    if lang == 'uk':
        return text
    row = _T.get(text)
    return row[LANGS.index(lang) - 1] if row else text


@lru_cache(maxsize=1)
def _messages() -> tuple[dict[str, list[str]], list[tuple[re.Pattern, str]]]:
    """Серверні повідомлення й описи операцій із backend/i18n_messages.json (див. scripts/sync_i18n.py)."""
    try:
        table = json.loads((Path(__file__).with_name('i18n_messages.json')).read_text())
    except (OSError, ValueError):
        return {}, []
    templates = [
        (re.compile('^' + re.escape(k).replace(re.escape('%@'), '(.+?)') + '$', re.S), k)
        for k in sorted(table, key=len, reverse=True) if '%@' in k
    ]
    return table, templates


_OPS = re.compile(r'^(\d+) операці[яїй]$')


def _ops(n: int, lang: str) -> str:
    one = n % 10 == 1 and n % 100 != 11
    few = 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14
    return {
        'en': f"{n} transaction{'' if n == 1 else 's'}",
        'ru': f"{n} операци{'я' if one else 'и' if few else 'й'}",
        'de': f"{n} Transaktion{'' if n == 1 else 'en'}",
        'it': f"{n} operazion{'e' if n == 1 else 'i'}",
    }[lang]


def _piece(text: str, lang: str) -> str:
    """Переклад підставленого фрагмента шаблону: день тижня, «12 операцій», назва з таблиці документів."""
    m = _OPS.match(text)
    if m:
        return _ops(int(m.group(1)), lang)
    row = _T.get(text)
    return row[LANGS.index(lang) - 1] if row else text


def tr_text(text: str) -> str:
    """Переклад збереженого українського тексту (опис операції, повідомлення), у т. ч. за шаблоном із %@."""
    lang = _lang_from_request()
    if lang == 'uk' or not text:
        return text
    table, templates = _messages()
    i = LANGS.index(lang) - 1
    if text in table:
        return table[text][i]
    for rx, key in templates:
        m = rx.match(text)
        if m:
            out = table[key][i]
            for g in m.groups():
                out = out.replace('%@', _piece(g, lang), 1)
            return out
    return text


# uk: (en, ru, de, it)
_T: dict[str, tuple[str, str, str, str]] = {
    # типи операцій
    'Операція': ('Transaction', 'Операция', 'Transaktion', 'Operazione'),
    'Переказ': ('Transfer', 'Перевод', 'Überweisung', 'Bonifico'),
    'Поповнення': ('Top-up', 'Пополнение', 'Aufladung', 'Ricarica'),
    'Оплата': ('Payment', 'Оплата', 'Zahlung', 'Pagamento'),
    'Виплата': ('Payout', 'Выплата', 'Auszahlung', 'Pagamento in uscita'),
    'Донат': ('Donation', 'Донат', 'Spende', 'Donazione'),
    'Накопичення': ('Savings', 'Накопления', 'Sparen', 'Risparmio'),
    'Кредит': ('Loan', 'Кредит', 'Kredit', 'Prestito'),
    'Погашення кредиту': ('Loan repayment', 'Погашение кредита', 'Kreditrückzahlung', 'Rimborso del prestito'),
    'Депозит': ('Deposit', 'Депозит', 'Einlage', 'Deposito'),
    'Магазин': ('Shop', 'Магазин', 'Shop', 'Negozio'),
    'Поповнення картки': ('Card top-up', 'Пополнение карты', 'Kartenaufladung', 'Ricarica della carta'),
    'Оплата в магазині': ('Shop payment', 'Оплата в магазине', 'Zahlung im Shop', 'Pagamento nel negozio'),
    'Повернення з магазину': ('Shop refund', 'Возврат из магазина', 'Rückerstattung vom Shop', 'Rimborso dal negozio'),
    'Кешбек': ('Cashback', 'Кешбэк', 'Cashback', 'Cashback'),
    'Комісія': ('Fee', 'Комиссия', 'Gebühr', 'Commissione'),
    'Податок': ('Tax', 'Налог', 'Steuer', 'Imposta'),
    'Зарплата': ('Salary', 'Зарплата', 'Gehalt', 'Stipendio'),
    # види виписок
    'Стандартна виписка': ('Standard statement', 'Стандартная выписка', 'Standardauszug', 'Estratto standard'),
    'Детальна виписка': ('Detailed statement', 'Подробная выписка', 'Detaillierter Auszug', 'Estratto dettagliato'),
    'Розрахунковий звіт': ('Settlement report', 'Расчётный отчёт', 'Abrechnungsbericht', 'Rapporto di regolamento'),
    # квитанція
    'КВИТАНЦІЯ': ('RECEIPT', 'КВИТАНЦИЯ', 'BELEG', 'RICEVUTA'),
    'Операцію виконано': ('Transaction completed', 'Операция выполнена', 'Transaktion ausgeführt', 'Operazione eseguita'),
    'Дата й час': ('Date and time', 'Дата и время', 'Datum und Uhrzeit', 'Data e ora'),
    'Власник': ('Holder', 'Владелец', 'Inhaber', 'Titolare'),
    'Рахунок': ('Account', 'Счёт', 'Konto', 'Conto'),
    'Контрагент': ('Counterparty', 'Контрагент', 'Gegenpartei', 'Controparte'),
    'Призначення': ('Purpose', 'Назначение', 'Verwendungszweck', 'Causale'),
    '№ операції': ('Transaction no.', '№ операции', 'Transaktionsnr.', 'N. operazione'),
    'Скануйте QR, щоб звірити квитанцію з реєстром TaxTech': (
        'Scan the QR to check the receipt against the TaxTech register',
        'Сканируйте QR, чтобы сверить квитанцию с реестром TaxTech',
        'QR scannen, um den Beleg mit dem TaxTech-Register abzugleichen',
        'Inquadra il QR per confrontare la ricevuta con il registro TaxTech'),
    'Навчальний документ: токени TAX не є грошима': (
        'Educational document: TAX tokens are not money',
        'Учебный документ: токены TAX не являются деньгами',
        'Lehrdokument: TAX-Token sind kein Geld',
        'Documento didattico: i token TAX non sono denaro'),
    'ПЕРЕВІРКА ДОКУМЕНТА': ('DOCUMENT CHECK', 'ПРОВЕРКА ДОКУМЕНТА', 'DOKUMENTPRÜFUNG', 'VERIFICA DEL DOCUMENTO'),
    'Скануйте QR або відкрийте адресу: документ звіряється з реєстром TaxTech.': (
        'Scan the QR or open the address: the document is checked against the TaxTech register.',
        'Сканируйте QR или откройте адрес: документ сверяется с реестром TaxTech.',
        'QR scannen oder Adresse öffnen: Das Dokument wird mit dem TaxTech-Register abgeglichen.',
        "Inquadra il QR o apri l'indirizzo: il documento viene confrontato con il registro TaxTech."),
    # виписка: шапка
    'Власник рахунку': ('Account holder', 'Владелец счёта', 'Kontoinhaber', 'Titolare del conto'),
    'Телефон / Email': ('Phone / Email', 'Телефон / Email', 'Telefon / E-Mail', 'Telefono / Email'),
    'Поточний баланс': ('Current balance', 'Текущий баланс', 'Aktuelles Guthaben', 'Saldo attuale'),
    'Валюта': ('Currency', 'Валюта', 'Währung', 'Valuta'),
    'TAX — навчальний токен лабораторії': (
        'TAX is an educational token of the lab', 'TAX — учебный токен лаборатории',
        'TAX ist ein Lern-Token des Labors', 'TAX è un token didattico del laboratorio'),
    'Дата формування': ('Generated on', 'Дата формирования', 'Erstellt am', 'Data di generazione'),
    'ID замовлення': ('Order ID', 'ID заказа', 'Bestell-ID', 'ID ordine'),
    # виписка: підсумки
    'Поч. баланс': ('Opening bal.', 'Нач. баланс', 'Anfangssaldo', 'Saldo iniz.'),
    'Надходження': ('Income', 'Поступления', 'Eingänge', 'Entrate'),
    'Витрати': ('Expenses', 'Расходы', 'Ausgaben', 'Uscite'),
    'Кін. баланс': ('Closing bal.', 'Кон. баланс', 'Endsaldo', 'Saldo fin.'),
    'Чистий рух': ('Net flow', 'Чистое движение', 'Nettobewegung', 'Flusso netto'),
    'Кількість операцій (усього)': ('Transactions (total)', 'Количество операций (всего)', 'Anzahl Transaktionen (gesamt)', 'Numero di operazioni (totale)'),
    'Кількість надходжень / витрат': ('Income / expense count', 'Количество поступлений / расходов', 'Anzahl Eingänge / Ausgaben', 'Numero di entrate / uscite'),
    'Середній чек': ('Average ticket', 'Средний чек', 'Durchschnittsbetrag', 'Importo medio'),
    'Середнє надходження': ('Average income', 'Среднее поступление', 'Durchschnittlicher Eingang', 'Entrata media'),
    'Середня витрата': ('Average expense', 'Средний расход', 'Durchschnittliche Ausgabe', 'Uscita media'),
    'Максимальне надходження': ('Largest income', 'Максимальное поступление', 'Höchster Eingang', 'Entrata massima'),
    'Максимальна витрата': ('Largest expense', 'Максимальный расход', 'Höchste Ausgabe', 'Uscita massima'),
    'Мінімальна сума операції': ('Smallest transaction', 'Минимальная сумма операции', 'Kleinste Transaktion', 'Operazione minima'),
    'Максимальна сума операції': ('Largest transaction', 'Максимальная сумма операции', 'Größte Transaktion', 'Operazione massima'),
    # виписка: таблиці
    'Помісячний рух коштів': ('Monthly cash flow', 'Помесячное движение средств', 'Monatlicher Zahlungsverlauf', 'Flusso di cassa mensile'),
    'Розподіл за типами операцій': ('Breakdown by transaction type', 'Распределение по типам операций', 'Aufteilung nach Transaktionsart', 'Ripartizione per tipo di operazione'),
    'Денний підсумок руху коштів': ('Daily cash flow summary', 'Дневной итог движения средств', 'Tägliche Zahlungsübersicht', 'Riepilogo giornaliero dei flussi'),
    'Розрахунковий денний реєстр': ('Daily settlement register', 'Расчётный дневной реестр', 'Tägliches Abrechnungsregister', 'Registro giornaliero di regolamento'),
    'Деталізація транзакцій': ('Transaction details', 'Детализация транзакций', 'Transaktionsdetails', 'Dettaglio delle operazioni'),
    'Транзакцій за вказаний період не знайдено.': ('No transactions found for this period.', 'Транзакций за указанный период не найдено.', 'Für diesen Zeitraum wurden keine Transaktionen gefunden.', 'Nessuna operazione trovata nel periodo indicato.'),
    'Тип': ('Type', 'Тип', 'Art', 'Tipo'),
    'К-сть': ('Qty', 'Кол-во', 'Anz.', 'N.'),
    'Оборот': ('Turnover', 'Оборот', 'Umsatz', 'Volume'),
    'Дата': ('Date', 'Дата', 'Datum', 'Data'),
    'Операцій': ('Transactions', 'Операций', 'Transaktionen', 'Operazioni'),
    'Місяць': ('Month', 'Месяц', 'Monat', 'Mese'),
    'Разом': ('Total', 'Итого', 'Gesamt', 'Totale'),
    'Опис / Контрагент': ('Description / Counterparty', 'Описание / Контрагент', 'Beschreibung / Gegenpartei', 'Descrizione / Controparte'),
    'Сума': ('Amount', 'Сумма', 'Betrag', 'Importo'),
    'Баланс після': ('Balance after', 'Баланс после', 'Saldo danach', 'Saldo dopo'),
    'весь час': ('all time', 'всё время', 'gesamte Zeit', 'tutto il periodo'),
    'з': ('from', 'с', 'ab', 'dal'),
    'по': ('to', 'по', 'bis', 'al'),
    'Сформовано': ('Generated', 'Сформировано', 'Erstellt', 'Generato'),
    # місяці
    'Січень': ('January', 'Январь', 'Januar', 'Gennaio'),
    'Лютий': ('February', 'Февраль', 'Februar', 'Febbraio'),
    'Березень': ('March', 'Март', 'März', 'Marzo'),
    'Квітень': ('April', 'Апрель', 'April', 'Aprile'),
    'Травень': ('May', 'Май', 'Mai', 'Maggio'),
    'Червень': ('June', 'Июнь', 'Juni', 'Giugno'),
    'Липень': ('July', 'Июль', 'Juli', 'Luglio'),
    'Серпень': ('August', 'Август', 'August', 'Agosto'),
    'Вересень': ('September', 'Сентябрь', 'September', 'Settembre'),
    'Жовтень': ('October', 'Октябрь', 'Oktober', 'Ottobre'),
    'Листопад': ('November', 'Ноябрь', 'November', 'Novembre'),
    'Грудень': ('December', 'Декабрь', 'Dezember', 'Dicembre'),
    'січня': ('January', 'января', 'Januar', 'gennaio'),
    'лютого': ('February', 'февраля', 'Februar', 'febbraio'),
    'березня': ('March', 'марта', 'März', 'marzo'),
    'квітня': ('April', 'апреля', 'April', 'aprile'),
    'травня': ('May', 'мая', 'Mai', 'maggio'),
    'червня': ('June', 'июня', 'Juni', 'giugno'),
    'липня': ('July', 'июля', 'Juli', 'luglio'),
    'серпня': ('August', 'августа', 'August', 'agosto'),
    'вересня': ('September', 'сентября', 'September', 'settembre'),
    'жовтня': ('October', 'октября', 'Oktober', 'ottobre'),
    'листопада': ('November', 'ноября', 'November', 'novembre'),
    'грудня': ('December', 'декабря', 'Dezember', 'dicembre'),
    # сторінка перевірки (/v/<код>)
    'Квитанція': ('Receipt', 'Квитанция', 'Beleg', 'Ricevuta'),
    'Виписка': ('Statement', 'Выписка', 'Kontoauszug', 'Estratto conto'),
    'Документ дійсний': ('The document is valid', 'Документ действителен', 'Das Dokument ist gültig', 'Il documento è valido'),
    'Відбиток збігається з реєстром TaxTech.': ('The fingerprint matches the TaxTech register.', 'Отпечаток совпадает с реестром TaxTech.', 'Der Fingerabdruck stimmt mit dem TaxTech-Register überein.', "L'impronta corrisponde al registro TaxTech."),
    'Дані змінилися': ('The data has changed', 'Данные изменились', 'Die Daten haben sich geändert', 'I dati sono cambiati'),
    'Відбиток документа більше не збігається з реєстром.': ('The document fingerprint no longer matches the register.', 'Отпечаток документа больше не совпадает с реестром.', 'Der Fingerabdruck des Dokuments stimmt nicht mehr mit dem Register überein.', "L'impronta del documento non corrisponde più al registro."),
    'Документ не знайдено': ('Document not found', 'Документ не найден', 'Dokument nicht gefunden', 'Documento non trovato'),
    'Код': ('Code', 'Код', 'Code', 'Codice'),
    'не відповідає жодному документу TaxTech.': ('does not match any TaxTech document.', 'не соответствует ни одному документу TaxTech.', 'passt zu keinem TaxTech-Dokument.', 'non corrisponde a nessun documento TaxTech.'),
    'Перевірте код або скануйте QR із документа ще раз.': ('Check the code or scan the QR on the document again.', 'Проверьте код или отсканируйте QR с документа ещё раз.', 'Prüfen Sie den Code oder scannen Sie den QR-Code des Dokuments erneut.', 'Controlla il codice o inquadra di nuovo il QR del documento.'),
    'Вид': ('Kind', 'Вид', 'Art', 'Tipo'),
    'Період': ('Period', 'Период', 'Zeitraum', 'Periodo'),
    'Надійшло': ('Received', 'Поступило', 'Eingegangen', 'Ricevuto'),
    'Витрачено': ('Spent', 'Потрачено', 'Ausgegeben', 'Speso'),
    'Видано': ('Issued', 'Выдано', 'Ausgestellt', 'Emesso'),
    'Відбиток SHA-256': ('SHA-256 fingerprint', 'Отпечаток SHA-256', 'SHA-256-Fingerabdruck', 'Impronta SHA-256'),
    'Скануйте QR: сторінка звіряє документ з реєстром операцій і не показує особистих даних.': (
        'Scan the QR: the page checks the document against the transaction register and shows no personal data.',
        'Сканируйте QR: страница сверяет документ с реестром операций и не показывает личных данных.',
        'QR scannen: Die Seite gleicht das Dokument mit dem Transaktionsregister ab und zeigt keine persönlichen Daten.',
        'Inquadra il QR: la pagina confronta il documento con il registro delle operazioni e non mostra dati personali.'),
    'Перевірено': ('Checked', 'Проверено', 'Geprüft', 'Verificato'),
    'Навчальний документ TaxTech: токени TAX не є грошима.': ('TaxTech educational document: TAX tokens are not money.', 'Учебный документ TaxTech: токены TAX не являются деньгами.', 'TaxTech-Lehrdokument: TAX-Token sind kein Geld.', 'Documento didattico TaxTech: i token TAX non sono denaro.'),
    'Особисті дані приховано.': ('Personal data is hidden.', 'Личные данные скрыты.', 'Persönliche Daten sind ausgeblendet.', 'I dati personali sono nascosti.'),
    'ДОКУМЕНТ · TAXTECH': ('DOCUMENT · TAXTECH', 'ДОКУМЕНТ · TAXTECH', 'DOKUMENT · TAXTECH', 'DOCUMENTO · TAXTECH'),
    # CSV-експорт
    'Напрям': ('Direction', 'Направление', 'Richtung', 'Direzione'),
    'Сума (TAX)': ('Amount (TAX)', 'Сумма (TAX)', 'Betrag (TAX)', 'Importo (TAX)'),
    'Опис': ('Description', 'Описание', 'Beschreibung', 'Descrizione'),
    "Пов'язаний рахунок": ('Related account', 'Связанный счёт', 'Zugehöriges Konto', 'Conto collegato'),
    'Прихід': ('In', 'Приход', 'Eingang', 'Entrata'),
    'Відхід': ('Out', 'Расход', 'Ausgang', 'Uscita'),
    'Видача кредиту': ('Loan disbursement', 'Выдача кредита', 'Kreditauszahlung', 'Erogazione del prestito'),
    # дні тижня (підказки «Найактивніший день»)
    'понеділок': ('Monday', 'понедельник', 'Montag', 'lunedì'),
    'вівторок': ('Tuesday', 'вторник', 'Dienstag', 'martedì'),
    'середа': ('Wednesday', 'среда', 'Mittwoch', 'mercoledì'),
    'четвер': ('Thursday', 'четверг', 'Donnerstag', 'giovedì'),
    'пʼятниця': ('Friday', 'пятница', 'Freitag', 'venerdì'),
    'субота': ('Saturday', 'суббота', 'Samstag', 'sabato'),
    'неділя': ('Sunday', 'воскресенье', 'Sonntag', 'domenica'),
    # періоди виписок
    'весь час': ('all time', 'всё время', 'gesamter Zeitraum', 'tutto il periodo'),
    # описи операцій пісочниці (scripts/seed_sandbox.py)
    'Супермаркет (віртуальна покупка)': ('Supermarket (virtual purchase)', 'Супермаркет (виртуальная покупка)', 'Supermarkt (virtueller Einkauf)', 'Supermercato (acquisto virtuale)'),
    'Продукти біля дому (віртуальна покупка)': ('Corner grocery (virtual purchase)', 'Продукты у дома (виртуальная покупка)', 'Lebensmittel um die Ecke (virtueller Einkauf)', 'Alimentari sotto casa (acquisto virtuale)'),
    "Кав'ярня (віртуальна покупка)": ('Café (virtual purchase)', 'Кофейня (виртуальная покупка)', 'Café (virtueller Einkauf)', 'Caffè (acquisto virtuale)'),
    'Аптека (віртуальна покупка)': ('Pharmacy (virtual purchase)', 'Аптека (виртуальная покупка)', 'Apotheke (virtueller Einkauf)', 'Farmacia (acquisto virtuale)'),
    'Транспорт (віртуальна покупка)': ('Transport (virtual purchase)', 'Транспорт (виртуальная покупка)', 'Verkehr (virtueller Einkauf)', 'Trasporti (acquisto virtuale)'),
    'АЗС (віртуальна покупка)': ('Petrol station (virtual purchase)', 'АЗС (виртуальная покупка)', 'Tankstelle (virtueller Einkauf)', 'Distributore (acquisto virtuale)'),
    'Інтернет-магазин (віртуальна покупка)': ('Online store (virtual purchase)', 'Интернет-магазин (виртуальная покупка)', 'Onlineshop (virtueller Einkauf)', 'Negozio online (acquisto virtuale)'),
    'Комунальні послуги (віртуальна оплата)': ('Utilities (virtual payment)', 'Коммунальные услуги (виртуальная оплата)', 'Nebenkosten (virtuelle Zahlung)', 'Utenze (pagamento virtuale)'),
    "Мобільний зв'язок (віртуальна оплата)": ('Mobile plan (virtual payment)', 'Мобильная связь (виртуальная оплата)', 'Mobilfunk (virtuelle Zahlung)', 'Telefonia mobile (pagamento virtuale)'),
    'Кіно (віртуальна покупка)': ('Cinema (virtual purchase)', 'Кино (виртуальная покупка)', 'Kino (virtueller Einkauf)', 'Cinema (acquisto virtuale)'),
    'Стартове поповнення': ('Opening top-up', 'Стартовое пополнение', 'Startaufladung', 'Ricarica iniziale'),
    'Переказ знайомому': ('Transfer to a friend', 'Перевод знакомому', 'Überweisung an einen Bekannten', 'Bonifico a un amico'),
}


# ── Тексти в JSON-відповідях API ─────────────────────────────────────────────
# Сервер зберігає описи операцій, сповіщення й підказки українською. Застосунок iOS перекладає їх у себе,
# веб - ні, тому відповідь /api/* перекладається тут, мовою запиту (?lang або Accept-Language).
# Лише текстові поля з кирилицею; ключі, коди, хеші й номери не чіпаємо, невідоме лишається як є.
_CYR = re.compile('[А-Яа-яІіЇїЄєҐґ]')
JSON_TEXT_KEYS = frozenset({'description', 'title', 'body', 'text', 'message', 'desc', 'tx_type', 'label', 'subtitle', 'hint', 'period'})


def tr_any(text: str) -> str:
    """Переклад за таблицею серверних текстів, а якщо там немає - за таблицею документів."""
    if ' · ' in text:
        return ' · '.join(tr_any(part) for part in text.split(' · '))
    out = tr_text(text)
    return tr(text) if out == text else out


def translate_payload(obj):
    """Перекладає текстові поля JSON-відповіді на мову поточного запиту (на місці повертає нову структуру)."""
    if isinstance(obj, dict):
        return {k: (tr_any(v) if k in JSON_TEXT_KEYS and isinstance(v, str) and _CYR.search(v) else translate_payload(v))
                for k, v in obj.items()}
    if isinstance(obj, list):
        return [translate_payload(v) for v in obj]
    return obj

