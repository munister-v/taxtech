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
                    BrandEmpty(title: "Цілей ще немає", action: "Поставити ціль") { adding = true }
                } else if !items.isEmpty {
                    let saved = items.reduce(0) { $0 + $1.currentAmount }, target = items.reduce(0) { $0 + $1.targetAmount }
                    HeroPanel {
                        HeroCaption("Відкладено")
                        BigAmount(value: saved, size: 40).padding(.top, 6)
                        Text("з \(Format.money(target))").font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.onAccent.opacity(0.7))
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(items) { g in tile(g) }
                    }
                    Button("Нова ціль") { adding = true }.buttonStyle(LineButton())
                }
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Цілі")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $adding) { NewGoalView { await load() } }
        .sheet(item: $funding) { g in
            AmountSheet(title: g.title, action: "Відкласти", amount: 500) { a in
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
                Text("з \(Format.money(g.targetAmount))").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                if let d = g.deadline, !d.isEmpty { Text("до \(BankText.date(d))").font(.caption).foregroundStyle(.secondary) }
            }
            HStack {
                Button { funding = g } label: {
                    Image(systemName: "plus").font(.subheadline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(Theme.accent, in: .circle)
                        .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(PressScale())
                .accessibilityLabel("Відкласти")
                Spacer()
                Menu {
                    Button("Видалити ціль", role: .destructive) {
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
                    TextField("Назва", text: $title)
                    TextField("Скільки потрібно, TAX", value: $target, format: .number).keyboardType(.decimalPad)
                    Toggle("Є строк", isOn: $hasDeadline)
                        .tint(Theme.ink.opacity(0.6))
                    if hasDeadline { DatePicker("До", selection: $deadline, in: Date.now..., displayedComponents: .date) }
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Створити ціль", disabled: title.isEmpty || (target ?? 0) <= 0 || screen.busy) {
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
            .navigationTitle("Нова ціль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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
            Section("Контакти") {
                if loaded && contacts.isEmpty { Text("Контактів немає").foregroundStyle(.secondary) }
                ForEach(contacts) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(c.contactName)
                        Text([c.accountNumber, c.phone].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", "))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button("Видалити", role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteContact(c.id) }
                                await load()
                            }
                        }
                    }
                }
                Button("Додати контакт") { addingContact = true }
            }
            Section {
                if loaded && templates.isEmpty { Text("Шаблонів немає").foregroundStyle(.secondary) }
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
                        Button("Видалити", role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteTemplate(t.id) }
                                await load()
                            }
                        }
                    }
                }
                Button("Додати шаблон") { addingTemplate = true }
            } header: {
                Text("Шаблони платежів")
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle("Контакти")
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

    static let relations = [("family", "Родина"), ("friend", "Друг"), ("work", "Робота"), ("other", "Інше")]

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField("Ім'я", text: $name)
                    Picker("Хто це", selection: $relation) {
                        ForEach(Self.relations, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    TextField("Рахунок, KP-…", text: $account)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Телефон", text: $phone).keyboardType(.phonePad)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Зберегти", disabled: name.isEmpty || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.addContact(name: name, relation: relation, account: account, phone: phone) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Новий контакт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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
                    TextField("Назва", text: $name)
                    TextField("Рахунок одержувача, KP-…", text: $recipient)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Сума, TAX (необов'язково)", value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField("Призначення", text: $note)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Зберегти", disabled: name.isEmpty || recipient.isEmpty || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.addTemplate(name: name, recipient: recipient, amount: amount, note: note) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Новий шаблон")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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
                if loaded && limits.isEmpty { Text("Лімітів немає").foregroundStyle(.secondary) }
                ForEach(limits) { l in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(BankText.type(l.txType))
                            Spacer()
                            Text("\(Format.money(l.spent ?? 0)) з \(Format.money(l.monthlyLimit))")
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                        }
                        Meter(value: (l.pct ?? 0) / 100)
                    }
                    .swipeActions {
                        Button("Видалити", role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteLimit(l.txType) }
                                await load()
                            }
                        }
                    }
                }
                Button("Поставити ліміт") { addingLimit = true }
            } header: {
                Text("Місячні ліміти")
            } footer: {
                Text("Скільки можна витратити за місяць за видом операцій.")
            }
            Section("Регулярні платежі") {
                if loaded && recurring.isEmpty { Text("Регулярних платежів немає").foregroundStyle(.secondary) }
                ForEach(recurring) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.title)
                            Text("\(BankText.frequency(r.frequency)), далі \(BankText.date(r.nextRunDate))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Format.money(r.amount)).monospacedDigit()
                        Toggle("Активний", isOn: .init(get: { r.isActive != 0 }, set: { _ in
                            Task {
                                await screen.run { try await model.api.toggleRecurring(r.id) }
                                await load()
                            }
                        }))
                        .labelsHidden()
                        .tint(Theme.ink.opacity(0.6))
                    }
                    .swipeActions {
                        Button("Видалити", role: .destructive) {
                            Task {
                                await screen.run { try await model.api.deleteRecurring(r.id) }
                                await load()
                            }
                        }
                    }
                }
                Button("Новий регулярний платіж") { addingRecurring = true }
            }
            ErrorSection(error: screen.error)
        }
        .labForm()
        .navigationTitle("Ліміти й платежі")
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
                    Picker("Вид операцій", selection: $type) {
                        ForEach(["payment", "transfer", "donation"], id: \.self) { Text(BankText.type($0)).tag($0) }
                    }
                    TextField("Ліміт на місяць, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Поставити ліміт", disabled: (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await model.api.setLimit(txType: type, amount: amount ?? 0) }) {
                            await done()
                            dismiss()
                        }
                    }
                }
            }
            .labForm()
            .navigationTitle("Новий ліміт")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
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
                    TextField("Назва", text: $title)
                    TextField("Рахунок одержувача, KP-…", text: $recipient)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Сума, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                    Picker("Як часто", selection: $frequency) {
                        ForEach(BankText.frequencies, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    DatePicker("Перший платіж", selection: $first, in: Date.now..., displayedComponents: .date)
                }
                ErrorSection(error: screen.error)
                FormAction(title: "Створити", disabled: title.isEmpty || recipient.isEmpty || (amount ?? 0) <= 0 || screen.busy) {
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
            .navigationTitle("Регулярний платіж")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
