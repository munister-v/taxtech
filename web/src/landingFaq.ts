import type { LandingLang } from './landingLang';

// Questions block of the landing, written out per language (the short strings elsewhere use landingI18n.ts).
type L = Record<LandingLang, string>;
export type FaqItem = { q: L; a: L };
export type FaqGroup = { title: L; items: FaqItem[] };

const f = (uk: string, en: string, it: string, de: string, ru: string): L => ({ uk, en, it, de, ru });

export const FAQ: FaqGroup[] = [
  {
    title: f('Про TaxTech', 'About TaxTech', 'Su TaxTech', 'Über TaxTech', 'О TaxTech'),
    items: [
      {
        q: f('Що таке TaxTech?', 'What is TaxTech?', 'Che cos’è TaxTech?', 'Was ist TaxTech?', 'Что такое TaxTech?'),
        a: f(
          `Навчальний цифровий банк лабораторії цифрових фінансів: вебзастосунок і застосунок для iPhone. Рахунок, картки, перекази, депозити, кредит і антифрод працюють так, як у справжньому банку, але на віртуальних грошах, тож на них можна вчитися й пробувати без ризику. Заодно TaxTech є платіжним партнером магазину Saint Agnes.`,
          `The training digital bank of a digital-finance lab, as a web app and an iPhone app. Accounts, cards, transfers, deposits, credit and fraud checks work as in a real bank, but with virtual money, so you can learn and experiment without risk. TaxTech is also the payment partner of the Saint Agnes shop.`,
          `La banca digitale didattica di un laboratorio di finanza digitale, come app web e app per iPhone. Conti, carte, bonifici, depositi, credito e controlli antifrode funzionano come in una vera banca, ma con denaro virtuale: si può imparare e sperimentare senza rischi. TaxTech è anche il partner di pagamento del negozio Saint Agnes.`,
          `Die digitale Lernbank eines Labors für digitale Finanzen, als Web-App und als iPhone-App. Konten, Karten, Überweisungen, Einlagen, Kredit und Betrugsprüfung funktionieren wie bei einer echten Bank, aber mit virtuellem Geld, sodass man ohne Risiko lernen und ausprobieren kann. TaxTech ist außerdem Zahlungspartner des Shops Saint Agnes.`,
          `Учебный цифровой банк лаборатории цифровых финансов: веб-приложение и приложение для iPhone. Счёт, карты, переводы, депозиты, кредит и антифрод работают как в настоящем банке, но на виртуальных деньгах, поэтому на них можно учиться и экспериментировать без риска. Кроме того, TaxTech — платёжный партнёр магазина Saint Agnes.`,
        ),
      },
      {
        q: f('Що таке TAX і чи це гроші?', 'What is TAX, and is it money?', 'Che cos’è TAX e sono soldi?', 'Was ist TAX, und ist es Geld?', 'Что такое TAX и это деньги?'),
        a: f(
          `TAX — віртуальний токен банку. Він не є грошима чи електронними грошима й не обмінюється на гривню чи будь-яку іншу валюту. Справжні картки й рахунки до TaxTech не прив’язуються, номери карт починаються з 0000, тож втратити реальні гроші тут неможливо.`,
          `TAX is the bank’s virtual token. It is not money or e-money and cannot be exchanged for hryvnia or any other currency. No real cards or accounts are linked to TaxTech and card numbers start with 0000, so there is no way to lose real money here.`,
          `TAX è il token virtuale della banca. Non è denaro né moneta elettronica e non si cambia in grivnie né in altra valuta. A TaxTech non si collegano carte o conti reali e i numeri delle carte iniziano con 0000, quindi qui è impossibile perdere denaro vero.`,
          `TAX ist der virtuelle Token der Bank. Er ist weder Geld noch E-Geld und lässt sich weder in Hrywnja noch in eine andere Währung tauschen. An TaxTech werden keine echten Karten oder Konten angebunden, Kartennummern beginnen mit 0000 – echtes Geld kann hier also nicht verloren gehen.`,
          `TAX — виртуальный токен банка. Это не деньги и не электронные деньги, он не обменивается ни на гривну, ни на другую валюту. К TaxTech не привязываются настоящие карты и счета, номера карт начинаются с 0000, поэтому потерять реальные деньги здесь невозможно.`,
        ),
      },
      {
        q: f('Це справжній банк? Чи є ліцензія?', 'Is it a real bank? Is there a licence?', 'È una banca vera? C’è una licenza?', 'Ist das eine echte Bank? Gibt es eine Lizenz?', 'Это настоящий банк? Есть ли лицензия?'),
        a: f(
          `Ні. TaxTech — навчальна платформа, а не банк, і банківської ліцензії в неї немає. Вона також не сертифікована за EMVCo, PCI DSS чи FIDO. Усе, що ви тут бачите, — картки, перекази, 3-D Secure, антифрод, — відтворює поведінку справжніх систем, щоб її можна було вивчати.`,
          `No. TaxTech is a training platform, not a bank, and it holds no banking licence. It is also not certified by EMVCo, PCI DSS or FIDO. Everything you see here (cards, transfers, 3-D Secure, fraud checks) reproduces how real systems behave so that it can be studied.`,
          `No. TaxTech è una piattaforma didattica, non una banca, e non ha alcuna licenza bancaria. Non è nemmeno certificata EMVCo, PCI DSS o FIDO. Tutto ciò che vedi (carte, bonifici, 3-D Secure, controlli antifrode) riproduce il comportamento dei sistemi reali per poterlo studiare.`,
          `Nein. TaxTech ist eine Lernplattform, keine Bank, und besitzt keine Banklizenz. Sie ist auch nicht nach EMVCo, PCI DSS oder FIDO zertifiziert. Alles, was du hier siehst (Karten, Überweisungen, 3-D Secure, Betrugsprüfung), bildet das Verhalten echter Systeme nach, damit man es untersuchen kann.`,
          `Нет. TaxTech — учебная платформа, а не банк, и банковской лицензии у неё нет. Она также не сертифицирована по EMVCo, PCI DSS или FIDO. Всё, что вы здесь видите — карты, переводы, 3-D Secure, антифрод, — воспроизводит поведение настоящих систем, чтобы его можно было изучать.`,
        ),
      },
    ],
  },
  {
    title: f('Рахунок і картки', 'Account and cards', 'Conto e carte', 'Konto und Karten', 'Счёт и карты'),
    items: [
      {
        q: f('Як відкрити рахунок?', 'How do I open an account?', 'Come si apre un conto?', 'Wie eröffne ich ein Konto?', 'Как открыть счёт?'),
        a: f(
          `Вкажіть телефон або email і пароль: рахунок і перша картка з’являються одразу, без перевірки документів. У застосунку для iPhone можна ще й увійти через Apple. Після першого входу додайте passkey, і далі заходьте за Face ID або Touch ID без пароля.`,
          `Enter a phone number or email and a password: the account and your first card appear at once, with no document checks. In the iPhone app you can also sign in with Apple. After the first sign-in add a passkey and from then on use Face ID or Touch ID instead of the password.`,
          `Inserisci un numero di telefono o un’email e una password: il conto e la prima carta compaiono subito, senza controllo dei documenti. Nell’app per iPhone puoi anche accedere con Apple. Dopo il primo accesso aggiungi una passkey e poi entra con Face ID o Touch ID al posto della password.`,
          `Gib eine Telefonnummer oder E-Mail und ein Passwort ein: Konto und erste Karte erscheinen sofort, ohne Dokumentenprüfung. In der iPhone-App kannst du dich auch mit Apple anmelden. Nach der ersten Anmeldung fügst du einen Passkey hinzu und meldest dich danach mit Face ID oder Touch ID statt mit dem Passwort an.`,
          `Укажите телефон или email и пароль: счёт и первая карта появятся сразу, без проверки документов. В приложении для iPhone можно также войти через Apple. После первого входа добавьте passkey и дальше заходите по Face ID или Touch ID вместо пароля.`,
        ),
      },
      {
        q: f('Які в мене картки і чи можна змінити вигляд?', 'What cards do I get, and can I change the design?', 'Che carte ricevo e posso cambiare il design?', 'Welche Karten bekomme ich, und kann ich das Design ändern?', 'Какие у меня карты и можно ли сменить вид?'),
        a: f(
          `Картки віртуальні, без пластику. Для кожної можна обрати один із шести виглядів: гільйош або одне з фото Рима, як у розділі «Шість облич». Картка має чип, номер із 0000 на початку й працює для оплати в Saint Agnes через TaxPay та для переказів між клієнтами.`,
          `Cards are virtual, with no plastic. For each one you can pick one of six designs: guilloche or one of the Rome photographs, as in the “Six faces” section. A card has a chip, a number that starts with 0000 and works for payments in Saint Agnes through TaxPay and for transfers between customers.`,
          `Le carte sono virtuali, senza plastica. Per ognuna puoi scegliere uno di sei design: guilloche o una delle fotografie di Roma, come nella sezione «Sei volti». La carta ha un chip, un numero che inizia con 0000 e serve per pagare in Saint Agnes tramite TaxPay e per i bonifici tra clienti.`,
          `Die Karten sind virtuell, ohne Plastik. Für jede kannst du eines von sechs Designs wählen: Guilloche oder eines der Rom-Fotos, wie im Abschnitt „Sechs Gesichter“. Die Karte hat einen Chip, eine Nummer mit 0000 am Anfang und dient zum Bezahlen bei Saint Agnes über TaxPay sowie für Überweisungen zwischen Kunden.`,
          `Карты виртуальные, без пластика. Для каждой можно выбрать один из шести видов: гильоше или одно из фото Рима, как в разделе «Шесть лиц». У карты есть чип, номер с 0000 в начале, и она работает для оплаты в Saint Agnes через TaxPay и для переводов между клиентами.`,
        ),
      },
      {
        q: f('Що ще є в рахунку, крім карток?', 'What else is in the account besides cards?', 'Cos’altro c’è nel conto oltre alle carte?', 'Was gibt es im Konto außer Karten?', 'Что ещё есть в счёте, кроме карт?'),
        a: f(
          `Перекази між клієнтами, поповнення, депозити, кредит із графіком погашення, історія операцій за днями й сховище документів: квитанції та виписки. Усе рахується в TAX, а кожна операція проходить через єдиний платіжний рушій з ідемпотентними ключами, тому повторний натиск не списує гроші двічі.`,
          `Transfers between customers, top-ups, deposits, credit with a repayment schedule, an operation history grouped by day and a document vault with receipts and statements. Everything is counted in TAX, and every operation goes through a single payment engine with idempotency keys, so a repeated tap never charges twice.`,
          `Bonifici tra clienti, ricariche, depositi, credito con piano di rimborso, storico delle operazioni raggruppato per giorno e un archivio di documenti con ricevute ed estratti conto. Tutto è contato in TAX e ogni operazione passa da un unico motore di pagamento con chiavi di idempotenza, quindi un tocco ripetuto non addebita mai due volte.`,
          `Überweisungen zwischen Kunden, Einzahlungen, Einlagen, Kredit mit Tilgungsplan, ein nach Tagen gruppierter Verlauf und ein Dokumentenarchiv mit Belegen und Kontoauszügen. Alles wird in TAX gerechnet, und jede Operation läuft über eine einzige Zahlungs-Engine mit Idempotenzschlüsseln, sodass ein wiederholtes Tippen nie doppelt abbucht.`,
          `Переводы между клиентами, пополнение, депозиты, кредит с графиком погашения, история операций по дням и хранилище документов с квитанциями и выписками. Всё считается в TAX, а каждая операция проходит через единый платёжный движок с ключами идемпотентности, поэтому повторное нажатие не спишет деньги дважды.`,
        ),
      },
    ],
  },
  {
    title: f('Оплата в магазині', 'Paying in the shop', 'Pagare nel negozio', 'Bezahlen im Shop', 'Оплата в магазине'),
    items: [
      {
        q: f('Що таке TaxPay і як оплатити в Saint Agnes?', 'What is TaxPay and how do I pay in Saint Agnes?', 'Che cos’è TaxPay e come si paga in Saint Agnes?', 'Was ist TaxPay und wie bezahle ich bei Saint Agnes?', 'Что такое TaxPay и как оплатить в Saint Agnes?'),
        a: f(
          `TaxPay — платіжна сторінка TaxTech для зовнішніх магазинів. У Saint Agnes оберіть розмір і кількість, додайте товар у кошик, на оформленні натисніть оплату через TaxPay: магазин створить сесію, а вас переведе на сторінку банку з кошиком і сумою. Увійдіть, якщо треба, і сплатіть одним дотиком; банк сам повідомить магазин і поверне вас назад.`,
          `TaxPay is TaxTech’s payment page for outside shops. In Saint Agnes pick a size and quantity, add the item to the basket and choose TaxPay at checkout: the shop opens a session and sends you to the bank’s page with your basket and the amount. Sign in if needed and pay with one tap; the bank itself tells the shop and sends you back.`,
          `TaxPay è la pagina di pagamento di TaxTech per i negozi esterni. In Saint Agnes scegli taglia e quantità, aggiungi l’articolo al carrello e al checkout scegli TaxPay: il negozio apre una sessione e ti porta alla pagina della banca con il carrello e l’importo. Accedi se serve e paga con un tocco; è la banca stessa ad avvisare il negozio e a riportarti indietro.`,
          `TaxPay ist die Zahlungsseite von TaxTech für externe Shops. Wähle bei Saint Agnes Größe und Menge, lege den Artikel in den Warenkorb und wähle an der Kasse TaxPay: Der Shop öffnet eine Sitzung und leitet dich auf die Seite der Bank mit Warenkorb und Betrag. Melde dich bei Bedarf an und zahle mit einem Fingertipp; die Bank benachrichtigt den Shop selbst und führt dich zurück.`,
          `TaxPay — платёжная страница TaxTech для внешних магазинов. В Saint Agnes выберите размер и количество, добавьте товар в корзину и при оформлении выберите оплату через TaxPay: магазин откроет сессию, а вас перенаправит на страницу банка с корзиной и суммой. Войдите, если нужно, и оплатите одним касанием; банк сам сообщит магазину и вернёт вас обратно.`,
        ),
      },
      {
        q: f('Скільки діє оплата і що, якщо я не встиг?', 'How long does a payment stay open, and what if I am too slow?', 'Quanto resta aperto un pagamento e se non faccio in tempo?', 'Wie lange bleibt eine Zahlung offen, und was, wenn ich zu langsam bin?', 'Сколько действует оплата и что, если я не успел?'),
        a: f(
          `Сесія оплати живе 30 хвилин, і стільки ж магазин тримає в резерві вибраний розмір. Якщо час вийшов або ви закрили сторінку, резерв знімається, гроші не списуються, а товар знову доступний усім. Оформити замовлення можна заново.`,
          `A payment session lasts 30 minutes, and the shop holds your chosen size in reserve for the same time. If the time runs out or you close the page, the reservation is released, nothing is charged and the item becomes available to everyone again. You can simply place the order again.`,
          `Una sessione di pagamento dura 30 minuti e il negozio tiene riservata la taglia scelta per lo stesso tempo. Se il tempo scade o chiudi la pagina, la riserva viene rilasciata, non viene addebitato nulla e l’articolo torna disponibile per tutti. Puoi semplicemente rifare l’ordine.`,
          `Eine Zahlungssitzung dauert 30 Minuten, und der Shop hält die gewählte Größe genauso lange für dich zurück. Läuft die Zeit ab oder schließt du die Seite, wird die Reservierung aufgehoben, es wird nichts abgebucht, und der Artikel ist wieder für alle verfügbar. Du kannst die Bestellung einfach neu aufgeben.`,
          `Сессия оплаты живёт 30 минут, и столько же магазин держит в резерве выбранный размер. Если время вышло или вы закрыли страницу, резерв снимается, деньги не списываются, а товар снова доступен всем. Оформить заказ можно заново.`,
        ),
      },
      {
        q: f('Як повернути гроші за замовлення?', 'How do I get my money back for an order?', 'Come ottengo il rimborso di un ordine?', 'Wie bekomme ich das Geld für eine Bestellung zurück?', 'Как вернуть деньги за заказ?'),
        a: f(
          `Якщо скасувати оплачене замовлення в магазині, кошти повертаються на ваш рахунок через банк, і повторне скасування не поверне їх двічі. Якщо повернення раптом не пройде, магазин збереже помилку в замовленні, а повторне скасування спробує ще раз. Обмін товару в магазині діє 14 днів.`,
          `If you cancel a paid order in the shop, the money goes back to your account through the bank, and cancelling again never refunds it twice. Should a refund fail, the shop records the error on the order and cancelling again retries it. Exchanges in the shop are open for 14 days.`,
          `Se annulli un ordine pagato nel negozio, il denaro torna sul tuo conto tramite la banca e annullare di nuovo non lo rimborsa due volte. Se un rimborso dovesse fallire, il negozio registra l’errore sull’ordine e annullare di nuovo lo riprova. Il cambio merce nel negozio è possibile entro 14 giorni.`,
          `Wenn du eine bezahlte Bestellung im Shop stornierst, fließt das Geld über die Bank auf dein Konto zurück, und ein erneutes Stornieren erstattet nie doppelt. Schlägt eine Erstattung fehl, vermerkt der Shop den Fehler an der Bestellung, und ein erneutes Stornieren versucht es noch einmal. Umtausch im Shop ist 14 Tage lang möglich.`,
          `Если отменить оплаченный заказ в магазине, деньги вернутся на ваш счёт через банк, а повторная отмена не вернёт их дважды. Если возврат вдруг не пройдёт, магазин сохранит ошибку в заказе, а повторная отмена попробует снова. Обмен товара в магазине действует 14 дней.`,
        ),
      },
    ],
  },
  {
    title: f('Безпека й документи', 'Security and documents', 'Sicurezza e documenti', 'Sicherheit und Dokumente', 'Безопасность и документы'),
    items: [
      {
        q: f('Як працює захист від шахрайства?', 'How does fraud protection work?', 'Come funziona la protezione dalle frodi?', 'Wie funktioniert der Betrugsschutz?', 'Как работает защита от мошенничества?'),
        a: f(
          `Кожен переказ ще до списання проходить 28 правил у трьох шарах: сама операція (сума, час, швидкість), ваша історія та граф переказів між клієнтами. Правила оцінюють ризик нечіткою логікою, а за критичного рівня переказ блокується. Онлайн-оплату додатково підтверджує код 3-D Secure.`,
          `Before any money moves, every transfer passes 28 rules in three layers: the transaction itself (amount, time, velocity), your history and the transfer graph between customers. The rules score risk with fuzzy logic, and a transfer is blocked at a critical level. Online payments are confirmed with a 3-D Secure code on top.`,
          `Prima che il denaro si muova, ogni bonifico supera 28 regole su tre livelli: l’operazione stessa (importo, orario, velocità), il tuo storico e il grafo dei bonifici tra clienti. Le regole valutano il rischio con logica fuzzy e a livello critico il bonifico viene bloccato. I pagamenti online sono inoltre confermati con un codice 3-D Secure.`,
          `Bevor Geld fließt, durchläuft jede Überweisung 28 Regeln in drei Schichten: die Transaktion selbst (Betrag, Zeit, Häufigkeit), dein Verlauf und der Überweisungsgraph zwischen Kunden. Die Regeln bewerten das Risiko mit Fuzzy-Logik, bei kritischem Niveau wird die Überweisung blockiert. Online-Zahlungen bestätigst du zusätzlich mit einem 3-D-Secure-Code.`,
          `Ещё до списания каждый перевод проходит 28 правил в трёх слоях: сама операция (сумма, время, частота), ваша история и граф переводов между клиентами. Правила оценивают риск нечёткой логикой, а при критическом уровне перевод блокируется. Онлайн-оплату дополнительно подтверждает код 3-D Secure.`,
        ),
      },
      {
        q: f('Як перевірити квитанцію або виписку?', 'How do I verify a receipt or a statement?', 'Come verifico una ricevuta o un estratto conto?', 'Wie prüfe ich einen Beleg oder Kontoauszug?', 'Как проверить квитанцию или выписку?'),
        a: f(
          `Кожна квитанція й виписка — PDF із кодом на кшталт TT-XXXX-XXXX-XXXX і QR. Скануйте QR або введіть код на сторінці перевірки: вона звірить документ із реєстром операцій і покаже, чи він дійсний. Якщо дані змінили, перевірка скаже, що відбиток не збігається. Код виводиться з секретного ключа банку, тож підробити його неможливо.`,
          `Every receipt and statement is a PDF with a code like TT-XXXX-XXXX-XXXX and a QR. Scan the QR or enter the code on the verification page: it checks the document against the operation registry and tells you whether it is valid. If the data was altered, the check reports that the fingerprint no longer matches. The code is derived from the bank’s secret key, so it cannot be forged.`,
          `Ogni ricevuta ed estratto conto è un PDF con un codice del tipo TT-XXXX-XXXX-XXXX e un QR. Scansiona il QR o inserisci il codice nella pagina di verifica: confronta il documento con il registro delle operazioni e dice se è valido. Se i dati sono stati alterati, la verifica segnala che l’impronta non corrisponde più. Il codice deriva dalla chiave segreta della banca, quindi non si può falsificare.`,
          `Jeder Beleg und Kontoauszug ist ein PDF mit einem Code wie TT-XXXX-XXXX-XXXX und einem QR-Code. Scanne den QR-Code oder gib den Code auf der Prüfseite ein: Sie gleicht das Dokument mit dem Operationsregister ab und zeigt, ob es gültig ist. Wurden die Daten verändert, meldet die Prüfung, dass der Fingerabdruck nicht mehr übereinstimmt. Der Code wird aus dem geheimen Schlüssel der Bank abgeleitet und lässt sich deshalb nicht fälschen.`,
          `Каждая квитанция и выписка — PDF с кодом вида TT-XXXX-XXXX-XXXX и QR. Отсканируйте QR или введите код на странице проверки: она сверит документ с реестром операций и покажет, действителен ли он. Если данные изменили, проверка сообщит, что отпечаток не совпадает. Код выводится из секретного ключа банка, поэтому подделать его нельзя.`,
        ),
      },
      {
        q: f('Які мої дані бачить сторінка перевірки?', 'What of my data does the verification page show?', 'Quali miei dati mostra la pagina di verifica?', 'Welche meiner Daten zeigt die Prüfseite?', 'Какие мои данные видит страница проверки?'),
        a: f(
          `Лише знеособлені реквізити: вид документа, суму, дату, власника у вигляді ініціалів із зірочками й останні чотири цифри рахунку. Ім’я, телефон, email чи історію операцій сторінка не розкриває, тож квитанцією можна ділитися, не відкриваючи особистого.`,
          `Only anonymised details: the kind of document, the amount, the date, the holder as initials with asterisks and the last four digits of the account. The page does not reveal your name, phone, email or operation history, so you can share a receipt without exposing anything personal.`,
          `Solo dati resi anonimi: il tipo di documento, l’importo, la data, il titolare come iniziali con asterischi e le ultime quattro cifre del conto. La pagina non rivela nome, telefono, email o storico delle operazioni, quindi puoi condividere una ricevuta senza esporre nulla di personale.`,
          `Nur anonymisierte Angaben: die Art des Dokuments, den Betrag, das Datum, den Inhaber als Initialen mit Sternchen und die letzten vier Ziffern des Kontos. Name, Telefon, E-Mail oder Verlauf zeigt die Seite nicht, sodass du einen Beleg teilen kannst, ohne Persönliches preiszugeben.`,
          `Только обезличенные реквизиты: вид документа, сумму, дату, владельца в виде инициалов со звёздочками и последние четыре цифры счёта. Имя, телефон, email и историю операций страница не раскрывает, поэтому квитанцией можно делиться, не открывая личного.`,
        ),
      },
    ],
  },
];
