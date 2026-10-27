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
                    BrandEmpty(title: "Депозитів ще немає", action: "Відкрити депозит") { opening = true }
                } else if !items.isEmpty {
                    HeroPanel {
                        HeroCaption("На депозитах")
                        BigAmount(value: active.reduce(0) { $0 + $1.amount }, size: 40).padding(.top, 6)
                        HStack(alignment: .top, spacing: 16) {
                            Stat(value: "+" + Format.money(active.reduce(0) { $0 + $1.interestEarned }), label: "дохід за строк", inverted: true)
                            Stat(value: "\(active.count)", label: "активних", inverted: true)
                        }
                        .padding(.top, 14)
                    }
                    ForEach(items) { d in card(d) }
                    Button("Відкрити депозит") { opening = true }.buttonStyle(InkButton())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Депозити")
        .navigationBarTitleDisplayMode(.inline)
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

    private func card(_ d: API.Deposit) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(d.description?.isEmpty == false ? d.description! : "Депозит на \(d.termMonths) міс.").font(.headline)
                        Text("\(d.interestRate.formatted())% річних").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.money(d.amount)).font(.title3.weight(.bold)).monospacedDigit()
                }
                if d.isActive {
                    Meter(value: d.progress ?? 0)
                    HStack {
                        Text("+\(Format.money(d.interestEarned))").font(.subheadline.weight(.semibold)).monospacedDigit()
                        Spacer()
                        Text("до \(BankText.date(d.maturityDate))").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button(d.matured == true ? "Забрати з відсотками" : "Закрити достроково") { closing = d }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                } else {
                    Text("Закрито").font(.subheadline).foregroundStyle(.secondary)
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
                    TextField("Сума, TAX (від 500)", value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker("Строк", selection: $months) {
                        ForEach(Self.rates.keys.sorted(), id: \.self) { Text("\($0) міс. · \(Self.rates[$0]!.formatted())%").tag($0) }
                    }
                    Toggle("Продовжувати автоматично", isOn: $renew)
                        .tint(Theme.ink.opacity(0.6))
                    TextField("Назва (необов'язково)", text: $note)
                } footer: {
                    Text("Дохід приблизно \(Format.money(estimate)).")
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

    private var active: [API.Credit] { items.filter(\.isActive) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if loaded && items.isEmpty {
                    BrandEmpty(title: "Кредитів немає", action: "Оформити кредит") { applying = true }
                } else if !items.isEmpty {
                    HeroPanel {
                        HeroCaption("Залишок боргу")
                        BigAmount(value: active.reduce(0) { $0 + $1.balanceRemaining }, size: 40).padding(.top, 6)
                        HStack(alignment: .top, spacing: 16) {
                            Stat(value: Format.money(active.reduce(0) { $0 + $1.monthlyPayment }), label: "платіж на місяць", inverted: true)
                            Stat(value: active.compactMap(\.nextPaymentDate).min().map { BankText.date($0) } ?? "-",
                                 label: "наступний платіж", inverted: true)
                        }
                        .padding(.top, 14)
                    }
                    ForEach(items) { c in card(c) }
                    Button("Оформити кредит") { applying = true }.buttonStyle(LineButton())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Кредити")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $applying) { TakeCreditView { await load() } }
        .sheet(item: $repaying) { c in
            AmountSheet(title: "Платіж за кредитом", action: "Сплатити",
                        hint: "Залишилось \(Format.money(c.balanceRemaining)).",
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
                        Text(c.description?.isEmpty == false ? c.description! : "Кредит на \(c.termMonths) міс.").font(.headline)
                        Text("\(Format.money(c.principal)) під \(c.interestRate.formatted())%").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.money(c.balanceRemaining)).font(.title3.weight(.bold)).monospacedDigit()
                }
                if c.isActive {
                    Meter(value: c.progress ?? 0)
                    HStack {
                        Text("сплачено \(Format.money(c.totalPaid))").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        Text(BankText.date(c.nextPaymentDate)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("Сплатити \(Format.money(min(c.monthlyPayment, c.balanceRemaining)))") { repaying = c }
                        .buttonStyle(InkButton())
                } else {
                    Text("Погашено").font(.subheadline.weight(.semibold))
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
                    TextField("Сума, TAX (1 000 - 500 000)", value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker("Строк", selection: $months) {
                        ForEach(Self.rates.keys.sorted(), id: \.self) { Text("\($0) міс. · \(Self.rates[$0]!.formatted())%").tag($0) }
                    }
                    TextField("Мета (необов'язково)", text: $note)
                } footer: {
                    Text("Приблизно \(Format.money(monthly)) на місяць.")
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
