import QuickLook
import SwiftUI

// MARK: Донати

struct DonationsView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Donation] = []
    @State private var giving = false
    @State private var loaded = false

    private var total: Double { items.reduce(0) { $0 + $1.amount } }

    var body: some View {
        LabForm {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Усього задоначено").s).caption()
                    Text(Format.money(total)).font(Theme.balance(40)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }
            if loaded && items.isEmpty {
                Section { BrandEmpty(title: L("Донатів ще немає").s).listRowBackground(Color.clear) }
            }
            if !items.isEmpty {
                Section(L("Історія").s) {
                    ForEach(items) { d in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.fundName)
                                Text([BankText.date(d.createdAt), d.comment].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Format.money(d.amount)).fontWeight(.semibold).monospacedDigit()
                        }
                    }
                }
            }
        }
        .labForm()
        .navigationTitle(L("Донати").s)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button(L("Задонатити").s, systemImage: "plus") { giving = true } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $giving) { DonateView { await load() } }
    }

    private func load() async {
        items = ((try? await model.api.donations()) ?? []).sorted { $0.id > $1.id }
        loaded = true
    }
}

struct DonateView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var fund = DonateView.funds[0]
    @State private var amount: Double? = 200
    @State private var comment = ""
    @State private var screen = Screen()

    static var funds: [String] { [L("Повернись живим").s, L("Фонд Сергія Притули").s, "United24", L("Госпітальєри").s, L("Інший напрям").s] }

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    Picker(L("Фонд").s, selection: $fund) { ForEach(Self.funds, id: \.self, content: Text.init) }
                    TextField(L("Сума, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField(L("Коментар").s, text: $comment)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Задонатити").s, disabled: (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.donate(fund: fund, amount: amount ?? 0, comment: comment) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Донат").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Виплати

struct PayoutsView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Payout] = []
    @State private var accruing = false
    @State private var loaded = false

    static var types: [(String, String)] { [("salary", L("Грошове забезпечення").s), ("bonus", L("Премія").s), ("compensation", L("Компенсація").s), ("general", L("Інша виплата").s)] }

    var body: some View {
        LabForm {
            if loaded && items.isEmpty {
                Section { BrandEmpty(title: L("Виплат ще немає").s).listRowBackground(Color.clear) }
            }
            ForEach(items) { p in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.title)
                        Text(BankText.date(p.createdAt)).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("+" + Format.money(p.amount)).fontWeight(.semibold).monospacedDigit()
                }
            }
        }
        .labForm()
        .navigationTitle(L("Виплати").s)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button(L("Нарахувати").s, systemImage: "plus") { accruing = true } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $accruing) { AccrueView { await load() } }
    }

    private func load() async {
        items = ((try? await model.api.payouts()) ?? []).sorted { $0.id > $1.id }
        loaded = true
    }
}

struct AccrueView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var type = "salary"
    @State private var amount: Double? = 20000
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    Picker(L("Вид").s, selection: $type) { ForEach(PayoutsView.types, id: \.0) { Text($0.1).tag($0.0) } }
                    TextField(L("Сума, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Нарахувати").s, disabled: (amount ?? 0) <= 0 || screen.busy) {
                    let title = PayoutsView.types.first { $0.0 == type }?.1 ?? L("Виплата").s
                    Task {
                        if await screen.run({ try await model.api.accruePayout(title: title, amount: amount ?? 0, type: type) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Нова виплата").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: Борги

struct DebtsView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Debt] = []
    @State private var adding = false
    @State private var screen = Screen()
    @State private var loaded = false

    private var open: [API.Debt] { items.filter { !$0.isSettled } }
    private var toMe: [API.Debt] { open.filter(\.owedToMe) }
    private var mine: [API.Debt] { open.filter { !$0.owedToMe } }

    var body: some View {
        LabForm {
            Section {
                HStack(spacing: 0) {
                    figure(L("Мені винні").s, toMe.reduce(0) { $0 + $1.amount })
                    Rectangle().fill(Theme.line).frame(width: Theme.hairline)
                    figure(L("Я винен").s, mine.reduce(0) { $0 + $1.amount })
                }
                .listRowInsets(EdgeInsets())
            }
            if loaded && open.isEmpty {
                Section { BrandEmpty(title: L("Відкритих боргів немає").s).listRowBackground(Color.clear) }
            }
            group(L("Мені винні").s, toMe)
            group(L("Я винен").s, mine)
            let closed = items.filter(\.isSettled)
            if !closed.isEmpty {
                Section(L("Закриті").s) {
                    ForEach(closed) { d in
                        Line(d.contactName, Format.money(d.amount)).foregroundStyle(.secondary)
                    }
                    .onDelete { i in remove(i.map { closed[$0] }) }
                }
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle(L("Борги").s)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button(L("Новий борг").s, systemImage: "plus") { adding = true } }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $adding) { NewDebtView { await load() } }
    }

    private func figure(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).caption()
            Text(Format.money(value)).font(.title3.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    @ViewBuilder private func group(_ title: String, _ list: [API.Debt]) -> some View {
        if !list.isEmpty {
            Section(title) {
                ForEach(list) { d in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(d.contactName)
                                if let n = d.description, !n.isEmpty { Text(n).font(.footnote).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Text(Format.money(d.amount)).fontWeight(.semibold).monospacedDigit()
                        }
                        Button(L("Позначити повернутим").s) {
                            Task {
                                await screen.run { try await model.api.settleDebt(d.id) }
                                await load()
                            }
                        }
                        .font(.footnote.weight(.medium))
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { i in remove(i.map { list[$0] }) }
            }
        }
    }

    private func remove(_ list: [API.Debt]) {
        Task {
            for d in list { await screen.run { try await model.api.deleteDebt(d.id) } }
            await load()
        }
    }

    private func load() async {
        items = ((try? await model.api.debts()) ?? []).sorted { $0.id > $1.id }
        loaded = true
    }
}

struct NewDebtView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var owedToMe = true
    @State private var name = ""
    @State private var amount: Double?
    @State private var note = ""
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    Picker(L("Хто кому").s, selection: $owedToMe) {
                        Text(L("Мені винні").s).tag(true)
                        Text(L("Я винен").s).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    TextField(L("Ім'я").s, text: $name)
                    TextField(L("Сума, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField(L("За що").s, text: $note)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Додати").s, disabled: name.isEmpty || (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.addDebt(name: name, amount: amount ?? 0, owedToMe: owedToMe, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Новий борг").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Сповіщення

struct NoticesView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Notice] = []
    @State private var loaded = false

    var body: some View {
        LabForm {
            if loaded && items.isEmpty {
                Section { BrandEmpty(title: L("Сповіщень немає").s).listRowBackground(Color.clear) }
            }
            ForEach(items) { n in
                VStack(alignment: .leading, spacing: 3) {
                    Text(n.title).fontWeight(n.isRead ? .regular : .semibold)
                    if let b = n.body, !b.isEmpty { Text(b).font(.footnote).foregroundStyle(.secondary) }
                    Text(BankText.date(n.createdAt)).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
        .labForm()
        .navigationTitle(L("Сповіщення").s)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            items = (try? await model.api.notices()) ?? []
            loaded = true
            try? await model.api.readAll()
        }
    }
}

// MARK: Виписки

struct StatementsView: View {
    @Environment(AppModel.self) private var model
    @State private var period = Period.month
    @State private var from = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var to = Date.now
    @State private var preview: URL?
    @State private var screen = Screen()
    @State private var all: [API.Transaction] = []

    enum Period: Hashable { case month, previous, quarter, year, custom }

    /// Операції вибраного періоду: від початку першого дня до кінця останнього.
    private var inRange: [API.Transaction] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: from)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: to)) ?? to
        return all.filter { $0.date >= start && $0.date < end }
    }

    private var range: String { "from_date=\(BankText.isoDay(from))&to_date=\(BankText.isoDay(to))" }
    private var title: String { "\(BankText.date(BankText.isoDay(from))) - \(BankText.date(BankText.isoDay(to)))" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SegmentBar(items: [(Period.month, L("Цей місяць").s), (.previous, L("Минулий").s), (.quarter, L("3 місяці").s),
                                   (.year, L("Рік").s), (.custom, L("Свій період").s)], selection: $period)
                if period == .custom {
                    Surface {
                        DatePicker(L("З").s, selection: $from, in: ...to, displayedComponents: .date).padding(14)
                        Rule()
                        DatePicker(L("По").s, selection: $to, in: from...Date.now, displayedComponents: .date).padding(14)
                    }
                }
                let rows = inRange
                let income = rows.filter(\.isIncome).reduce(0) { $0 + $1.amount }
                let spent = rows.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
                HeroPanel {
                    Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                    Text(L("Витрачено").s).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 14)
                    Text(Format.short(spent))
                        .font(.system(size: 44, weight: .semibold)).monospacedDigit()
                        .minimumScaleFactor(0.5).lineLimit(1).frame(maxWidth: .infinity)
                    Rule().padding(.horizontal, -16).padding(.top, 14)
                    HStack(alignment: .top, spacing: 12) {
                        summary(L("Надійшло").s, Format.short(income), tint: .green)
                        summary(L("Операцій").s, "\(rows.count)")
                        summary(L("Різниця").s, (income - spent >= 0 ? "+" : "−") + Format.short(abs(income - spent)))
                    }
                    .padding(.top, 6)
                }
                if !rows.isEmpty {
                    BlockTitle(L("Операції періоду").s, trailing: "\(rows.count)")
                    Surface {
                        ForEach(Array(rows.prefix(8).enumerated()), id: \.element.id) { i, tx in
                            if i > 0 { Rule() }
                            ActivityRow(tx: tx)
                        }
                    }
                    if rows.count > 8 {
                        Text(L("і ще \(rows.count - 8) у виписці").s)
                            .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                VStack(spacing: 10) {
                    Button { open("transactions/statement?\(range)", L("Виписка \(BankText.isoDay(from)) - \(BankText.isoDay(to)).pdf").s) } label: {
                        Label(L("Виписка PDF").s, systemImage: "doc.richtext")
                    }
                    .buttonStyle(InkButton())
                    Button { open("transactions/export?\(range)", L("Операції \(BankText.isoDay(from)) - \(BankText.isoDay(to)).csv").s) } label: {
                        Label(L("Таблиця операцій").s, systemImage: "tablecells")
                    }
                    .buttonStyle(LineButton())
                    NavigationLink { DocumentsView() } label: {
                        Label(L("Мої документи і QR-коди").s, systemImage: "qrcode")
                    }
                    .buttonStyle(LineButton())
                }
                .disabled(screen.busy)
                if screen.busy { ProgressView().frame(maxWidth: .infinity) }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle(L("Виписки").s)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: period) { apply() }
        .task { all = (try? await model.api.history(.init())) ?? [] }
        .quickLookPreview($preview)
    }

    private func summary(_ title: String, _ value: String, tint: Color = Theme.ink) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(tint)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func apply() {
        let cal = Calendar.current, now = Date.now
        switch period {
        case .month: from = cal.dateInterval(of: .month, for: now)?.start ?? now; to = now
        case .previous:
            let prev = cal.date(byAdding: .month, value: -1, to: now) ?? now
            let m = cal.dateInterval(of: .month, for: prev)
            from = m?.start ?? now
            to = m.map { $0.end.addingTimeInterval(-1) } ?? now
        case .quarter: from = cal.date(byAdding: .month, value: -3, to: now) ?? now; to = now
        case .year: from = cal.dateInterval(of: .year, for: now)?.start ?? now; to = now
        case .custom: break
        }
    }

    private func open(_ path: String, _ name: String) {
        Task { await screen.run { preview = try await model.api.document(path, name: name) } }
    }
}

// MARK: Профіль і безпека

struct SecurityView: View {
    @Environment(AppModel.self) private var model
    @State private var me: API.Me?
    @State private var hasPin = false
    @State private var sessions: [API.Device] = []
    @State private var settingPin = false
    @State private var changingPassword = false
    @State private var screen = Screen()

    private var bioAvailable: Bool { Biometrics.kind != .none }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if let me {
                    Surface {
                        VStack(spacing: 0) {
                            Line2(L("Ім'я").s, me.fullName)
                            if let e = me.email, !e.isEmpty { Rule(); Line2(L("Пошта").s, e) }
                            if let p = me.phone, !p.isEmpty, !p.hasPrefix("apple:") { Rule(); Line2(L("Телефон").s, p) }
                            if let a = me.bankAccountNumber { Rule(); Line2(L("Рахунок").s, a) }
                        }
                    }
                }

                section(L("Вхід у банк").s, footer: hasPin
                        ? L("PIN питаємо щоразу, коли застосунок повертається з фону.").s
                        : L("Без PIN банк відкривається одразу після запуску.").s) {
                    actionRow(L("PIN-код").s, value: hasPin ? L("Увімкнено").s : L("Вимкнено").s, action: hasPin ? L("Змінити").s : L("Встановити").s) { settingPin = true }
                    if bioAvailable {
                        Rule()
                        Toggle(isOn: Binding(get: { model.biometricsEnabled && hasPin }, set: { on in Task { await setBiometrics(on) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Biometrics.title)
                                Text(hasPin ? L("Замість PIN на замку").s : L("Спершу встановіть PIN").s).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .tint(Theme.ink)
                        .disabled(!hasPin)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    if hasPin {
                        Rule()
                        Button {
                            Task {
                                if await screen.run({ try await model.api.clearPin() }) { model.biometricsEnabled = false }
                                await load()
                            }
                        } label: {
                            Text(L("Прибрати PIN").s).frame(maxWidth: .infinity, alignment: .leading).padding(16).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }

                section(L("Пароль").s, footer: L("Після зміни пароля інші пристрої лишаються в акаунті; завершіть їхні сесії нижче, якщо треба.").s) {
                    Button { changingPassword = true } label: {
                        HStack {
                            Text(L("Змінити пароль").s)
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(16).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }

                section(L("Пристрої в акаунті").s, footer: nil) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Rule() }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(device(s)).fontWeight(.semibold)
                                    if s.isCurrent {
                                        Text(L("цей").s).font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Theme.ink.opacity(0.1), in: .capsule)
                                    }
                                }
                                Text([s.lastSeenAt.map(BankText.date), s.ipAddress].compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !s.isCurrent {
                                Button(L("Завершити").s) {
                                    Task {
                                        await screen.run { try await model.api.endSession(s.id) }
                                        await load()
                                    }
                                }
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 12).frame(height: 32)
                                .overlay(Capsule().stroke(Theme.ink.opacity(0.16), lineWidth: 1))
                                .foregroundStyle(Theme.ink)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                if sessions.count > 1 {
                    Button(L("Вийти на всіх інших пристроях").s) {
                        Task {
                            await screen.run { try await model.api.endOtherSessions() }
                            await load()
                        }
                    }
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(Capsule().stroke(Theme.ink.opacity(0.16), lineWidth: 1))
                    .foregroundStyle(Theme.ink)
                    .buttonStyle(PressScale())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .navigationTitle(L("Безпека").s)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $settingPin) { NewPinView { await load() } }
        .sheet(isPresented: $changingPassword) { PasswordView() }
    }

    private func section<C: View>(_ title: String, footer: String?, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.bold))
            Surface { VStack(spacing: 0) { content() } }
            if let footer { Text(footer).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4) }
        }
    }

    private func actionRow(_ title: String, value: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(value).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action, action: perform)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 14).frame(height: 32)
                .overlay(Capsule().stroke(Theme.ink.opacity(0.16), lineWidth: 1))
                .foregroundStyle(Theme.ink)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    /// Вмикаємо лише після успішної перевірки обличчя: так людина бачить, що біометрія справді працює.
    private func setBiometrics(_ on: Bool) async {
        guard on else { model.biometricsEnabled = false; return }
        model.biometricsEnabled = await Biometrics.unlock(reason: L("Увімкнути \(Biometrics.title) для TaxTech").s)
    }

    private func device(_ s: API.Device) -> String {
        let ua = s.userAgent ?? ""
        if s.authMethod == "apple" { return L("Вхід через Apple").s }
        if ua.contains("iPhone") || ua.contains("CFNetwork") || ua.contains("TaxTech") || ua.contains("Kopiyka") { return "iPhone" }
        if ua.contains("Mac") { return "Mac" }
        if ua.contains("curl") { return L("Командний рядок").s }
        return ua.isEmpty ? L("Пристрій").s : String(ua.prefix(32))
    }

    private func load() async {
        async let m = model.api.me()
        async let p = model.api.hasPin()
        async let s = model.api.sessions()
        me = try? await m
        hasPin = (try? await p) ?? false
        sessions = (try? await s) ?? []
    }
}

struct NewPinView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var first: String?
    @State private var error: String?
    @State private var mismatches = 0

    var body: some View {
        PinPad(title: first == nil ? L("Новий PIN").s : L("Повторіть PIN").s, error: error, shake: mismatches) { pin in
            guard let f = first else { first = pin; error = nil; return true }
            guard f == pin else { first = nil; error = L("Коди не збіглися. Ще раз.").s; mismatches += 1; return true }
            do {
                try await model.api.setPin(pin)
                model.bankUnlocked = true
                await done()
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            return true
        }
        .presentationDetents([.large])
    }
}

struct PasswordView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var old = ""
    @State private var new = ""
    @State private var done = false
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(done ? L("Пароль змінено").s : L("Новий пароль").s).font(.display(30)).tracking(-0.8)
                    if done {
                        Text(L("Наступного разу входьте з новим паролем. Інші пристрої можна вивести з акаунта на екрані «Безпека».").s)
                            .foregroundStyle(.secondary)
                        Button(L("Готово").s) { dismiss() }.buttonStyle(InkButton())
                    } else {
                        AuthField(title: L("Поточний пароль").s, placeholder: L("Пароль").s, text: $old, secure: true, content: .password)
                        VStack(alignment: .leading, spacing: 10) {
                            AuthField(title: L("Новий пароль").s, placeholder: L("Щонайменше 8 символів").s, text: $new,
                                      secure: true, content: .newPassword, submit: .done)
                            if !new.isEmpty { PasswordStrength(password: new) }
                            if !new.isEmpty && new == old {
                                Text(L("Новий пароль збігається з поточним").s).font(.footnote).foregroundStyle(Theme.ink.opacity(0.75))
                            }
                        }
                        if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                        Button(L("Змінити пароль").s) {
                            Task { if await screen.run({ try await model.api.changePassword(old: old, new: new) }) { done = true } }
                        }
                        .buttonStyle(InkButton())
                        .disabled(old.isEmpty || new.count < 8 || new == old || screen.busy)
                    }
                }
                .padding(24)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(done ? L("Закрити").s : L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

// MARK: Замок PIN

/// Банк закритий кодом: чотири цифри, перевіряє сервер.
struct PinLockView: View {
    @Environment(AppModel.self) private var model
    @State private var error: String?
    @State private var asked = false
    @State private var failures = 0

    private var biometrics: Bool { model.biometricsEnabled && Biometrics.kind != .none }

    var body: some View {
        PinPad(title: L("Введіть PIN").s, error: error, footer: L("Вийти").s, shake: failures, submit: { pin in
            do {
                try await model.api.verifyPin(pin)
                model.bankUnlocked = true
            } catch {
                self.error = L("Невірний PIN").s
                failures += 1
            }
            return true
        }, onFooter: {
            model.signOut()
        }, biometric: biometrics ? { Task { await unlock() } } : nil)
        .task {
            // одразу пропонуємо обличчя; скасував - лишається PIN
            guard biometrics, !asked else { return }
            asked = true
            await unlock()
        }
    }

    private func unlock() async {
        if await Biometrics.unlock(reason: L("Відкрити банк TaxTech").s) { model.bankUnlocked = true }
    }
}

/// Плоска клавіатура на чотири цифри: чотири риски над великими цифрами.
struct PinPad: View {
    let title: String
    var error: String?
    var footer: String?
    /// Зростає з кожною невдалою спробою: риски трусяться, телефон вібрує.
    var shake = 0
    /// Повертає true, коли введене треба стерти.
    let submit: (String) async -> Bool
    var onFooter: (() -> Void)?
    /// Face ID / Touch ID у лівому нижньому куті клавіатури.
    var biometric: (() -> Void)?
    @State private var pin = ""
    @State private var busy = false
    @State private var shakeAmount = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            MarkView(height: 40)
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.4)
                .padding(.top, 20)
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i < pin.count ? Theme.ink : Theme.line)
                        .frame(width: 36, height: i < pin.count ? 6 : 3)
                        .scaleEffect(i == pin.count - 1 ? 1.12 : 1)
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: pin.count)
            .modifier(Shake(animatableData: CGFloat(shakeAmount)))
            .padding(.top, 28)
            Text(error ?? " ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 14)
            Spacer(minLength: 24)
            let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
            VStack(spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button { if key.isEmpty { biometric?() } else { tap(key) } } label: {
                                Group {
                                    if key == "⌫" { Image(systemName: "delete.left") }
                                    else if key.isEmpty && biometric != nil { Image(systemName: Biometrics.symbol) }
                                    else { Text(key) }
                                }
                                .font(.system(size: 30, weight: .regular))
                                .frame(maxWidth: .infinity, minHeight: 68)
                                .foregroundStyle(Theme.ink)
                                .background(key.isEmpty ? Color.clear : Theme.surface,
                                            in: .rect(cornerRadius: Theme.corner, style: .continuous))
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .disabled((key.isEmpty && biometric == nil) || busy)
                            .accessibilityLabel(key == "⌫" ? L("Стерти").s : key.isEmpty && biometric != nil ? Biometrics.title : key)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            if let footer, let onFooter {
                Button(footer, action: onFooter)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)
            }
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .sensoryFeedback(.selection, trigger: pin.count)
        .sensoryFeedback(.error, trigger: shake)
        .onChange(of: shake) { withAnimation(.linear(duration: 0.45)) { shakeAmount += 1 } }
    }

    private func tap(_ key: String) {
        if key == "⌫" {
            if !pin.isEmpty { pin.removeLast() }
            return
        }
        guard pin.count < 4 else { return }
        pin += key
        guard pin.count == 4 else { return }
        busy = true
        let entered = pin
        Task {
            if await submit(entered) { pin = "" }
            busy = false
        }
    }
}
