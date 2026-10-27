import AuthenticationServices
import CryptoKit
import SwiftUI

/// Вхід і реєстрація на весь екран: знак, «Вхід / Реєстрація», Apple, пошта й пароль.
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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    MarkView(height: 64)
                    (Text("Tax").font(Theme.display(30, .bold)) + Text("Tech").font(Theme.display(30, .light)))
                        .tracking(-0.6)
                    Text("Особистий кабінет").caption()
                }
                .padding(.top, 56)
                .padding(.bottom, 32)

                VStack(spacing: 14) {
                    Picker("Режим", selection: $register) {
                        Text("Вхід").tag(false)
                        Text("Реєстрація").tag(true)
                    }
                    .pickerStyle(.segmented)

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
                    .clipShape(.rect(cornerRadius: Theme.corner, style: .continuous))
                    .disabled(working)

                    if working {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Входимо…").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let status {
                        Text(status)
                            .font(.footnote)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                    }

                    HStack {
                        Rectangle().fill(Theme.line).frame(height: Theme.hairline)
                        Text("або").font(.footnote).foregroundStyle(.secondary)
                        Rectangle().fill(Theme.line).frame(height: Theme.hairline)
                    }
                    .padding(.vertical, 4)

                    if register {
                        field("Ім'я та прізвище") { TextField("Олена Коваленко", text: $name).textContentType(.name) }
                        field("Телефон") { TextField("+380…", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber) }
                    }
                    field(register ? "Пошта" : "Телефон або пошта") {
                        TextField(register ? "you@example.com" : "Телефон або пошта", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(register ? .emailAddress : .username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    field("Пароль") {
                        SecureField(register ? "Щонайменше 8 символів" : "Пароль", text: $password)
                            .textContentType(register ? .newPassword : .password)
                    }

                    Button(register ? "Створити акаунт" : "Увійти") { Task { await submit() } }
                        .buttonStyle(InkButton())
                        .disabled(!valid || working)
                }
                .padding(20)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerLarge, style: .continuous))


                VStack(spacing: 10) {
                    Button(showServer ? "Сховати адресу сервера" : "Адреса сервера") { showServer.toggle() }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if showServer {
                        TextField("https://…", text: $server)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.footnote.monospaced())
                            .padding(12)
                            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                            .onSubmit { applyServer() }
                    }
                }
                .padding(.top, 24)
                Text(Brand.lab)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .animation(.smooth(duration: 0.2), value: register)
        .onChange(of: register) { status = nil }
        .onAppear {
            server = model.serverURL.absoluteString
            #if DEBUG
            // демо-вхід для симулятора: simctl launch з SIMCTL_CHILD_KOPIYKA_DEMO_* (значення з server/.env.example)
            let env = ProcessInfo.processInfo.environment
            if email.isEmpty, let id = env["KOPIYKA_DEMO_IDENTITY"] { email = id }
            if password.isEmpty, let pw = env["KOPIYKA_DEMO_PASSWORD"] { password = pw }
            #endif
        }
    }

    private var valid: Bool {
        register ? name.count >= 2 && phone.filter(\.isNumber).count >= 10 && email.contains("@") && password.count >= 8
            : !email.isEmpty && !password.isEmpty
    }

    private func field<F: View>(_ title: String, @ViewBuilder _ content: () -> F) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).caption()
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Theme.bg, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
        }
    }

    private func submit() async {
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
            status = error.localizedDescription
        }
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
