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
                    Text("Усього задоначено").caption()
                    Text(Format.money(total)).font(Theme.balance(40)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }
            if loaded && items.isEmpty {
                Section { BrandEmpty(title: "Донатів ще немає").listRowBackground(Color.clear) }
            }
            if !items.isEmpty {
                Section("Історія") {
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
        .navigationTitle("Донати")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Задонатити", systemImage: "plus") { giving = true } }
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

    static let funds = ["Повернись живим", "Фонд Сергія Притули", "United24", "Госпітальєри", "Інший напрям"]

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    Picker("Фонд", selection: $fund) { ForEach(Self.funds, id: \.self, content: Text.init) }
                    TextField("Сума, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField("Коментар", text: $comment)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Задонатити", disabled: (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.donate(fund: fund, amount: amount ?? 0, comment: comment) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Донат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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

    static let types = [("salary", "Грошове забезпечення"), ("bonus", "Премія"), ("compensation", "Компенсація"), ("general", "Інша виплата")]

    var body: some View {
        LabForm {
            if loaded && items.isEmpty {
                Section { BrandEmpty(title: "Виплат ще немає").listRowBackground(Color.clear) }
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
        .navigationTitle("Виплати")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Нарахувати", systemImage: "plus") { accruing = true } }
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
                    Picker("Вид", selection: $type) { ForEach(PayoutsView.types, id: \.0) { Text($0.1).tag($0.0) } }
                    TextField("Сума, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Нарахувати", disabled: (amount ?? 0) <= 0 || screen.busy) {
                    let title = PayoutsView.types.first { $0.0 == type }?.1 ?? "Виплата"
                    Task {
                        if await screen.run({ try await model.api.accruePayout(title: title, amount: amount ?? 0, type: type) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Нова виплата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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
                    figure("Мені винні", toMe.reduce(0) { $0 + $1.amount })
                    Rectangle().fill(Theme.line).frame(width: Theme.hairline)
                    figure("Я винен", mine.reduce(0) { $0 + $1.amount })
                }
                .listRowInsets(EdgeInsets())
            }
            if loaded && open.isEmpty {
                Section { BrandEmpty(title: "Відкритих боргів немає").listRowBackground(Color.clear) }
            }
            group("Мені винні", toMe)
            group("Я винен", mine)
            let closed = items.filter(\.isSettled)
            if !closed.isEmpty {
                Section("Закриті") {
                    ForEach(closed) { d in
                        Line(d.contactName, Format.money(d.amount)).foregroundStyle(.secondary)
                    }
                    .onDelete { i in remove(i.map { closed[$0] }) }
                }
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle("Борги")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Новий борг", systemImage: "plus") { adding = true } }
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
                        Button("Позначити повернутим") {
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
                    Picker("Хто кому", selection: $owedToMe) {
                        Text("Мені винні").tag(true)
                        Text("Я винен").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    TextField("Ім'я", text: $name)
                    TextField("Сума, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField("За що", text: $note)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Додати", disabled: name.isEmpty || (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.addDebt(name: name, amount: amount ?? 0, owedToMe: owedToMe, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Новий борг")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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
                Section { BrandEmpty(title: "Сповіщень немає").listRowBackground(Color.clear) }
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
        .navigationTitle("Сповіщення")
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

    enum Period: Hashable { case month, previous, quarter, year, custom }

    private var range: String { "from_date=\(BankText.isoDay(from))&to_date=\(BankText.isoDay(to))" }
    private var title: String { "\(BankText.date(BankText.isoDay(from))) - \(BankText.date(BankText.isoDay(to)))" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SegmentBar(items: [(Period.month, "Цей місяць"), (.previous, "Минулий"), (.quarter, "3 місяці"),
                                   (.year, "Рік"), (.custom, "Свій період")], selection: $period)
                if period == .custom {
                    Surface {
                        DatePicker("З", selection: $from, in: ...to, displayedComponents: .date).padding(14)
                        Rule()
                        DatePicker("По", selection: $to, in: from...Date.now, displayedComponents: .date).padding(14)
                    }
                }
                HeroPanel {
                    HeroCaption("Виписка за період")
                    Text(title).font(.title3.weight(.semibold)).padding(.top, 6)
                }
                VStack(spacing: 10) {
                    Button { open("transactions/statement?\(range)", "Виписка \(BankText.isoDay(from)) - \(BankText.isoDay(to)).pdf") } label: {
                        Label("Переглянути виписку", systemImage: "doc.richtext")
                    }
                    .buttonStyle(InkButton())
                    Button { open("transactions/export?\(range)", "Операції \(BankText.isoDay(from)) - \(BankText.isoDay(to)).csv") } label: {
                        Label("Таблиця операцій", systemImage: "tablecells")
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
        .navigationTitle("Виписки")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: period) { apply() }
        .quickLookPreview($preview)
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
                            Line2("Ім'я", me.fullName)
                            if let e = me.email, !e.isEmpty { Rule(); Line2("Пошта", e) }
                            if let p = me.phone, !p.isEmpty, !p.hasPrefix("apple:") { Rule(); Line2("Телефон", p) }
                            if let a = me.bankAccountNumber { Rule(); Line2("Рахунок", a) }
                        }
                    }
                }

                section("Вхід у банк", footer: hasPin
                        ? "PIN питаємо щоразу, коли застосунок повертається з фону."
                        : "Без PIN банк відкривається одразу після запуску.") {
                    actionRow("PIN-код", value: hasPin ? "Увімкнено" : "Вимкнено", action: hasPin ? "Змінити" : "Встановити") { settingPin = true }
                    if bioAvailable {
                        Rule()
                        Toggle(isOn: Binding(get: { model.biometricsEnabled && hasPin }, set: { on in Task { await setBiometrics(on) } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Biometrics.title)
                                Text(hasPin ? "Замість PIN на замку" : "Спершу встановіть PIN").font(.footnote).foregroundStyle(.secondary)
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
                            Text("Прибрати PIN").frame(maxWidth: .infinity, alignment: .leading).padding(16).contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }

                section("Пароль", footer: "Після зміни пароля інші пристрої лишаються в акаунті; завершіть їхні сесії нижче, якщо треба.") {
                    Button { changingPassword = true } label: {
                        HStack {
                            Text("Змінити пароль")
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(16).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }

                section("Пристрої в акаунті", footer: nil) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Rule() }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(device(s)).fontWeight(.semibold)
                                    if s.isCurrent {
                                        Text("цей").font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8).padding(.vertical, 2)
                                            .background(Theme.ink.opacity(0.1), in: .capsule)
                                    }
                                }
                                Text([s.lastSeenAt.map(BankText.date), s.ipAddress].compactMap { $0 }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !s.isCurrent {
                                Button("Завершити") {
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
                    Button("Вийти на всіх інших пристроях") {
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
        .navigationTitle("Безпека")
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
        model.biometricsEnabled = await Biometrics.unlock(reason: "Увімкнути \(Biometrics.title) для TaxTech")
    }

    private func device(_ s: API.Device) -> String {
        let ua = s.userAgent ?? ""
        if s.authMethod == "apple" { return "Вхід через Apple" }
        if ua.contains("iPhone") || ua.contains("CFNetwork") || ua.contains("TaxTech") || ua.contains("Kopiyka") { return "iPhone" }
        if ua.contains("Mac") { return "Mac" }
        if ua.contains("curl") { return "Командний рядок" }
        return ua.isEmpty ? "Пристрій" : String(ua.prefix(32))
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
        PinPad(title: first == nil ? "Новий PIN" : "Повторіть PIN", error: error, shake: mismatches) { pin in
            guard let f = first else { first = pin; error = nil; return true }
            guard f == pin else { first = nil; error = "Коди не збіглися. Ще раз."; mismatches += 1; return true }
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
                    Text(done ? "Пароль змінено" : "Новий пароль").font(.system(size: 30, weight: .bold)).tracking(-0.6)
                    if done {
                        Text("Наступного разу входьте з новим паролем. Інші пристрої можна вивести з акаунта на екрані «Безпека».")
                            .foregroundStyle(.secondary)
                        Button("Готово") { dismiss() }.buttonStyle(InkButton())
                    } else {
                        AuthField(title: "Поточний пароль", placeholder: "Пароль", text: $old, secure: true, content: .password)
                        VStack(alignment: .leading, spacing: 10) {
                            AuthField(title: "Новий пароль", placeholder: "Щонайменше 8 символів", text: $new,
                                      secure: true, content: .newPassword, submit: .done)
                            if !new.isEmpty { PasswordStrength(password: new) }
                            if !new.isEmpty && new == old {
                                Text("Новий пароль збігається з поточним").font(.footnote).foregroundStyle(Theme.ink.opacity(0.75))
                            }
                        }
                        if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                        Button("Змінити пароль") {
                            Task { if await screen.run({ try await model.api.changePassword(old: old, new: new) }) { done = true } }
                        }
                        .buttonStyle(InkButton())
                        .disabled(old.isEmpty || new.count < 8 || new == old || screen.busy)
                    }
                }
                .padding(24)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(done ? "Закрити" : "Скасувати") { dismiss() } } }
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
        PinPad(title: "Введіть PIN", error: error, footer: "Вийти", shake: failures, submit: { pin in
            do {
                try await model.api.verifyPin(pin)
                model.bankUnlocked = true
            } catch {
                self.error = "Невірний PIN"
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
        if await Biometrics.unlock(reason: "Відкрити банк TaxTech") { model.bankUnlocked = true }
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
                            .accessibilityLabel(key == "⌫" ? "Стерти" : key.isEmpty && biometric != nil ? Biometrics.title : key)
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
