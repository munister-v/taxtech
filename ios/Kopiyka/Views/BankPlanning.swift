import SwiftUI

// MARK: Цілі накопичень

struct GoalsView: View {
    @Environment(AppModel.self) private var model
    @State private var items: [API.Goal] = []
    @State private var adding = false
    @State private var funding: API.Goal?
    @State private var screen = Screen()
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if loaded && items.isEmpty {
                    BrandEmpty(title: L("Цілей ще немає").s, action: L("Поставити ціль").s) { adding = true }
                } else if !items.isEmpty {
                    let saved = items.reduce(0) { $0 + $1.currentAmount }, target = items.reduce(0) { $0 + $1.targetAmount }
                    HeroPanel {
                        HeroCaption(L("Відкладено").s)
                        BigAmount(value: saved, size: 40).padding(.top, 6)
                        Text(L("з \(Format.money(target))").s).font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(items) { g in tile(g) }
                    }
                    Button(L("Нова ціль").s) { adding = true }.buttonStyle(LineButton())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle(L("Цілі").s)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $adding) { NewGoalView { await load() } }
        .sheet(item: $funding) { g in
            AmountSheet(title: g.title, action: L("Відкласти").s, amount: 500) { a in
                try await model.api.contribute(g.id, a)
                await load()
            }
        }
    }

    /// Ціль: кільце прогресу з відсотком, назва, скільки відкладено, дії.
    private func tile(_ g: API.Goal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 7)
                Circle().trim(from: 0, to: g.progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(g.progress * 100))%").font(.subheadline.weight(.bold)).monospacedDigit()
            }
            .frame(width: 64, height: 64)
            Text(g.title).font(.headline).lineLimit(2, reservesSpace: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.money(g.currentAmount)).font(.subheadline.weight(.bold)).monospacedDigit()
                Text(L("з \(Format.money(g.targetAmount))").s).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if let d = g.deadline, !d.isEmpty { Text(L("до \(BankText.date(d))").s).font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Button { funding = g } label: {
                    Image(systemName: "plus").font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Theme.accent, in: .circle)
                        .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(L("Відкласти").s)
                Spacer()
                Menu {
                    Button(L("Видалити ціль").s, role: .destructive) {
                        Task {
                            await screen.run { try await model.api.deleteGoal(g.id) }
                            await load()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis").font(.subheadline.weight(.bold)).frame(width: 36, height: 36)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func load() async {
        items = (try? await model.api.goals()) ?? []
        loaded = true
    }
}

struct NewGoalView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var title = ""
    @State private var target: Double?
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField(L("Назва").s, text: $title)
                    TextField(L("Скільки потрібно, TAX").s, value: $target, format: .number).keyboardType(.decimalPad)
                    Toggle(L("Є строк").s, isOn: $hasDeadline)
                        .tint(Theme.ink.opacity(0.6))
                    if hasDeadline { DatePicker(L("До").s, selection: $deadline, in: Date.now..., displayedComponents: .date) }
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Створити ціль").s, disabled: title.isEmpty || (target ?? 0) <= 0 || screen.busy) {
                    Task {
                        let day = hasDeadline ? BankText.isoDay(deadline) : nil
                        if await screen.run({ try await model.api.addGoal(title: title, target: target ?? 0, deadline: day) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Нова ціль").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Контакти й шаблони

struct ContactsView: View {
    @Environment(AppModel.self) private var model
    @State private var contacts: [API.Contact] = []
    @State private var templates: [API.Template] = []
    @State private var addingContact = false
    @State private var addingTemplate = false
    @State private var screen = Screen()
    @State private var loaded = false

    var body: some View {
        LabForm {
            Section(L("Контакти").s) {
                if loaded && contacts.isEmpty { Text(L("Контактів немає").s).foregroundStyle(.secondary) }
                ForEach(contacts) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.contactName)
                        Text([c.accountNumber, c.phone].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(L("Видалити").s, role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteContact(c.id) }
                                await load()
                            }
                        }
                    }
                }
                Button(L("Додати контакт").s) { addingContact = true }
            }
            Section {
                if loaded && templates.isEmpty { Text(L("Шаблонів немає").s).foregroundStyle(.secondary) }
                ForEach(templates) { t in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(t.name)
                            Spacer()
                            if let a = t.amount { Text(Format.money(a)).monospacedDigit() }
                        }
                        Text(t.recipientAccount ?? "").font(.footnote).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(L("Видалити").s, role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteTemplate(t.id) }
                                await load()
                            }
                        }
                    }
                }
                Button(L("Додати шаблон").s) { addingTemplate = true }
            } header: {
                Text(L("Шаблони платежів").s)
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle(L("Контакти").s)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $addingContact) { NewContactView { await load() } }
        .sheet(isPresented: $addingTemplate) { NewTemplateView { await load() } }
    }

    private func load() async {
        contacts = (try? await model.api.contacts()) ?? []
        templates = (try? await model.api.templates()) ?? []
        loaded = true
    }
}

struct NewContactView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var name = ""
    @State private var relation = "friend"
    @State private var account = ""
    @State private var phone = ""
    @State private var screen = Screen()

    static var relations: [(String, String)] { [("family", L("Родина").s), ("friend", L("Друг").s), ("work", L("Робота").s), ("other", "Інше")] }

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField(L("Ім'я").s, text: $name)
                    Picker(L("Хто це").s, selection: $relation) {
                        ForEach(Self.relations, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    TextField(L("Рахунок, KP-…").s, text: $account)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(L("Телефон").s, text: $phone).keyboardType(.phonePad)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Зберегти").s, disabled: name.isEmpty || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.addContact(name: name, relation: relation, account: account, phone: phone) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Новий контакт").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct NewTemplateView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var name = ""
    @State private var recipient = ""
    @State private var amount: Double?
    @State private var note = ""
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField(L("Назва").s, text: $name)
                    TextField(L("Рахунок одержувача, KP-…").s, text: $recipient)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(L("Сума, TAX (необов'язково)").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField(L("Призначення").s, text: $note)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Зберегти").s, disabled: name.isEmpty || recipient.isEmpty || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.addTemplate(name: name, recipient: recipient, amount: amount, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Новий шаблон").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Ліміти й регулярні платежі

struct LimitsView: View {
    @Environment(AppModel.self) private var model
    @State private var limits: [API.BudgetLimit] = []
    @State private var recurring: [API.Recurring] = []
    @State private var addingLimit = false
    @State private var addingRecurring = false
    @State private var screen = Screen()
    @State private var loaded = false

    var body: some View {
        LabForm {
            Section {
                if loaded && limits.isEmpty { Text(L("Лімітів немає").s).foregroundStyle(.secondary) }
                ForEach(limits) { l in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(BankText.type(l.txType))
                            Spacer()
                            Text(L("\(Format.money(l.spent ?? 0)) з \(Format.money(l.monthlyLimit))").s)
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                        }
                        Meter(value: (l.pct ?? 0) / 100)
                    }
                    .swipeActions {
                        Button(L("Видалити").s, role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteLimit(l.txType) }
                                await load()
                            }
                        }
                    }
                }
                Button(L("Поставити ліміт").s) { addingLimit = true }
            } header: {
                Text(L("Місячні ліміти").s)
            } footer: {
                Text(L("Скільки можна витратити за місяць за видом операцій.").s)
            }
            Section(L("Регулярні платежі").s) {
                if loaded && recurring.isEmpty { Text(L("Регулярних платежів немає").s).foregroundStyle(.secondary) }
                ForEach(recurring) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.title)
                            Text(L("\(BankText.frequency(r.frequency)), далі \(BankText.date(r.nextRunDate))").s)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Format.money(r.amount)).monospacedDigit()
                        Toggle(L("Активний").s, isOn: .init(get: { r.isActive != 0 }, set: { _ in
                            Task {
                                await screen.run { try await model.api.toggleRecurring(r.id) }
                                await load()
                            }
                        }))
                        .labelsHidden()
                        .tint(Theme.ink.opacity(0.6))
                    }
                    .swipeActions {
                        Button(L("Видалити").s, role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteRecurring(r.id) }
                                await load()
                            }
                        }
                    }
                }
                Button(L("Новий регулярний платіж").s) { addingRecurring = true }
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle(L("Ліміти й платежі").s)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $addingLimit) { NewLimitView { await load() } }
        .sheet(isPresented: $addingRecurring) { NewRecurringView { await load() } }
    }

    private func load() async {
        limits = (try? await model.api.limits()) ?? []
        recurring = (try? await model.api.recurring()) ?? []
        loaded = true
    }
}

struct NewLimitView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var type = "payment"
    @State private var amount: Double?
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    Picker(L("Вид операцій").s, selection: $type) {
                        ForEach(["payment", "transfer", "donation"], id: \.self) { Text(BankText.type($0)).tag($0) }
                    }
                    TextField(L("Ліміт на місяць, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Поставити ліміт").s, disabled: (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.setLimit(txType: type, amount: amount ?? 0) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Новий ліміт").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

struct NewRecurringView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var title = ""
    @State private var recipient = ""
    @State private var amount: Double?
    @State private var frequency = "monthly"
    @State private var first = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField(L("Назва").s, text: $title)
                    TextField(L("Рахунок одержувача, KP-…").s, text: $recipient)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(L("Сума, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker(L("Як часто").s, selection: $frequency) {
                        ForEach(BankText.frequencies, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    DatePicker(L("Перший платіж").s, selection: $first, in: Date.now..., displayedComponents: .date)
                }
                ErrorSection(error: screen.error)
                FormAction(title: L("Створити").s, disabled: title.isEmpty || recipient.isEmpty || (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({
                            try await model.api.addRecurring(title: title, recipient: recipient, amount: amount ?? 0,
                                                             frequency: frequency, first: BankText.isoDay(first))
                        }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle(L("Регулярний платіж").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
