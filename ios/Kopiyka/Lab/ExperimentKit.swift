import SwiftUI

/// Досліди лабораторії. Кожен - урок з теорією, живим дослідом і трьома питаннями.
/// Працюють на телефоні, без мережі й без входу.
enum Experiment: String, CaseIterable, Identifiable, Hashable {
    case router, fraud, chain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .router: L("Телефон чи сервер").s
        case .fraud: L("Антифрод на телефоні").s
        case .chain: L("Хеш-ланцюг").s
        }
    }

    var line: String {
        switch self {
        case .router: L("Де рахувати: на пристрої чи в хмарі").s
        case .fraud: L("Бал ризику переказу без мережі").s
        case .chain: L("Чому історію не підмінити непомітно").s
        }
    }

    var symbol: String {
        switch self {
        case .router: "arrow.triangle.branch"
        case .fraud: "shield.lefthalf.filled"
        case .chain: "link"
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
    @State private var part = Part.theory

    enum Part: Hashable { case theory, lab, quiz }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SegmentBar(items: [(Part.theory, L("Теорія").s), (.lab, L("Дослід").s), (.quiz, L("Перевірка").s)], selection: $part)
                switch part {
                case .theory: theory
                case .lab: lab
                case .quiz: QuizView(experiment: experiment)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle(experiment.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var theory: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(experiment.theory.enumerated()), id: \.offset) { i, text in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("\(i + 1)").caption().frame(width: 14, alignment: .leading)
                    Text(text).font(.body).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }
            }
            Button(L("До досліду").s) { withAnimation(.snappy) { part = .lab } }
                .buttonStyle(InkButton())
                .padding(.top, 6)
        }
    }

    @ViewBuilder private var lab: some View {
        switch experiment {
        case .router: RouterLab()
        case .fraud: FraudLab()
        case .chain: ChainLab()
        }
    }
}

/// Три питання з миттєвою відповіддю; результат зберігається.
struct QuizView: View {
    let experiment: Experiment
    @State private var picked: [Int: Int] = [:]
    @State private var progress = LabProgress.shared

    var body: some View {
        let questions = experiment.quiz
        let done = picked.count == questions.count
        let score = Self.score(questions, picked)
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(questions.enumerated()), id: \.offset) { i, q in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(i + 1) / \(questions.count)").caption()
                    Text(q.text).font(.headline).fixedSize(horizontal: false, vertical: true)
                    ForEach(q.options.indices, id: \.self) { o in option(i, q, o) }
                }
            }
            if done {
                HeroPanel(yellow: score >= LabProgress.passMark) {
                    HeroCaption(score >= LabProgress.passMark ? L("Пройдено").s : L("Ще раз").s)
                    Text("\(score) / \(questions.count)").font(Theme.balance(40)).monospacedDigit()
                    if score < LabProgress.passMark {
                        Button(L("Спробувати знову").s) { withAnimation(.snappy) { picked = [:] } }
                            .buttonStyle(LineButton()).padding(.top, 12)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if let best = progress.score(experiment) {
                Text(L("Найкращий результат: \(best) / \(questions.count)").s).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.selection, trigger: picked.count)
        .animation(.snappy, value: picked)
    }

    private static func score(_ qs: [Question], _ picked: [Int: Int]) -> Int {
        qs.indices.filter { picked[$0] == qs[$0].answer }.count
    }

    private func option(_ i: Int, _ q: Question, _ o: Int) -> some View {
        let chosen = picked[i]
        let revealed = chosen != nil
        let right = o == q.answer
        return Button {
            guard chosen == nil else { return }
            picked[i] = o
            let qs = experiment.quiz
            if picked.count == qs.count { progress.record(experiment, score: Self.score(qs, picked)) }
        } label: {
            HStack(spacing: 12) {
                Text(q.options[o]).font(.subheadline.weight(.medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if revealed, right || chosen == o {
                    Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(right ? Theme.accent : Color.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(revealed && right ? Theme.accent : Theme.ink.opacity(chosen == o ? 0.5 : 0.1), lineWidth: revealed && right ? 1.5 : 1)
            }
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
                Text(title).font(.subheadline)
                Spacer()
                Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
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
