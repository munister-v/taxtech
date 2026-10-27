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
                TextField("Сума, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                if let error { Text(error).foregroundStyle(.secondary) }
            }
            .labForm()
            .navigationTitle("Поповнення")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Поповнити") {
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
                        Text("Доступно \(Format.money(balance))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowBackground(Color.clear)
                }
                Section {
                    Picker("Куди", selection: $byCard) {
                        Text("На рахунок").tag(false)
                        Text("На картку").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    TextField(byCard ? "Номер картки" : "Рахунок одержувача, KP-…", text: $recipient)
                        .keyboardType(byCard ? .numberPad : .default)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Призначення", text: $note)
                    if !contacts.isEmpty || !templates.isEmpty {
                        Menu("Обрати зі збережених") {
                            ForEach(contacts.filter { ($0.accountNumber ?? "").isEmpty == false }) { c in
                                Button(c.contactName) { byCard = false; recipient = c.accountNumber ?? "" }
                            }
                            ForEach(templates) { t in
                                Button("Шаблон: \(t.name)") {
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

                if verdict == nil {
                    Section {
                        Button("Перевірити переказ") { Task { await check() } }
                            .disabled(!valid || busy)
                        Button("Приклад: дроблення під поріг") {
                            recipient = "KP-100003"
                            amount = 9_950
                            note = "терміново"
                        }
                    }
                }

                if let verdict, let record {
                    Section("Оцінка ризику") {
                        LabeledContent("Бал", value: "\(verdict.score) з 100").monospacedDigit()
                        LabeledContent("Рівень", value: Self.levels[verdict.level] ?? verdict.level)
                        LabeledContent("Шарів правил", value: "\(verdict.layers) з 3")
                        if !verdict.flags.isEmpty {
                            Text(verdict.flags.map { Self.flags[$0] ?? $0 }.joined(separator: "\n"))
                                .font(.footnote)
                        }
                        RoutedNote(record: record)
                    }
                    if outcome == nil {
                        Section {
                            if verdict.level == "critical" {
                                Text("Переказ із критичним ризиком не надсилається.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Надіслати \(Format.money(amount ?? 0))") { Task { await send() } }
                                    .disabled(busy)
                            }
                        }
                    }
                }

                if let outcome { Section { Text(outcome) } }
                if let error { Section { Text(error).foregroundStyle(.secondary) } }
            }
            .labForm()
            .task {
                if recipient.isEmpty {
                    byCard = startByCard
                    recipient = startRecipient
                }
                await loadSaved()
            }
            .navigationTitle("Переказ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(outcome == nil ? "Скасувати" : "Готово") { dismiss() } }
            }
        }
    }

    private var valid: Bool { (amount ?? 0) > 0 && recipient.count >= 4 }

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
            outcome = "Надіслано \(Format.money(amount ?? 0)) на \(recipient)"
            await model.feedback(record.id, correct: true)
            await done()
        } catch {
            // банк відмовив повним антифродом, а попередня оцінка пропустила - це помилка оцінки
            let blocked = error.localizedDescription.contains("заблоковано")
            if blocked { await model.feedback(record.id, correct: false) }
            outcome = blocked ? "Банк заблокував переказ: \(error.localizedDescription)" : nil
            if !blocked { self.error = error.localizedDescription }
        }
    }

    static let levels = ["low": "Низький", "medium": "Середній", "high": "Високий", "critical": "Критичний"]
    static let flags = FraudFlags.titles
}
