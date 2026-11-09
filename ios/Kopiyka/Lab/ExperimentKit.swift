import SwiftUI

/// Досліди лабораторії. Кожен - урок з теорією, живим дослідом і трьома питаннями.
/// Працюють на телефоні, без мережі й без входу.
enum Experiment: String, CaseIterable, Identifiable, Hashable {
    case router, fraud, ledger, idempotency, hold, chain, seal, merkle, work, tax, network

    var id: String { rawValue }

    /// Порядковий номер для римської цифри.
    var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    var title: String {
        switch self {
        case .router: L("Телефон чи сервер").s
        case .fraud: L("Антифрод на телефоні").s
        case .chain: L("Хеш-ланцюг").s
        case .ledger: L("Подвійний запис").s
        case .idempotency: L("Ідемпотентність").s
        case .hold: L("Холд коштів").s
        case .seal: L("Печатка документа").s
        case .merkle: L("Дерево Меркла").s
        case .work: L("Доказ роботи").s
        case .tax: L("Зарплата й податки").s
        case .network: L("Мережа переказів").s
        }
    }

    var line: String {
        switch self {
        case .router: L("Де рахувати: на пристрої чи в хмарі").s
        case .fraud: L("Бал ризику переказу без мережі").s
        case .chain: L("Чому історію не підмінити непомітно").s
        case .ledger: L("Кожен переказ - дві проводки").s
        case .idempotency: L("Повтор запиту не списує двічі").s
        case .hold: L("Заморожено, але ще не списано").s
        case .seal: L("Код, який не підробити без ключа").s
        case .merkle: L("Один відбиток на багато записів").s
        case .work: L("Дорого знайти, дешево перевірити").s
        case .tax: L("Скільки на руки й скільки коштує роботодавцю").s
        case .network: L("Потік, автоплатежі, кліринг і бани").s
        }
    }

    var symbol: String {
        switch self {
        case .router: "arrow.triangle.branch"
        case .fraud: "shield.lefthalf.filled"
        case .chain: "link"
        case .ledger: "equal.square"
        case .idempotency: "arrow.2.squarepath"
        case .hold: "hourglass"
        case .seal: "checkmark.seal"
        case .merkle: "point.3.connected.trianglepath.dotted"
        case .work: "cpu"
        case .tax: "percent"
        case .network: "network"
        }
    }

    var theory: [String] {
        switch self {
        case .router: [
            L("Кожну ІІ-задачу можна виконати на телефоні або на сервері. Сервер точніший, телефон приватний і працює без мережі.").s,
            L("Вибір залежить від стану пристрою: мережі, заряду, нагріву й імовірності відключення світла. Радіо стільникової мережі ще кілька секунд витрачає енергію після передачі.").s,
            L("EdgeRouter рахує для кожного варіанта V·(t − 4·q) + Z·E, де t - час у секундах, q - якість, E - енергія, Z - черга перевитрати. Перемагає найменше значення.").s,
            L("Чутливість даних - жорстке обмеження, а не вага: чек і помічник ідуть на сервер лише після маскування особистих даних.").s,
        ]
        case .fraud: [
            L("Layer 1 бачить лише поля самого переказу: суму, залишок і призначення. Без історії й графа він працює на телефоні за 2 мс.").s,
            L("П'ять нечітких правил: сума трохи нижче порогу, кругла сума, підозрілі слова, майже весь залишок і сума впритул під порогом звітності. Кожне дає бали, один внесок не більший за 70.").s,
            L("Кілька спрацювань разом додають кореляційний бонус. Бал 0-25 - низький ризик, 26-50 - середній, 51-75 - високий, від 76 - критичний.").s,
            L("Історію, швидкість і граф одержувачів бачить лише сервер. Тому в сірій зоні телефон не впевнений, і каскад передає переказ на сервер.").s,
        ]
        case .chain: [
            L("Кожен запис має відбиток SHA-256 від своїх даних і відбитка попереднього запису. Перший запис спирається на нулі.").s,
            L("Змінити одну суму - значить змінити її відбиток, а разом із ним відбитки всіх наступних записів.").s,
            L("Банк веде такий ланцюг для переказів кожного рахунку. Перевірка рахує його наново й показує першу розірвану ланку.").s,
            L("Перерахувати все після правки можна, але тоді зміниться й останній відбиток. Якщо його записано окремо, підміна видна.").s,
        ]
        case .ledger: [
            L("Кожна операція породжує рівно дві проводки: списання (DEBIT) з рахунку відправника і зарахування (CREDIT) на рахунок отримувача.").s,
            L("Сума всіх списань завжди дорівнює сумі всіх зарахувань: гроші не з'являються й не зникають, а лише переходять.").s,
            L("Звірка порівнює ці суми за день. Якщо вони розійшлися, десь є проводка без пари, і банк це бачить.").s,
            L("Тому переказ у банку атомарний: або записуються обидві проводки, або жодна.").s,
        ]
        case .idempotency: [
            L("Мережа підводить: відповідь губиться, застосунок повторює запит, і та сама оплата може піти двічі.").s,
            L("Клієнт додає до запиту ключ. Сервер резервує його, виконує операцію й зберігає відповідь під цим ключем.").s,
            L("Повторний запит з тим самим ключем не виконується: сервер повертає збережену відповідь. Той самий ключ з іншою сумою - конфлікт, запит відхиляється.").s,
            L("Ключ звіряється з відбитком SHA-256 тіла запиту, тому підміна суми не проходить.").s,
        ]
        case .hold: [
            L("Перед платежем банк може заморозити суму: це авторизаційний холд. Гроші лишаються на рахунку, але недоступні.").s,
            L("Доступний залишок - це баланс мінус сума активних холдів. Холд більший за доступне відхиляється.").s,
            L("Холд завершується одним із трьох способів: CAPTURE проводить транзакцію, RELEASE знімає холд без списання, EXPIRE знімає його сам, коли спливає строк.").s,
            L("Строк залежить від причини: платіж карткою 12 годин, авторизація 24, великий переказ 48, перевірка антифроду 72.").s,
        ]
        case .seal: [
            L("Кожна квитанція й виписка має код виду TT-XXXX-XXXX-XXXX. Його друкують у PDF разом із QR-кодом.").s,
            L("Код виводиться з HMAC-SHA256 від виду документа, посилання й власника, ключем, який знає лише сервер.").s,
            L("Той самий документ завжди дає той самий код, а зміна навіть одного символу дає зовсім інший.").s,
            L("Публічна сторінка перевірки перераховує код і звіряє його: без ключа підібрати правильний код неможливо.").s,
        ]
        case .merkle: [
            L("Записи ділять на пари й беруть відбиток SHA-256 від кожної пари, потім від пар відбитків, і так до одного: це корінь дерева.").s,
            L("Корінь - короткий підпис усього набору. Зміна будь-якого запису змінює корінь.").s,
            L("Щоб довести, що запис є в наборі, не треба показувати все: досить сусідніх відбитків на шляху до кореня. Для мільйона записів це лише 20 хешів.").s,
            L("Так блокчейн дає легкому клієнту перевірити свою транзакцію, не завантажуючи весь блок.").s,
        ]
        case .work: [
            L("Блок має дані й число nonce. Треба знайти таке nonce, щоб відбиток SHA-256 від даних і nonce починався із заданої кількості нулів.").s,
            L("Передбачити відбиток неможливо, тому лишається перебирати: кожен додатковий нуль робить пошук у 16 разів довшим.").s,
            L("Перевірка коштує один хеш: хто бачить дані й nonce, перераховує відбиток і порівнює.").s,
            L("Тому змінити старий блок дорого: треба заново знайти nonce для нього й для всіх наступних.").s,
        ]
        case .tax: [
            L("З нарахованої зарплати утримують ПДФО 18% і військовий збір 5%. Решта - сума на руки.").s,
            L("ЄСВ 22% платить роботодавець понад зарплату: працівник його не бачить, а для роботодавця це додаткова вартість.").s,
            L("База ЄСВ обмежена: не більше 20 мінімальних зарплат на місяць.").s,
            L("Ставки в досліді навчальні, для 2026 року. Для реальних розрахунків звіряйтеся з Податковим кодексом.").s,
        ]
        case .network: [
            L("Три банки, дванадцять рахунків і потік переказів між людьми. Кожен переказ проходить антифрод: Layer 1 дивиться на сам переказ, шар історії - на те, що рахунок робив щойно.").s,
            L("Переказ між рахунками одного банку проводиться одразу. Між банками гроші йдуть у кліринг: кошти списано, але одержувач отримає їх лише під час розрахунку.").s,
            L("За період банки зараховують зустрічні потоки й переказують лише різницю між кожною парою. Тому сотні платежів перетворюються на кілька переказів.").s,
            L("Заблокований переказ - страйк рахунку, три страйки - бан. Про кожен переказ відомо, чесний він чи ні, тому видно обидві помилки: пропущене шахрайство й заблоковані чесні перекази.").s,
        ]
        }
    }

    var quiz: [Question] {
        switch self {
        case .router: [
            Question(L("Чек, стільникова мережа, заряд 60%. Де його краще розпізнати?").s,
                     [L("На телефоні").s, L("На сервері").s, L("Однаково").s], answer: 0),
            Question(L("Що відбувається, коли черга перевитрати енергії Z росте?").s,
                     [L("Метод завжди обирає сервер").s, L("Вага енергії в цілі росте, метод тяжіє до дешевших варіантів").s, L("Нічого").s], answer: 1),
            Question(L("Чому текст чека не йде на сервер без маскування?").s,
                     [L("Так швидше").s, L("Сервер не вміє читати чеки").s, L("Чутливість даних - жорстке обмеження").s], answer: 2),
        ]
        case .fraud: [
            Question(L("Переказ 4 900 TAX при залишку 100 000. Яке правило спрацює?").s,
                     [L("Увесь залишок").s, L("Сума трохи нижче порогу").s, L("Підозріла кругла сума").s], answer: 1),
            Question(L("Чого Layer 1 на телефоні не бачить?").s,
                     [L("Історії переказів і графа одержувачів").s, L("Суми").s, L("Призначення").s], answer: 0),
            Question(L("Чому в сірій зоні телефон звертається до сервера?").s,
                     [L("Телефон не вміє рахувати бали").s, L("Сервер має історію й граф, телефон - лише поля переказу").s, L("Так вимагає мережа").s], answer: 1),
        ]
        case .chain: [
            Question(L("Ви змінили суму в третьому записі. Що перестане збігатися?").s,
                     [L("Лише відбиток третього запису").s, L("Нічого").s, L("Відбиток третього й усіх наступних").s], answer: 2),
            Question(L("Навіщо зберігати останній відбиток окремо?").s,
                     [L("Щоб перерахований ланцюг видав себе іншим відбитком").s, L("Щоб заощадити місце").s, L("Для швидкості").s], answer: 0),
            Question(L("На що спирається перший запис ланцюга?").s,
                     [L("На випадкове число").s, L("На відбиток із самих нулів").s, L("На пароль").s], answer: 1),
        ]
        case .ledger: [
            Question(L("Скільки проводок породжує один переказ?").s,
                     [L("Одну").s, L("Дві: списання й зарахування").s, L("Три").s], answer: 1),
            Question(L("Що покаже звірка, якщо записано лише списання?").s,
                     [L("Суми списань і зарахувань розійшлися").s, L("Усе гаразд").s, L("Баланс стане нульовим").s], answer: 0),
            Question(L("Чому переказ атомарний?").s,
                     [L("Щоб було швидше").s, L("Щоб менше місця займав").s, L("Або записуються обидві проводки, або жодна").s], answer: 2),
        ]
        case .idempotency: [
            Question(L("Відповідь на оплату загубилась, клієнт повторив запит з тим самим ключем. Що робить сервер?").s,
                     [L("Списує ще раз").s, L("Віддає збережену відповідь без нового списання").s, L("Блокує рахунок").s], answer: 1),
            Question(L("Той самий ключ, але інша сума. Що буде?").s,
                     [L("Нова оплата").s, L("Стара сума замінюється").s, L("Конфлікт: запит відхилено").s], answer: 2),
            Question(L("Що буде без ключа при такому самому повторі?").s,
                     [L("Нічого").s, L("Списання пройде двічі").s, L("Сервер здогадається").s], answer: 1),
        ]
        case .hold: [
            Question(L("Баланс 1000, активний холд 300. Скільки доступно?").s,
                     [L("1000").s, L("700").s, L("300").s], answer: 1),
            Question(L("Чим CAPTURE відрізняється від RELEASE?").s,
                     [L("Нічим").s, L("RELEASE списує гроші").s, L("CAPTURE проводить транзакцію, RELEASE знімає холд без списання").s], answer: 2),
            Question(L("Скільки живе холд платежу карткою?").s,
                     [L("12 годин").s, L("72 години").s, L("Безстроково").s], answer: 0),
        ]
        case .seal: [
            Question(L("Що потрібно, щоб випустити правильний код?").s,
                     [L("Лише номер квитанції").s, L("Знати ключ сервера").s, L("Нічого").s], answer: 1),
            Question(L("Я змінив один символ у посиланні документа. Що з кодом?").s,
                     [L("Лишився тим самим").s, L("Став коротшим").s, L("Став зовсім іншим").s], answer: 2),
            Question(L("Той самий документ випустили двічі. Які коди?").s,
                     [L("Однакові").s, L("Різні").s, L("Випадкові").s], answer: 0),
        ]
        case .merkle: [
            Question(L("Ви змінили один запис із чотирьох. Що буде з коренем?").s,
                     [L("Лишиться тим самим").s, L("Зміниться").s, L("Стане нульовим").s], answer: 1),
            Question(L("Скільки відбитків потрібно для доказу запису в наборі з 8 записів?").s,
                     [L("Один").s, L("Три").s, L("Вісім").s], answer: 1),
            Question(L("Що перевіряє той, хто отримав доказ?").s,
                     [L("Що корінь, перерахований із доказу, збігається з відомим").s, L("Що всі записи на місці").s, L("Що сервер працює").s], answer: 0),
        ]
        case .work: [
            Question(L("Складність виросла на один нуль. Скільки спроб тепер потрібно в середньому?").s,
                     [L("У 2 рази більше").s, L("У 16 разів більше").s, L("Стільки ж").s], answer: 1),
            Question(L("Скільки хешів потрібно, щоб перевірити знайдене nonce?").s,
                     [L("Один").s, L("Стільки, скільки було спроб").s, L("Жодного").s], answer: 0),
            Question(L("Ви змінили дані блока після пошуку nonce. Що з відбитком?").s,
                     [L("Лишився тим самим").s, L("Став іншим, нулі на початку зазвичай зникли").s, L("Став коротшим").s], answer: 1),
        ]
        case .tax: [
            Question(L("Нараховано 10 000. Скільки на руки?").s,
                     [L("7 700").s, L("8 200").s, L("10 000").s], answer: 0),
            Question(L("Хто платить ЄСВ із зарплати?").s,
                     [L("Працівник із зарплати").s, L("Роботодавець понад зарплату").s, L("Банк").s], answer: 1),
            Question(L("Скільки коштує роботодавцю зарплата 10 000 разом з ЄСВ?").s,
                     [L("10 000").s, L("12 200").s, L("7 700").s], answer: 1),
        ]
        case .network: [
            Question(L("Переказ між банками: коли одержувач бачить гроші?").s,
                     [L("Одразу").s, L("Після міжбанківського розрахунку").s, L("Ніколи").s], answer: 1),
            Question(L("Навіщо банкам кліринг?").s,
                     [L("Щоб переказувати лише різницю зустрічних потоків").s, L("Щоб гроші йшли повільніше").s, L("Щоб приховати перекази").s], answer: 0),
            Question(L("Поріг блокування знизили. Що буде?").s,
                     [L("Менше шахрайства пройде, але більше чесних переказів зупиниться").s, L("Нічого не зміниться").s, L("Шахрайство пройде частіше").s], answer: 0),
        ]
        }
    }
}

struct Question {
    let text: String
    let options: [String]
    let answer: Int

    init(_ text: String, _ options: [String], answer: Int) {
        self.text = text
        self.options = options
        self.answer = answer
    }
}

/// Скільки питань з трьох відповіли правильно в кожному досліді. Лежить лише на телефоні.
@MainActor @Observable
final class LabProgress {
    static let shared = LabProgress()
    private static let key = "labProgress"

    private(set) var scores: [String: Int] = (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]

    /// Дослід пройдено, коли правильні щонайменше дві відповіді з трьох.
    static let passMark = 2

    func score(_ e: Experiment) -> Int? { scores[e.rawValue] }
    func passed(_ e: Experiment) -> Bool { (scores[e.rawValue] ?? 0) >= Self.passMark }
    var passedCount: Int { Experiment.allCases.filter(passed).count }

    func record(_ e: Experiment, score: Int) {
        guard score > (scores[e.rawValue] ?? -1) else { return }
        scores[e.rawValue] = score
        UserDefaults.standard.set(scores, forKey: Self.key)
    }
}

/// Урок: теорія, дослід, перевірка.
struct ExperimentScreen: View {
    let experiment: Experiment
    @State private var part: Part = {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["KOPIYKA_PART"] {
        case "lab": return .lab
        case "quiz": return .quiz
        default: break
        }
        #endif
        return .theory
    }()

    enum Part: Hashable { case theory, lab, quiz }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                SegmentBar(items: [(Part.theory, L("Теорія").s), (.lab, L("Дослід").s), (.quiz, L("Перевірка").s)], selection: $part)
                switch part {
                case .theory: theory
                case .lab: lab
                case .quiz: QuizView(experiment: experiment)
                }
                BankBridge(experiment: experiment)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle("Esperimento \(String(format: "%02d", experiment.number))")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(experiment.title).font(.display(32, .medium)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var theory: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(experiment.theory.enumerated()), id: \.offset) { i, text in
                if i > 0 { Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 0.5) }
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(String(format: "%02d", i + 1))
                        .font(Theme.ui(13, .semibold)).tracking(1.5)
                        .foregroundStyle(Theme.gold).frame(width: 24, alignment: .leading)
                    Text(text).font(Theme.ui(17)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 16)
            }
            Button(L("До досліду").s) { withAnimation(.snappy) { part = .lab } }
                .buttonStyle(InkButton())
                .padding(.top, 14)
        }
    }

    @ViewBuilder private var lab: some View {
        switch experiment {
        case .router: RouterLab()
        case .fraud: FraudLab()
        case .chain: ChainLab()
        case .ledger: LedgerLab()
        case .idempotency: IdempotencyLab()
        case .hold: HoldLab()
        case .seal: SealLab()
        case .merkle: MerkleLab()
        case .work: WorkLab()
        case .tax: TaxLab()
        case .network: NetworkLab()
        }
    }
}

/// Три питання по одному, з миттєвою відповіддю; результат зберігається.
struct QuizView: View {
    let experiment: Experiment
    @State private var picked: [Int: Int] = [:]
    @State private var current = 0
    @State private var progress = LabProgress.shared

    var body: some View {
        let qs = experiment.quiz
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 4) {
                ForEach(qs.indices, id: \.self) { i in
                    Rectangle()
                        .fill(i < current || (i == current && picked[i] != nil) ? Theme.accent : Theme.ink.opacity(0.14))
                        .frame(height: 2)
                }
            }
            if current >= qs.count {
                result(qs)
            } else {
                question(qs, current)
            }
        }
        .sensoryFeedback(.selection, trigger: picked.count)
        .animation(.snappy, value: picked)
        .animation(.snappy, value: current)
    }

    private static func score(_ qs: [Question], _ picked: [Int: Int]) -> Int {
        qs.indices.filter { picked[$0] == qs[$0].answer }.count
    }

    private func question(_ qs: [Question], _ i: Int) -> some View {
        let q = qs[i]
        return VStack(alignment: .leading, spacing: 14) {
            Text(String(format: "%02d / %02d", i + 1, qs.count))
                .font(Theme.ui(13, .semibold)).tracking(1.5).foregroundStyle(Theme.gold)
            Text(q.text).font(.display(24, .medium)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                ForEach(q.options.indices, id: \.self) { o in option(i, q, o) }
            }
            .padding(.top, 4)
            if picked[i] != nil {
                Button(i + 1 < qs.count ? L("Далі").s : L("Результат").s) { current += 1 }
                    .buttonStyle(InkButton())
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .id(i)
        .transition(.opacity)
    }

    private func result(_ qs: [Question]) -> some View {
        let score = Self.score(qs, picked)
        let pass = score >= LabProgress.passMark
        return VStack(alignment: .leading, spacing: 14) {
            LabHero(ok: pass) {
                HeroCaption(pass ? L("Пройдено").s : L("Ще раз").s)
                Text("\(score) / \(qs.count)").font(Theme.balance(56)).monospacedDigit().padding(.top, 2)
            }
            if !pass {
                Button(L("Спробувати знову").s) { picked = [:]; current = 0 }.buttonStyle(InkButton())
            }
            if let best = progress.score(experiment) {
                Text(L("Найкращий результат: \(best) / \(qs.count)").s).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func option(_ i: Int, _ q: Question, _ o: Int) -> some View {
        let chosen = picked[i]
        let revealed = chosen != nil
        let right = o == q.answer
        let wrong = revealed && chosen == o && !right
        let outline: Color = revealed && right ? Theme.accent : (wrong ? Theme.alert : Theme.ink.opacity(0.1))
        return Button {
            guard chosen == nil else { return }
            picked[i] = o
            let qs = experiment.quiz
            if picked.count == qs.count { progress.record(experiment, score: Self.score(qs, picked)) }
        } label: {
            HStack(spacing: 14) {
                Text(["A", "B", "C", "D"][min(o, 3)])
                    .font(Theme.ui(13, .semibold)).tracking(1)
                    .foregroundStyle(revealed && right ? Theme.accent : (wrong ? Theme.alert : Theme.gold))
                    .frame(width: 18)
                Text(q.options[o]).font(Theme.ui(style: .subheadline, .medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if revealed, right || wrong {
                    Image(systemName: right ? "checkmark" : "xmark")
                        .font(Theme.ui(style: .footnote, .bold))
                        .foregroundStyle(right ? Theme.accent : Theme.alert)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(outline, lineWidth: revealed && (right || wrong) ? 1.5 : 1)
            }
            .opacity(revealed && !right && !wrong ? 0.55 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(PressScale())
    }
}

/// Рядок керування в досліді: підпис, значення й повзунок.
struct LabSlider: View {
    let title: String
    let value: String
    @Binding var x: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(Theme.ui(style: .subheadline))
                Spacer()
                Text(value).font(Theme.ui(style: .subheadline, .semibold)).monospacedDigit()
            }
            Slider(value: $x, in: range).tint(Theme.accent)
        }
    }
}

/// Блок керування або результату на поверхні з тонкою золотою лінією.
struct LabPanel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title { Text(title).caption() }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .goldEdge(22)
    }
}

/// Панель результату досліду: темна поверхня, кольорова смуга зліва показує стан (норма або збій).
struct LabHero<Content: View>: View {
    var ok = true
    @ViewBuilder var content: Content

    var body: some View {
        let tone = ok ? Theme.accent : Theme.alert
        HeroPanel { content }
            .overlay { RoundedRectangle(cornerRadius: 24, style: .continuous).fill(tone.opacity(0.07)).allowsHitTesting(false) }
            .overlay(alignment: .leading) { Capsule().fill(tone).frame(width: 3).padding(.vertical, 24).padding(.leading, 9) }
            .animation(.snappy, value: ok)
    }
}
