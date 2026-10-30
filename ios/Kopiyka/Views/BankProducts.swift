import SwiftUI

// MARK: Картки

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
                    Button(L("Випустити віртуальну картку").s) {
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
            .navigationTitle(L("Нова картка").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
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

    private var active: [API.Deposit] { items.filter(\.isActive) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if loaded && items.isEmpty {
                    BrandEmpty(title: L("Депозитів ще немає").s, action: L("Відкрити депозит").s) { opening = true }
                } else if !items.isEmpty {
                    HeroPanel {
                        HeroCaption(L("На депозитах").s)
                        BigAmount(value: active.reduce(0) { $0 + $1.amount }, size: 40).padding(.top, 6)
                        HStack(alignment: .top, spacing: 16) {
                            Stat(value: "+" + Format.money(active.reduce(0) { $0 + $1.interestEarned }), label: L("дохід за строк").s, inverted: true)
                            Stat(value: "\(active.count)", label: L("активних").s, inverted: true)
                        }
                        .padding(.top, 14)
                    }
                    ForEach(items) { d in card(d) }
                    Button(L("Відкрити депозит").s) { opening = true }.buttonStyle(InkButton())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle(L("Депозити").s)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $opening) { OpenDepositView { await load() } }
        .confirmationDialog(L("Закрити депозит?").s, isPresented: .init(get: { closing != nil }, set: { if !$0 { closing = nil } }),
                            titleVisibility: .visible, presenting: closing) { d in
            Button(d.matured == true ? L("Закрити й забрати відсотки").s : L("Закрити достроково, можливий штраф").s,
                   role: .destructive) {
                Task {
                    await screen.run { try await model.api.closeDeposit(d.id, early: d.matured != true) }
                    await load()
                }
            }
        }
    }

    private func card(_ d: API.Deposit) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(d.description?.isEmpty == false ? d.description! : L("Депозит на \(d.termMonths) міс.").s).font(.headline)
                        Text(L("\(d.interestRate.formatted())% річних").s).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.money(d.amount)).font(.title3.weight(.bold)).monospacedDigit()
                }
                if d.isActive {
                    Meter(value: d.progress ?? 0)
                    HStack {
                        Text("+\(Format.money(d.interestEarned))").font(.subheadline.weight(.semibold)).monospacedDigit()
                        Spacer()
                        Text(L("до \(BankText.date(d.maturityDate))").s).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button(d.matured == true ? L("Забрати з відсотками").s : L("Закрити достроково").s) { closing = d }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text(L("Закрито").s).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .opacity(d.isActive ? 1 : 0.6)
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
                    TextField(L("Сума, TAX (від 500)").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker(L("Строк").s, selection: $months) {
                        ForEach(Self.rates.keys.sorted(), id: \.self) { Text(L("\($0) міс. · \(Self.rates[$0]!.formatted())%").s).tag($0) }
                    }
                    Toggle(L("Продовжувати автоматично").s, isOn: $renew)
                        .tint(Theme.ink.opacity(0.6))
                    TextField(L("Назва (необов'язково)").s, text: $note)
                } footer: {
                    Text(L("Дохід приблизно \(Format.money(estimate)).").s)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Відкрити депозит").s, disabled: (amount ?? 0) < 500 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.openDeposit(amount: amount ?? 0, months: months, autoRenew: renew, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Новий депозит").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
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

    private var active: [API.Credit] { items.filter(\.isActive) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if loaded && items.isEmpty {
                    BrandEmpty(title: L("Кредитів немає").s, action: L("Оформити кредит").s) { applying = true }
                } else if !items.isEmpty {
                    HeroPanel {
                        HeroCaption(L("Залишок боргу").s)
                        BigAmount(value: active.reduce(0) { $0 + $1.balanceRemaining }, size: 40).padding(.top, 6)
                        HStack(alignment: .top, spacing: 16) {
                            Stat(value: Format.money(active.reduce(0) { $0 + $1.monthlyPayment }), label: L("платіж на місяць").s, inverted: true)
                            Stat(value: active.compactMap(\.nextPaymentDate).min().map { BankText.date($0) } ?? "-",
                                 label: L("наступний платіж").s, inverted: true)
                        }
                        .padding(.top, 14)
                    }
                    ForEach(items) { c in card(c) }
                    Button(L("Оформити кредит").s) { applying = true }.buttonStyle(LineButton())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle(L("Кредити").s)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $applying) { TakeCreditView { await load() } }
        .sheet(item: $repaying) { c in
            AmountSheet(title: L("Платіж за кредитом").s, action: L("Сплатити").s,
                        hint: L("Залишилось \(Format.money(c.balanceRemaining)).").s,
                        amount: min(c.monthlyPayment, c.balanceRemaining)) { a in
                try await model.api.repayCredit(c.id, amount: a)
                await load()
            }
        }
    }

    private func card(_ c: API.Credit) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.description?.isEmpty == false ? c.description! : L("Кредит на \(c.termMonths) міс.").s).font(.headline)
                        Text(L("\(Format.money(c.principal)) під \(c.interestRate.formatted())%").s).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.money(c.balanceRemaining)).font(.title3.weight(.bold)).monospacedDigit()
                }
                if c.isActive {
                    Meter(value: c.progress ?? 0)
                    HStack {
                        Text(L("сплачено \(Format.money(c.totalPaid))").s).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        Text(BankText.date(c.nextPaymentDate)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button(L("Сплатити \(Format.money(min(c.monthlyPayment, c.balanceRemaining)))").s) { repaying = c }
                        .buttonStyle(InkButton())
                } else {
                    Text(L("Погашено").s).font(.subheadline.weight(.semibold))
                }
            }
            .padding(16)
        }
        .opacity(c.isActive ? 1 : 0.6)
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
                    TextField(L("Сума, TAX (1 000 - 500 000)").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker(L("Строк").s, selection: $months) {
                        ForEach(Self.rates.keys.sorted(), id: \.self) { Text(L("\($0) міс. · \(Self.rates[$0]!.formatted())%").s).tag($0) }
                    }
                    TextField(L("Мета (необов'язково)").s, text: $note)
                } footer: {
                    Text(L("Приблизно \(Format.money(monthly)) на місяць.").s)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Оформити кредит").s, disabled: (amount ?? 0) < 1000 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.takeCredit(amount: amount ?? 0, months: months, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Новий кредит").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
    }

    /// Ануїтет: P·r / (1 − (1 + r)^−n), r - місячна ставка.
    private var monthly: Double {
        let p = amount ?? 0
        let r = (Self.rates[months] ?? 0) / 100 / 12
        return r == 0 ? p / Double(months) : p * r / (1 - pow(1 + r, -Double(months)))
    }
}
