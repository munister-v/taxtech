import EdgeRouter
import SwiftUI

struct TopUpView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let done: () async -> Void
    @State private var amount: Double? = 1000
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            LabForm {
                TextField(L("Сума, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                if let error { Text(error).foregroundStyle(.secondary) }
            }
            .labForm()
            .navigationTitle(L("Поповнення").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Поповнити").s) {
                        busy = true
                        Task {
                            do {
                                _ = try await model.api.topUp(amount ?? 0)
                                await done()
                                dismiss()
                            } catch {
                                self.error = error.localizedDescription
                            }
                            busy = false
                        }
                    }
                    .disabled((amount ?? 0) <= 0 || busy)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Переказ у два кроки: спершу EdgeRouter оцінює ризик, потім людина підтверджує.
/// Сервер банку при виконанні ще раз перевіряє повним антифродом - і його відповідь
/// стає міткою правильності для оцінки, зробленої на телефоні.
struct TransferView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let balance: Double
    var startByCard = false
    var startRecipient = ""
    var startAmount: Double?
    let done: () async -> Void

    @State private var recipient = ""
    @State private var byCard = false
    @State private var contacts: [API.Contact] = []
    @State private var templates: [API.Template] = []
    @State private var amount: Double?
    @State private var note = ""
    @State private var verdict: FraudTask.Verdict?
    @State private var record: DecisionRecord?
    @State private var outcome: String?
    @State private var error: String?
    @State private var busy = false
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    VStack(spacing: 6) {
                        TextField("0", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .font(Theme.balance(48))
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .foregroundStyle(insufficient ? Theme.alert : Theme.ink)
                        HStack(spacing: 10) {
                            if insufficient {
                                Text(Tx("Недостатньо коштів", "Not enough funds", "Недостаточно средств"))
                                    .font(Theme.ui(style: .footnote, .semibold)).foregroundStyle(Theme.alert)
                            } else {
                                Text(L("Доступно \(Format.money(balance))").s)
                                    .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                            }
                            if balance > 0, amount != maxAmount {
                                Button(Tx("Усе", "Max", "Всё")) { amount = maxAmount }
                                    .font(Theme.ui(style: .footnote, .bold)).foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Theme.accent.opacity(0.14), in: .capsule)
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
                Section {
                    Picker(L("Куди").s, selection: $byCard) {
                        Text(L("На рахунок").s).tag(false)
                        Text(L("На картку").s).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    TextField(byCard ? L("Номер картки").s : L("Рахунок одержувача, KP-…").s, text: $recipient)
                        .keyboardType(byCard ? .numberPad : .default)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if case .bad = recipientState {
                        Text(byCard ? Tx("Номер картки - 16 цифр", "A card number has 16 digits", "Номер карты - 16 цифр")
                                    : Tx("Рахунок виглядає так: KP-100003", "An account looks like KP-100003", "Счёт выглядит так: KP-100003"))
                            .font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert)
                    }
                    TextField(L("Призначення").s, text: $note)
                    if !contacts.isEmpty || !templates.isEmpty {
                        Menu(L("Обрати зі збережених").s) {
                            ForEach(contacts.filter { ($0.accountNumber ?? "").isEmpty == false }) { c in
                                Button(c.contactName) { byCard = false; recipient = c.accountNumber ?? "" }
                            }
                            ForEach(templates) { t in
                                Button(L("Шаблон: \(t.name)").s) {
                                    byCard = false
                                    recipient = t.recipientAccount ?? ""
                                    if let a = t.amount { amount = a }
                                    note = t.description ?? ""
                                }
                            }
                        }
                    }
                }
                .onChange(of: recipient) { reset() }
                .onChange(of: byCard) { reset() }
                .onChange(of: amount) { reset() }
                .onChange(of: note) { reset() }

                if overLimit {
                    Section {
                        Text(Tx("Ліміт на один переказ — \(Format.money(KYCLimits.transfer)). Підтвердьте особу в профілі, щоб підняти до \(Format.money(KYCLimits.verified)).",
                                "The limit per transfer is \(Format.money(KYCLimits.transfer)). Verify your identity in Profile to raise it to \(Format.money(KYCLimits.verified)).",
                                "Лимит на один перевод — \(Format.money(KYCLimits.transfer)). Подтвердите личность в профиле, чтобы поднять до \(Format.money(KYCLimits.verified))."))
                            .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                    }
                }
                if verdict == nil {
                    Section {
                        Button(L("Перевірити переказ").s) { Task { await check() } }
                            .disabled(!valid || busy)
                        Button(L("Приклад: дроблення під поріг").s) {
                            recipient = "KP-100003"
                            amount = 9_950
                            note = L("терміново").s
                        }
                    }
                }

                if let verdict, let record {
                    Section(L("Оцінка ризику").s) {
                        LabeledContent(L("Бал").s, value: L("\(verdict.score) з 100").s).monospacedDigit()
                        LabeledContent(L("Рівень").s, value: Self.levels[verdict.level] ?? verdict.level)
                        LabeledContent(L("Шарів правил").s, value: L("\(verdict.layers) з 3").s)
                        if !verdict.flags.isEmpty {
                            Text(verdict.flags.map { Self.flags[$0] ?? $0 }.joined(separator: "\n"))
                                .font(Theme.ui(style: .footnote))
                        }
                        RoutedNote(record: record)
                    }
                    Section { LearnLink(.fraud) }.expertOnly()
                    if outcome == nil {
                        Section {
                            if verdict.level == "critical" {
                                Text(L("Переказ із критичним ризиком не надсилається.").s)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(L("Надіслати \(Format.money(amount ?? 0))").s) {
                                    if needsConfirm { confirming = true } else { Task { await send() } }
                                }
                                .disabled(busy)
                            }
                        }
                    }
                }

                if let outcome { Section { Text(outcome); LearnLink(.idempotency).expertOnly() } }
                if let error { Section { Text(error).foregroundStyle(.secondary) } }
            }
            .labForm()
            .alert(Tx("Надіслати \(Format.money(amount ?? 0))?", "Send \(Format.money(amount ?? 0))?", "Отправить \(Format.money(amount ?? 0))?"),
                   isPresented: $confirming) {
                Button(Tx("Надіслати", "Send", "Отправить")) { Task { await send() } }
                Button(Tx("Скасувати", "Cancel", "Отмена"), role: .cancel) {}
            } message: {
                Text(Tx("Одержувач: \(recipient). Велика сума: перевірте реквізити, повернути переказ не вийде.",
                        "To: \(recipient). This is a large amount: check the details, a transfer cannot be taken back.",
                        "Получатель: \(recipient). Крупная сумма: проверьте реквизиты, вернуть перевод не получится."))
            }
            .sensoryFeedback(.success, trigger: outcome) { _, new in new?.hasPrefix(L("Надіслано").s) == true }
            .sensoryFeedback(.error, trigger: error) { _, new in new != nil }
            .task {
                if recipient.isEmpty {
                    byCard = startByCard
                    recipient = startRecipient
                    if amount == nil { amount = startAmount }
                }
                await loadSaved()
            }
            .navigationTitle(L("Переказ").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(outcome == nil ? L("Скасувати").s : L("Готово").s) { dismiss() } }
            }
        }
    }

    private var overLimit: Bool { (amount ?? 0) > KYCLimits.transfer }
    private var insufficient: Bool { (amount ?? 0) > balance + 0.004 }
    private var maxAmount: Double { (min(balance, KYCLimits.transfer) * 100).rounded(.down) / 100 }
    private var recipientState: RecipientCheck.Result { RecipientCheck.check(recipient, byCard: byCard) }
    /// Від 5 000 або половини балансу переказ просить окремого підтвердження.
    private var needsConfirm: Bool { (amount ?? 0) >= 5_000 || ((amount ?? 0) >= 500 && (amount ?? 0) >= balance * 0.5) }
    private var valid: Bool {
        (amount ?? 0) > 0 && recipient.count >= 4 && !overLimit && !insufficient && recipientState == .ok
    }

    private func loadSaved() async {
        contacts = (try? await model.api.contacts()) ?? []
        templates = (try? await model.api.templates()) ?? []
    }

    private func reset() {
        verdict = nil
        record = nil
        outcome = nil
        error = nil
    }

    private func check() async {
        busy = true
        defer { busy = false }
        error = nil
        let input = FraudTask.Input(amount: amount ?? 0, balance: balance, description: note, recipient: recipient)
        do {
            let routed = try await model.run(FraudTask.profile, input: input, executors: FraudTask.executors(api: model.api))
            verdict = routed.output
            record = routed.record
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func send() async {
        guard let record else { return }
        busy = true
        defer { busy = false }
        do {
            if byCard {
                try await model.api.transferByCard(amount ?? 0, cardNumber: recipient, description: note)
            } else {
                _ = try await model.api.transfer(amount ?? 0, to: recipient, description: note)
            }
            outcome = L("Надіслано \(Format.money(amount ?? 0)) на \(recipient)").s
            await model.feedback(record.id, correct: true)
            await done()
        } catch {
            // банк відмовив повним антифродом, а попередня оцінка пропустила - це помилка оцінки
            let blocked = error.localizedDescription.contains("заблоковано")
            if blocked { await model.feedback(record.id, correct: false) }
            outcome = blocked ? L("Банк заблокував переказ: \(error.localizedDescription)").s : nil
            if !blocked { self.error = error.localizedDescription }
        }
    }

    static var levels: [String: String] { ["low": L("Низький").s, "medium": L("Середній").s, "high": L("Високий").s, "critical": L("Критичний").s] }
    static let flags = FraudFlags.titles
}
