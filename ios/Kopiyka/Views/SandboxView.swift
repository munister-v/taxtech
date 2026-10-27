import EdgeRouter
import SwiftUI

/// Навчальний банк на віртуальних грошах. Тут же - перевірка переказу на шахрайство,
/// яку EdgeRouter виконує на телефоні (Layer 1) або на сервері (усі шари).
struct SandboxView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.signedIn { TransferCheckView() } else { SignInView() }
            }
            .navigationTitle("Навчальний банк")
        }
    }
}

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var server = ""
    @State private var email = ""
    @State private var password = ""
    @State private var status: String?
    @State private var working = false

    var body: some View {
        Form {
            Section {
                Text("Гроші тут віртуальні: справжніх рахунків, карток і переказів немає. Банк потрібен, щоб навчитися фінансів і перевірити, де краще рахувати - на телефоні чи на сервері.")
                    .foregroundStyle(.secondary)
            }
            Section("Сервер") {
                TextField("Адреса", text: $server)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Перевірити зв'язок") { Task { await ping() } }
            }
            Section("Вхід") {
                TextField("Пошта", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Пароль", text: $password)
                Button("Увійти") { Task { await signIn() } }
                    .disabled(email.isEmpty || password.isEmpty || working)
            }
            if let status {
                Section { Text(status).foregroundStyle(.secondary) }
            }
        }
        .onAppear {
            server = model.serverURL.absoluteString
            #if DEBUG
            // демо-вхід для симулятора: simctl launch з SIMCTL_CHILD_KOPIYKA_DEMO_* (значення з server/.env.example)
            let env = ProcessInfo.processInfo.environment
            if email.isEmpty, let id = env["KOPIYKA_DEMO_IDENTITY"] { email = id }
            if password.isEmpty, let pw = env["KOPIYKA_DEMO_PASSWORD"] { password = pw }
            #endif
        }
        .onSubmit { applyServer() }
    }

    private func applyServer() {
        if let url = URL(string: server.trimmingCharacters(in: .whitespaces)), url.scheme != nil {
            model.serverURL = url
        }
    }

    private func ping() async {
        applyServer()
        let clock = ContinuousClock()
        let t0 = clock.now
        do {
            _ = try await model.api.ping()
            status = "Сервер на зв'язку, \(Format.ms(Double((clock.now - t0).components.attoseconds) / 1e15 + Double((clock.now - t0).components.seconds) * 1000))"
        } catch {
            status = "Немає зв'язку: \(error.localizedDescription)"
        }
    }

    private func signIn() async {
        applyServer()
        working = true
        defer { working = false }
        do {
            try await model.signIn(email: email, password: password)
        } catch {
            status = error.localizedDescription
        }
    }
}

struct TransferCheckView: View {
    @Environment(AppModel.self) private var model
    @State private var amount: Double?
    @State private var balance: Double? = 25_000
    @State private var recipient = ""
    @State private var note = ""
    @State private var verdict: FraudTask.Verdict?
    @State private var record: DecisionRecord?
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("Сума, віртуальні ₴", value: $amount, format: .number).keyboardType(.decimalPad)
                TextField("Залишок на рахунку", value: $balance, format: .number).keyboardType(.decimalPad)
                TextField("Рахунок одержувача", text: $recipient)
                TextField("Призначення", text: $note)
            } header: {
                Text("Переказ")
            }
            Section {
                Button("Перевірити переказ") { Task { await check() } }
                    .disabled((amount ?? 0) <= 0)
                Button("Приклад: дроблення під поріг") {
                    amount = 9_950
                    note = "терміново"
                    recipient = "UA00SANDBOX0000000000000042"
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            if let verdict, let record {
                Section("Ризик") {
                    LabeledContent("Бал", value: "\(verdict.score) з 100").monospacedDigit()
                    LabeledContent("Рівень", value: Self.levels[verdict.level] ?? verdict.level)
                    LabeledContent("Шарів правил", value: "\(verdict.layers) з 3")
                    if !verdict.flags.isEmpty {
                        Text(verdict.flags.map { Self.flags[$0] ?? $0 }.joined(separator: "\n"))
                            .font(.footnote)
                    }
                }
                Section {
                    RoutedNote(record: record)
                    FeedbackButtons(id: record.id)
                }
            }
            Section {
                Button("Вийти", role: .destructive) { model.signOut() }
            }
        }
    }

    private func check() async {
        error = nil
        let input = FraudTask.Input(amount: amount ?? 0, balance: balance ?? 0, description: note,
                                    recipient: recipient.isEmpty ? nil : recipient)
        do {
            let routed = try await model.run(FraudTask.profile, input: input, executors: FraudTask.executors(api: model.api))
            verdict = routed.output
            record = routed.record
        } catch {
            self.error = error.localizedDescription
        }
    }

    static let levels = ["low": "Низький", "medium": "Середній", "high": "Високий", "critical": "Критичний"]
    static let flags = [
        "structuring": "Сума трохи нижче контрольного порогу",
        "round_amount": "Підозріло кругла сума",
        "suspicious_description": "Підозрілі слова в призначенні",
        "balance_depletion": "Майже весь залишок",
        "balance_depletion_critical": "Увесь залишок",
        "threshold_masking": "Сума впритул під порогом звітності",
        "multi_rule_correlation": "Кілька ознак одночасно",
        "multi_rule_correlation_strong": "Багато ознак одночасно",
        "multi_rule_correlation_chain": "Ланцюжок ознак",
        // далі - правила, що бачать історію й граф, лише на сервері
        "amount_high": "Сума вища за звичну",
        "amount_extreme": "Сума набагато вища за звичну",
        "amount_new_personal_max": "Найбільша сума за весь час",
        "iqr_mild_outlier": "Сума поза звичним діапазоном",
        "iqr_extreme_outlier": "Сума далеко поза звичним діапазоном",
        "amount_arith_progression": "Суми ростуть рівними кроками",
        "amount_geo_progression": "Суми ростуть у рази",
        "velocity_elevated": "Частіше, ніж зазвичай",
        "velocity_burst": "Сплеск переказів",
        "velocity_sustained_hour": "Багато переказів протягом години",
        "freq_escalation_spike": "Різке зростання частоти",
        "freq_escalation_inactive": "Раптова активність після тиші",
        "inactivity_burst": "Великий переказ після довгої паузи",
        "rapid_succession": "Перекази один за одним",
        "night_batch_activity": "Серія переказів уночі",
        "time_night_utc": "Нічний час",
        "time_personal_anomaly": "Незвичний для вас час",
        "new_recipient": "Новий одержувач",
        "new_recipient_large_amount": "Велика сума новому одержувачу",
        "new_recipient_new_account": "Одержувач щойно відкрив рахунок",
        "new_sender_account": "Рахунок щойно відкрито",
        "duplicate_transfer": "Повтор того самого переказу",
        "smurfing": "Дроблення на дрібні перекази",
        "counterparty_concentration": "Майже всі перекази одному одержувачу",
        "transfer_fanout": "Розсилка багатьом одержувачам",
        "transfer_pingpong": "Гроші ходять туди й назад",
        "pass_through": "Гроші одразу йдуть далі",
        "money_mule_suspected": "Одержувач схожий на підставний рахунок",
        "money_mule_pattern": "Схема підставного рахунку",
        "recipient_risk_propagation": "Одержувач пов'язаний із підозрілими",
        "behavioral_entropy_amounts": "Неприродно однакові суми",
        "behavioral_entropy_timing": "Неприродно рівні проміжки",
        "behavioral_entropy_bot": "Схоже на автоматичні перекази",
        "card_topup_abuse": "Часті поповнення картки",
        "historical_blocked": "Раніше вже блокувались перекази",
        "historical_critical": "Раніше були критичні перекази",
        "journal_orphan_entries": "Розбіжність у журналі рахунку",
    ]
}
