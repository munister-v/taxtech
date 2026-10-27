import AuthenticationServices
import CryptoKit
import EdgeRouter
import SwiftUI

/// Навчальний банк на віртуальних грошах: рахунок, картки, історія, поповнення й переказ.
/// Перед переказом EdgeRouter оцінює ризик на телефоні (Layer 1) або на сервері (усі шари).
struct SandboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var pinRequired = false

    var body: some View {
        NavigationStack {
            if model.signedIn {
                if pinRequired && !model.bankUnlocked {
                    PinLockView().toolbar(.hidden, for: .navigationBar)
                } else {
                    BankView()
                }
            } else {
                SignInView()
                    .labForm()
                    .navigationTitle("Навчальний банк")
            }
        }
        .task(id: model.signedIn) {
            pinRequired = model.signedIn ? ((try? await model.api.hasPin()) ?? false) : false
        }
        .onChange(of: phase) { _, p in
            guard p == .background else { return }
            model.bankUnlocked = false
            Task { pinRequired = model.signedIn ? ((try? await model.api.hasPin()) ?? pinRequired) : false }
        }
    }
}

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
                TextField("Сума, віртуальні ₴", value: $amount, format: .number).keyboardType(.decimalPad)
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
            .task { await loadSaved() }
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

struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var server = ""
    @State private var email = ""
    @State private var password = ""
    @State private var status: String?
    @State private var working = false
    @State private var nonce = ""
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        LabForm {
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
            Section {
                SignInWithAppleButton(.continue) { request in
                    applyServer()
                    nonce = Self.randomNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    Task { await finishApple(result) }
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(height: 52)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                Text("Вхід через Apple створює навчальний акаунт із віртуальним рахунком. Пошту можна сховати: Apple дасть застосунку лише анонімну адресу.")
            }
            Section("Вхід за поштою") {
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

    private func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            // користувач закрив вікно - не помилка
            if (error as? ASAuthorizationError)?.code != .canceled { status = error.localizedDescription }
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                status = "Apple не віддала токен входу."
                return
            }
            // ім'я Apple віддає лише при першому вході
            let name = credential.fullName.flatMap {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            }
            working = true
            defer { working = false }
            do {
                try await model.signInWithApple(identityToken: token, nonce: nonce, fullName: name)
            } catch {
                status = error.localizedDescription
            }
        }
    }

    private static func randomNonce() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
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
            status = "Сервер на зв'язку, \(Format.ms(clock.now - t0))"
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
