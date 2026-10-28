import AuthenticationServices
import CryptoKit
import SwiftUI

/// Вхід і реєстрація: великий заголовок, текстові вкладки, поля з підказками, «Забули пароль?», Apple.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var register = false
    @State private var name = ""
    @State private var phone = "+380"
    @State private var email = ""
    @State private var password = ""
    @State private var server = ""
    @State private var showServer = false
    @State private var status: String?
    @State private var working = false
    @State private var nonce = ""
    @State private var forgot = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    MarkView(height: 30)
                    (Text("Tax").fontWeight(.bold) + Text("Tech").fontWeight(.light)).font(.system(size: 22)).tracking(-0.4)
                }
                .padding(.top, 28)
                .rise(0)

                Text(register ? "Новий акаунт" : "З поверненням")
                    .font(.system(size: 36, weight: .bold)).tracking(-0.8)
                    .padding(.top, 40)
                    .contentTransition(.opacity)
                    .rise(1)
                Text(register ? "Рахунок із токенами TAX, віртуальні картки, податки й магазин."
                              : "Увійдіть, щоб відкрити рахунок, картки й податки.")
                    .font(.body).foregroundStyle(.secondary)
                    .padding(.top, 6)
                    .rise(1)

                TextTabs(items: [(false, "Вхід"), (true, "Реєстрація")], selection: $register)
                    .padding(.top, 28)
                    .rise(2)

                VStack(alignment: .leading, spacing: 16) {
                    if register {
                        AuthField(title: "Ім'я та прізвище", placeholder: "Олена Коваленко", text: $name,
                                  hint: name.isEmpty || name.count >= 2 ? nil : "Щонайменше дві літери", content: .name)
                        AuthField(title: "Телефон", placeholder: "+380 …", text: $phone,
                                  hint: phoneHint, content: .telephoneNumber, keyboard: .phonePad)
                    }
                    AuthField(title: register ? "Пошта" : "Телефон або пошта",
                              placeholder: register ? "you@example.com" : "+380… або you@example.com", text: $email,
                              hint: register && !email.isEmpty && !emailValid ? "Перевірте адресу пошти" : nil,
                              content: register ? .emailAddress : .username, keyboard: .emailAddress, plain: true)
                    VStack(alignment: .leading, spacing: 10) {
                        AuthField(title: "Пароль", placeholder: register ? "Щонайменше 8 символів" : "Пароль", text: $password,
                                  secure: true, content: register ? .newPassword : .password,
                                  submit: register ? .join : .go) { Task { await submit() } }
                        if register && !password.isEmpty { PasswordStrength(password: password) }
                        if !register {
                            Button("Забули пароль?") { forgot = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .padding(.top, 22)
                .rise(3)

                if let status {
                    Label(status, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.ink.opacity(0.07), in: .rect(cornerRadius: 14, style: .continuous))
                        .padding(.top, 18)
                        .transition(.opacity)
                }

                Button { Task { await submit() } } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(Theme.onAccent) }
                        Text(register ? "Створити акаунт" : "Увійти")
                    }
                }
                .buttonStyle(InkButton())
                .disabled(!valid || working)
                .padding(.top, 22)
                .rise(4)

                HStack(spacing: 10) {
                    Rectangle().fill(Theme.line).frame(height: Theme.hairline)
                    Text("або").font(.footnote).foregroundStyle(.secondary)
                    Rectangle().fill(Theme.line).frame(height: Theme.hairline)
                }
                .padding(.vertical, 18)

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
                .clipShape(.capsule)
                .disabled(working)

                if register {
                    Text("Створюючи акаунт, ви погоджуєтеся, що це навчальний банк: гроші віртуальні, токени TAX не мають цінності.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .padding(.top, 14)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { withAnimation(.snappy) { showServer.toggle() } } label: {
                        HStack(spacing: 6) {
                            Text("Сервер").font(.footnote.weight(.medium))
                            Text(model.serverURL.host() ?? "").font(.footnote.monospaced()).foregroundStyle(.tertiary)
                            Image(systemName: showServer ? "chevron.up" : "chevron.down").font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    if showServer {
                        TextField("https://…", text: $server)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.footnote.monospaced())
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .overlay(Capsule().stroke(Theme.ink.opacity(0.14), lineWidth: 1))
                            .onSubmit { applyServer() }
                    }
                }
                .padding(.top, 30)

                Text(Brand.lab)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { Aurora() }
        .animation(.smooth(duration: 0.25), value: register)
        .animation(.smooth(duration: 0.2), value: status)
        .onChange(of: register) { status = nil }
        .onChange(of: email) { status = nil }
        .onChange(of: password) { status = nil }
        .sheet(isPresented: $forgot) { ForgotPasswordView(identity: email) }
        .onAppear {
            server = model.serverURL.absoluteString
            if email.isEmpty { email = model.lastIdentity }
            #if DEBUG
            // демо-вхід для симулятора: simctl launch з SIMCTL_CHILD_KOPIYKA_DEMO_* (значення з server/.env.example)
            let env = ProcessInfo.processInfo.environment
            if email.isEmpty, let id = env["KOPIYKA_DEMO_IDENTITY"] { email = id }
            if password.isEmpty, let pw = env["KOPIYKA_DEMO_PASSWORD"] { password = pw }
            #endif
        }
    }

    private var emailValid: Bool {
        let parts = email.split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !email.contains(" ")
    }

    private var phoneHint: String? {
        let digits = phone.filter(\.isNumber).count
        return phone.count <= 4 || digits >= 12 ? nil : "Номер у форматі +380 і 9 цифр"
    }

    private var valid: Bool {
        register ? name.count >= 2 && phone.filter(\.isNumber).count >= 12 && emailValid && password.count >= 8
            : !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private func submit() async {
        guard valid, !working else { return }
        applyServer()
        working = true
        defer { working = false }
        do {
            if register {
                try await model.register(name: name, phone: phone, email: email, password: password)
            } else {
                try await model.signIn(email: email, password: password)
            }
        } catch {
            status = Self.friendly(error.localizedDescription)
        }
    }

    /// Серверне «Невірні облікові дані» - людською мовою.
    private static func friendly(_ message: String) -> String {
        message.contains("Невірні облікові дані") ? "Пароль або логін не підходять. Перевірте їх чи відновіть пароль." : message
    }

    private func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            status = Self.appleMessage(error)
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
                status = "Сервер не прийняв вхід через Apple: \(error.localizedDescription)"
            }
        }
    }

    /// Людське пояснення, чому Apple не пустила; nil - користувач сам закрив вікно.
    private static func appleMessage(_ error: Error) -> String? {
        guard let e = error as? ASAuthorizationError else { return "Apple: \(error.localizedDescription)" }
        switch e.code {
        case .canceled: return nil
        case .unknown:
            return "Apple не відповіла (код 1000). Перевірте, що в Параметрах виконано вхід в Apple ID з двоетапною перевіркою, і спробуйте ще раз."
        case .notInteractive: return "Apple не змогла показати вікно входу. Спробуйте ще раз."
        case .failed, .invalidResponse, .notHandled:
            return "Apple не завершила вхід (код \(e.code.rawValue)). Спробуйте ще раз або увійдіть поштою."
        default: return "Apple: код \(e.code.rawValue). \(e.localizedDescription)"
        }
    }

    private static func randomNonce() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func applyServer() {
        if let url = URL(string: server.trimmingCharacters(in: .whitespaces)), url.scheme != nil, AppModel.reachable(url) {
            model.serverURL = url
        }
    }
}

// MARK: Поля, надійність пароля, відновлення

/// Поле форми: підпис над рамкою, рамка темнішає у фокусі, око для пароля, підказка під полем.
struct AuthField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var secure = false
    var hint: String?
    var content: UITextContentType?
    var keyboard: UIKeyboardType = .default
    /// Без автокапіталізації й автовиправлення: пошта, логін, коди.
    var plain = false
    var submit: SubmitLabel = .next
    var onSubmit: (() -> Void)?
    @FocusState private var focused: Bool
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Group {
                    if secure && !reveal {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(plain || secure ? .never : .words)
                .autocorrectionDisabled(plain || secure)
                .submitLabel(submit)
                .onSubmit { onSubmit?() }
                .focused($focused)
                if secure && !text.isEmpty {
                    Button { reveal.toggle(); focused = true } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye").foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(reveal ? "Сховати пароль" : "Показати пароль")
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, secure ? 8 : 16)
            .frame(minHeight: 54)
            .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(focused ? Theme.ink.opacity(0.75) : (hint != nil ? Theme.ink.opacity(0.35) : Theme.line),
                                  lineWidth: focused ? 1.5 : 1)
            )
            .animation(.snappy(duration: 0.15), value: focused)
            if let hint {
                Text(hint).font(.footnote).foregroundStyle(Theme.ink.opacity(0.75))
                    .transition(.opacity)
            }
        }
    }
}

/// Надійність пароля: чотири риски й перелік вимог, що вже виконані.
struct PasswordStrength: View {
    let password: String

    private var rules: [(String, Bool)] {
        [
            ("8+ символів", password.count >= 8),
            ("Літери й цифри", password.rangeOfCharacter(from: .letters) != nil && password.rangeOfCharacter(from: .decimalDigits) != nil),
            ("Великі й малі", password.rangeOfCharacter(from: .uppercaseLetters) != nil && password.rangeOfCharacter(from: .lowercaseLetters) != nil),
            ("Спецсимвол", password.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.whitespaces).inverted) != nil),
        ]
    }

    private var score: Int {
        guard password.count >= 8 else { return password.isEmpty ? 0 : 1 }
        return min(4, rules.filter(\.1).count + (password.count >= 12 ? 1 : 0))
    }

    private var label: String {
        ["", "Слабкий", "Середній", "Надійний", "Дуже надійний"][score]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    Capsule().fill(i < score ? Theme.ink : Theme.line).frame(height: 4)
                }
                Text(label).font(.footnote.weight(.semibold)).frame(width: 104, alignment: .trailing)
            }
            .animation(.snappy(duration: 0.2), value: score)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 6) {
                ForEach(rules, id: \.0) { rule in
                    Label(rule.0, systemImage: rule.1 ? "checkmark.circle.fill" : "circle")
                        .font(.footnote)
                        .foregroundStyle(rule.1 ? Theme.ink : Color.secondary)
                }
            }
        }
    }
}

/// «Забули пароль?»: телефон чи пошта → код → новий пароль; після зміни одразу входимо.
struct ForgotPasswordView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var identity: String
    @State private var ticket: API.ResetTicket?
    @State private var code = ""
    @State private var newPassword = ""
    @State private var left = 0
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(ticket == nil ? "Відновлення пароля" : "Новий пароль")
                        .font(.system(size: 30, weight: .bold)).tracking(-0.6)
                    if let ticket {
                        Text(ticket.demoCode == nil ? "Код надіслано на \(ticket.sentTo). Він діє \(ticket.expiresIn / 60) хвилин."
                                                    : "Код для \(ticket.sentTo) діє \(ticket.expiresIn / 60) хвилин.")
                            .foregroundStyle(.secondary)
                        if let demo = ticket.demoCode {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Навчальний банк: SMS не надсилаємо").font(.footnote).foregroundStyle(.secondary)
                                    Text(demo).font(.system(size: 24, weight: .bold).monospaced()).tracking(4)
                                }
                                Spacer()
                                Button("Вставити") { code = demo }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).frame(height: 36)
                                    .overlay(Capsule().stroke(Theme.ink.opacity(0.16), lineWidth: 1))
                                    .foregroundStyle(Theme.ink)
                                    .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Код із 6 цифр").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            TextField("000000", text: $code)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .font(.system(size: 28, weight: .semibold).monospaced())
                                .tracking(6)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 60)
                                .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
                                .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(6)) }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            AuthField(title: "Новий пароль", placeholder: "Щонайменше 8 символів", text: $newPassword,
                                      secure: true, content: .newPassword, submit: .done) { Task { await reset() } }
                            if !newPassword.isEmpty { PasswordStrength(password: newPassword) }
                        }
                        Button("Змінити пароль і увійти") { Task { await reset() } }
                            .buttonStyle(InkButton())
                            .disabled(code.count != 6 || newPassword.count < 8 || screen.busy)
                        HStack {
                            Text(left > 0 ? String(format: "Повторно через %d:%02d", left / 60, left % 60) : "Код не прийшов?")
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                            Spacer()
                            Button("Надіслати ще раз") { Task { await request() } }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .disabled(left > 0 || screen.busy)
                        }
                    } else {
                        Text("Вкажіть телефон або пошту акаунта. Надішлемо код, після нього задасте новий пароль, а всі старі сесії буде завершено.")
                            .foregroundStyle(.secondary)
                        AuthField(title: "Телефон або пошта", placeholder: "+380… або you@example.com", text: $identity,
                                  content: .username, keyboard: .emailAddress, plain: true, submit: .send) { Task { await request() } }
                        Button("Надіслати код") { Task { await request() } }
                            .buttonStyle(InkButton())
                            .disabled(identity.trimmingCharacters(in: .whitespaces).isEmpty || screen.busy)
                    }
                    if let e = screen.error {
                        Label(e, systemImage: "exclamationmark.circle").font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Theme.ink.opacity(0.07), in: .rect(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
            .task(id: ticket?.resetId) {
                guard ticket != nil else { return }
                left = 60
                while left > 0 && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    left -= 1
                }
            }
        }
        .presentationDetents([.large])
        .animation(.smooth(duration: 0.25), value: ticket?.resetId)
    }

    private func request() async {
        await screen.run {
            ticket = try await model.api.forgotPassword(identity: identity.trimmingCharacters(in: .whitespaces))
            code = ""
        }
    }

    private func reset() async {
        guard let ticket, code.count == 6, newPassword.count >= 8 else { return }
        if await screen.run({ try await model.resetPassword(ticket, code: code, newPassword: newPassword) }) {
            model.lastIdentity = identity.trimmingCharacters(in: .whitespaces)
            dismiss()
        }
    }
}
