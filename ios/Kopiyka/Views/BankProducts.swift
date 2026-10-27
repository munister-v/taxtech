import SwiftUI

// MARK: Картки

struct CardsView: View {
    @Environment(AppModel.self) private var model
    @State private var cards: [API.Card] = []
    @State private var selected: API.Card?
    @State private var issuing = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if loaded && cards.isEmpty {
                    Text("Карток немає").foregroundStyle(.secondary).padding(.top, 40)
                }
                ForEach(cards) { card in
                    Button { selected = card } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            VirtualCardView(number: card.maskedNumber, expiry: card.expiryDisplay,
                                            holder: card.holderName, design: CardDesign(server: card.design),
                                            frozen: card.isBlocked)
                            HStack {
                                Text(card.isPrimary ? "Основна" : "Додаткова")
                                Spacer()
                                Text(card.isBlocked ? "Заморожена" : "Активна")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Картки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Нова картка", systemImage: "plus") { issuing = true } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { card in
            CardDetailView(card: card) { await load() }
        }
        .sheet(isPresented: $issuing) { IssueCardView { await load() } }
    }

    private func load() async {
        cards = ((try? await model.api.cards()) ?? []).filter { !$0.isClosed }
        loaded = true
    }
}

struct IssueCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var design = CardDesign.dark
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VirtualCardView(number: "•••• •••• •••• ••••", expiry: nil, holder: nil, design: design)
                        .padding(.horizontal, 24)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 18) {
                        ForEach(CardDesign.allCases) { d in
                            Button { design = d } label: {
                                VStack(spacing: 8) {
                                    VirtualCardView(number: "", expiry: nil, holder: nil, design: d, compact: true)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .strokeBorder(Theme.ink, lineWidth: design == d ? 2 : 0)
                                                .padding(-5)
                                        }
                                    Text(d.title).font(.footnote.weight(design == d ? .semibold : .regular))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                    Button("Випустити віртуальну картку") {
                        Task {
                            if await screen.run({ try await model.api.issueCard(design: design.rawValue) }) {
                                await done()
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(InkButton())
                    .disabled(screen.busy)
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
            }
            .screenBackground()
            .navigationTitle("Нова картка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
        }
    }
}

struct CardDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: API.Card
    let changed: () async -> Void
    @State private var revealed: API.Revealed?
    @State private var screen = Screen()
    @State private var topUp = false
    @State private var confirmClose = false

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    VirtualCardView(number: revealed?.cardNumber ?? card.maskedNumber,
                                    expiry: card.expiryDisplay, holder: card.holderName,
                                    design: CardDesign(server: card.design), frozen: card.isBlocked)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                }
                Section {
                    if let r = revealed {
                        Line("Номер", r.cardNumber)
                        Line("CVV", r.cvv)
                        Button("Сховати реквізити") { revealed = nil }
                    } else {
                        Button("Показати реквізити") {
                            Task { await screen.run { revealed = try await model.api.reveal(card.id) } }
                        }
                    }
                } footer: {
                    Text("Реквізити віртуальні: з ними не можна заплатити поза навчальним банком.")
                }
                Section {
                    Button("Поповнити з рахунку") { topUp = true }
                    if !card.isPrimary {
                        Button("Зробити основною") { act { try await model.api.setPrimary(card.id) } }
                    }
                    Menu("Змінити дизайн") {
                        ForEach(CardDesign.allCases) { d in
                            Button(d.title) { act { try await model.api.setCardDesign(card.id, d.rawValue) } }
                        }
                    }
                    Button(card.isBlocked ? "Розморозити" : "Заморозити") { act { try await model.api.toggleCardBlock(card.id) } }
                }
                Section {
                    Button("Закрити картку") { confirmClose = true }
                }
                ErrorSection(error: screen.error)
            }
            .labForm()
            .navigationTitle("Картка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .sheet(isPresented: $topUp) {
                AmountSheet(title: "На картку", action: "Поповнити", amount: 500) { a in
                    try await model.api.topUpCard(card.id, a)
                    await changed()
                }
            }
            .confirmationDialog("Закрити картку назавжди?", isPresented: $confirmClose, titleVisibility: .visible) {
                Button("Закрити", role: .destructive) { act { try await model.api.closeCard(card.id) } }
            }
        }
    }

    private func act(_ work: @escaping () async throws -> Void) {
        Task {
            if await screen.run(work) {
                await changed()
                dismiss()
            }
        }
    }
}

// MARK: Депозити

struct DepositsView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Deposit] = []
    @State private var opening = false
    @State private var closing: API.Deposit?
    @State private var screen = Screen()
    @State private var loaded = false

    var body: some View {
        LabForm {
            if loaded && items.isEmpty {
                Section { Text("Депозитів ще немає. Відкрийте перший - відсотки нараховуються за строк.").foregroundStyle(.secondary) }
            }
            ForEach(items) { d in
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(d.description?.isEmpty == false ? d.description! : "Депозит на \(d.termMonths) міс.").font(.headline)
                        Spacer()
                        Text(Format.money(d.amount)).font(.headline).monospacedDigit()
                    }
                    Line("Ставка", "\(d.interestRate.formatted())% річних")
                    Line("Дохід за строк", Format.money(d.interestEarned))
                    Line("До", BankText.date(d.maturityDate))
                    Meter(value: d.progress ?? 0)
                    if d.isActive {
                        Button("Закрити депозит") { closing = d }
                    } else {
                        Text("Закрито").foregroundStyle(.secondary)
                    }
                }
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle("Депозити")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Новий депозит", systemImage: "plus") { opening = true } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $opening) { OpenDepositView { await load() } }
        .confirmationDialog("Закрити депозит?", isPresented: .init(get: { closing != nil }, set: { if !$0 { closing = nil } }),
                            titleVisibility: .visible, presenting: closing) { d in
            Button(d.matured == true ? "Закрити й забрати відсотки" : "Закрити достроково, можливий штраф",
                   role: .destructive) {
                Task {
                    await screen.run { try await model.api.closeDeposit(d.id, early: d.matured != true) }
                    await load()
                }
            }
        }
    }

    private func load() async {
        items = (try? await model.api.deposits()) ?? []
        loaded = true
    }
}

struct OpenDepositView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var amount: Double? = 1000
    @State private var months = 3
    @State private var renew = false
    @State private var note = ""
    @State private var screen = Screen()

    static let rates = [1: 8.0, 3: 10.0, 6: 12.0, 12: 14.0]

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField("Сума, ₴ (від 500)", value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker("Строк", selection: $months) {
                        ForEach(Self.rates.keys.sorted(), id: \.self) { Text("\($0) міс. · \(Self.rates[$0]!.formatted())%").tag($0) }
                    }
                    Toggle("Продовжувати автоматично", isOn: $renew)
                        .tint(Theme.ink.opacity(0.6))
                    TextField("Назва (необов'язково)", text: $note)
                } footer: {
                    Text("Орієнтовний дохід: \(Format.money(estimate)). Сума списується з рахунку на весь строк.")
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Відкрити депозит", disabled: (amount ?? 0) < 500 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.openDeposit(amount: amount ?? 0, months: months, autoRenew: renew, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Новий депозит")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
        }
    }

    private var estimate: Double { (amount ?? 0) * (Self.rates[months] ?? 0) / 100 * Double(months) * 30.4 / 365 }
}

// MARK: Кредити

struct CreditsView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Credit] = []
    @State private var applying = false
    @State private var repaying: API.Credit?
    @State private var screen = Screen()
    @State private var loaded = false

    var body: some View {
        LabForm {
            if loaded && items.isEmpty {
                Section { Text("Кредитів немає. Гроші віртуальні, тож це спосіб подивитись, як працює графік платежів.").foregroundStyle(.secondary) }
            }
            ForEach(items) { c in
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(c.description?.isEmpty == false ? c.description! : "Кредит на \(c.termMonths) міс.").font(.headline)
                        Spacer()
                        Text(Format.money(c.balanceRemaining)).font(.headline).monospacedDigit()
                    }
                    Line("Узято", Format.money(c.principal))
                    Line("Ставка", "\(c.interestRate.formatted())% річних")
                    Line("Щомісячний платіж", Format.money(c.monthlyPayment))
                    Line("Сплачено", Format.money(c.totalPaid))
                    if c.isActive {
                        Line("Наступний платіж", BankText.date(c.nextPaymentDate))
                        Meter(value: c.progress ?? 0)
                        Button("Сплатити") { repaying = c }
                    } else {
                        Text("Погашено").foregroundStyle(.secondary)
                    }
                }
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle("Кредити")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Новий кредит", systemImage: "plus") { applying = true } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $applying) { TakeCreditView { await load() } }
        .sheet(item: $repaying) { c in
            AmountSheet(title: "Платіж за кредитом", action: "Сплатити",
                        hint: "Залишилось сплатити \(Format.money(c.balanceRemaining)). Сума більша за залишок погасить кредит повністю.",
                        amount: min(c.monthlyPayment, c.balanceRemaining)) { a in
                try await model.api.repayCredit(c.id, amount: a)
                await load()
            }
        }
    }

    private func load() async {
        items = (try? await model.api.credits()) ?? []
        loaded = true
    }
}

struct TakeCreditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var amount: Double? = 5000
    @State private var months = 6
    @State private var note = ""
    @State private var screen = Screen()

    static let rates = [3: 18.0, 6: 20.0, 12: 22.0, 24: 24.0, 36: 26.0]

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField("Сума, ₴ (1 000 - 500 000)", value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker("Строк", selection: $months) {
                        ForEach(Self.rates.keys.sorted(), id: \.self) { Text("\($0) міс. · \(Self.rates[$0]!.formatted())%").tag($0) }
                    }
                    TextField("Мета (необов'язково)", text: $note)
                } footer: {
                    Text("Орієнтовний платіж: \(Format.money(monthly)) на місяць. Точний графік дасть сервер.")
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Оформити кредит", disabled: (amount ?? 0) < 1000 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.takeCredit(amount: amount ?? 0, months: months, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Новий кредит")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
        }
    }

    /// Ануїтет: P·r / (1 − (1 + r)^−n), r - місячна ставка.
    private var monthly: Double {
        let p = amount ?? 0
        let r = (Self.rates[months] ?? 0) / 100 / 12
        return r == 0 ? p / Double(months) : p * r / (1 - pow(1 + r, -Double(months)))
    }
}
