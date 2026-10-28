import AuthenticationServices
import CryptoKit
import SwiftUI

/// Вітальний екран: живий стос карток, сильний заголовок і три шляхи - Apple, вхід, новий акаунт.
/// Форми не тут: вхід відкривається аркушем, реєстрація - кроками по одному питанню.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var status: String?
    @State private var working = false
    @State private var nonce = ""
    @State private var signingIn = false
    @State private var signingUp = false
    @State private var server = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button { server = true } label: {
                    Image(systemName: "network").font(.system(size: 17, weight: .medium)).foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Адреса сервера")
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
            CardFan()
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .rise(1)
            BrandLockup(height: 70)
                .frame(maxWidth: .infinity)
                .padding(.top, 44)
                .rise(2)
            Spacer(minLength: 24)

            if let status {
                Label(status, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.ink.opacity(0.07), in: .rect(cornerRadius: 14, style: .continuous))
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            VStack(spacing: 10) {
                SignInWithAppleButton(.continue) { request in
                    nonce = Self.randomNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    Task { await finishApple(result) }
                }
                .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(.capsule)
                .disabled(working)

                Button("Увійти телефоном або поштою") { signingIn = true }
                    .buttonStyle(InkButton())

                Button { signingUp = true } label: {
                    (Text("Немає акаунта? ").foregroundStyle(.secondary) + Text("Створити").fontWeight(.semibold))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            .rise(4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background { Aurora() }
        .animation(.smooth(duration: 0.2), value: status)
        .sheet(isPresented: $signingIn) { SignInSheet() }
        .sheet(isPresented: $signingUp) { SignUpFlow() }
        .sheet(isPresented: $server) { ServerSheet() }
        .onAppear {
            #if DEBUG
            // демо-вхід для симулятора: simctl launch з SIMCTL_CHILD_KOPIYKA_DEMO_* одразу відкриває аркуш входу
            if ProcessInfo.processInfo.environment["KOPIYKA_DEMO_IDENTITY"] != nil { signingIn = true }
            #endif
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
}

/// Три картки віялом, що повільно дихають і нахиляються за телефоном.
struct CardFan: View {
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { tl in
            let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
            ZStack {
                card(.forest, number: "•••• 2048", angle: -16, x: -58, y: 22, t: t, phase: 0)
                card(.dark, number: "•••• 6897", angle: -3, x: 0, y: -2, t: t, phase: 1.3)
                card(.gold, number: "•••• 1755", angle: 12, x: 58, y: 26, t: t, phase: 2.6)
            }
        }
        .tilt()
    }

    private func card(_ design: CardDesign, number: String, angle: Double, x: CGFloat, y: CGFloat, t: Double, phase: Double) -> some View {
        VirtualCardView(number: number, expiry: "09/29", holder: nil, design: design)
            .frame(width: 236)
            .shadow(color: .black.opacity(0.22), radius: 18, y: 12)
            .rotationEffect(.degrees(angle + sin(t * 0.6 + phase) * 1.6))
            .offset(x: x, y: y + CGFloat(sin(t * 0.8 + phase) * 6))
    }
}

/// Вхід: телефон чи пошта й пароль на окремому аркуші.
struct SignInSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var identity = ""
    @State private var password = ""
    @State private var status: String?
    @State private var working = false
    @State private var forgot = false
    @State private var shakes = 0

    private var valid: Bool { !identity.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Вхід").font(.system(size: 34, weight: .bold)).tracking(-1)
                    AuthField(title: "Телефон або пошта", placeholder: "+380… або you@example.com", text: $identity,
                              content: .username, keyboard: .emailAddress, plain: true)
                    VStack(alignment: .leading, spacing: 12) {
                        AuthField(title: "Пароль", placeholder: "Пароль", text: $password, secure: true,
                                  content: .password, submit: .go) { Task { await submit() } }
                        Button("Забули пароль?") { forgot = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                    }
                    if let status {
                        Label(status, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Theme.ink.opacity(0.07), in: .rect(cornerRadius: 14, style: .continuous))
                            .modifier(Shake(animatableData: CGFloat(shakes)))
                    }
                    Button { Task { await submit() } } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView().tint(Theme.onAccent) }
                            Text("Увійти")
                        }
                    }
                    .buttonStyle(InkButton())
                    .disabled(!valid || working)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } }
            .sensoryFeedback(.error, trigger: shakes)
            .sheet(isPresented: $forgot) { ForgotPasswordView(identity: identity) }
            .onAppear {
                if identity.isEmpty { identity = model.lastIdentity }
                #if DEBUG
                let env = ProcessInfo.processInfo.environment
                if identity.isEmpty, let id = env["KOPIYKA_DEMO_IDENTITY"] { identity = id }
                if password.isEmpty, let pw = env["KOPIYKA_DEMO_PASSWORD"] { password = pw }
                #endif
            }
        }
        .presentationDetents([.large])
    }

    private func submit() async {
        guard valid, !working else { return }
        working = true
        defer { working = false }
        do {
            try await model.signIn(email: identity, password: password)
        } catch {
            let m = error.localizedDescription
            status = m.contains("Невірні облікові дані") ? "Пароль або логін не підходять. Перевірте або відновіть пароль." : m
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
    }
}

/// Реєстрація кроками: одне питання на екран, велике поле, «Далі».
struct SignUpFlow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var name = ""
    @State private var phone = "+380"
    @State private var email = ""
    @State private var password = ""
    @State private var status: String?
    @State private var working = false
    @FocusState private var focused: Bool

    private let steps = 4

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    ForEach(0..<steps, id: \.self) { i in
                        Capsule().fill(i <= step ? Theme.ink : Theme.line).frame(height: 4)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
                .padding(.top, 4)

                Text(question).font(.system(size: 32, weight: .bold)).tracking(-1)
                    .padding(.top, 28)
                    .id("q\(step)")
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                Text(hint).font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)

                Group {
                    switch step {
                    case 0: bigField("Олена Коваленко", $name, .name)
                    case 1: bigField("+380 …", $phone, .telephoneNumber, keyboard: .phonePad)
                    case 2: bigField("you@example.com", $email, .emailAddress, keyboard: .emailAddress, plain: true)
                    default:
                        VStack(alignment: .leading, spacing: 14) {
                            SecureField("Щонайменше 8 символів", text: $password)
                                .textContentType(.newPassword)
                                .font(.system(size: 24, weight: .semibold))
                                .focused($focused)
                                .padding(.vertical, 10)
                                .overlay(alignment: .bottom) { Rectangle().fill(focused ? Theme.ink : Theme.line).frame(height: 2) }
                            if !password.isEmpty { PasswordStrength(password: password) }
                        }
                    }
                }
                .padding(.top, 26)

                if let status {
                    Label(status, systemImage: "exclamationmark.circle").font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.ink.opacity(0.07), in: .rect(cornerRadius: 14, style: .continuous))
                        .padding(.top, 16)
                }

                Spacer()

                if step == steps - 1 {
                    Text("Створюючи акаунт, ви погоджуєтеся, що це навчальний банк: токени TAX не мають грошової цінності.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 12)
                }
                Button { Task { await next() } } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(Theme.onAccent) }
                        Text(step == steps - 1 ? "Створити акаунт" : "Далі")
                    }
                }
                .buttonStyle(InkButton())
                .disabled(!stepValid || working)
            }
            .padding(24)
            .screenBackground()
            .animation(.smooth(duration: 0.3), value: step)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { if step > 0 { step -= 1; status = nil } else { dismiss() } } label: {
                        Image(systemName: step > 0 ? "chevron.left" : "xmark")
                    }
                    .accessibilityLabel(step > 0 ? "Назад" : "Закрити")
                }
            }
            .onAppear { focused = true }
            .onChange(of: step) { focused = true }
            .sensoryFeedback(.selection, trigger: step)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(working)
    }

    private var question: String {
        ["Як вас звати?", "Ваш номер телефону", "Пошта для входу", "Придумайте пароль"][step]
    }

    private var hint: String {
        ["Так звертатимемося в застосунку й підписуватимемо картки.",
         "Ним теж можна входити. SMS не надсилаємо.",
         "Нею входитимете й відновлюватимете пароль.",
         "Довгий пароль із цифрами й символами - найкращий."][step]
    }

    private var stepValid: Bool {
        switch step {
        case 0: name.trimmingCharacters(in: .whitespaces).count >= 2
        case 1: phone.filter(\.isNumber).count >= 12
        case 2:
            email.split(separator: "@").count == 2 && (email.split(separator: "@").last?.contains(".") ?? false) && !email.contains(" ")
        default: password.count >= 8
        }
    }

    private func bigField(_ placeholder: String, _ text: Binding<String>, _ content: UITextContentType,
                          keyboard: UIKeyboardType = .default, plain: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(plain ? .never : .words)
            .autocorrectionDisabled(plain)
            .font(.system(size: 24, weight: .semibold))
            .focused($focused)
            .submitLabel(.next)
            .onSubmit { Task { await next() } }
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(focused ? Theme.ink : Theme.line).frame(height: 2) }
    }

    private func next() async {
        guard stepValid, !working else { return }
        status = nil
        if step < steps - 1 { step += 1; return }
        working = true
        defer { working = false }
        do {
            try await model.register(name: name.trimmingCharacters(in: .whitespaces), phone: phone, email: email, password: password)
        } catch {
            status = error.localizedDescription
        }
    }
}

/// Адреса навчального сервера: окремий аркуш замість поля на головному екрані.
struct ServerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var server = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Сервер").font(.system(size: 30, weight: .bold)).tracking(-0.8)
                Text("Застосунок працює з навчальним банком. За замовчуванням - публічний сервер; для занять у класі вкажіть адресу локального.")
                    .font(.subheadline).foregroundStyle(.secondary)
                TextField("https://…", text: $server)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .background(Theme.surface, in: .rect(cornerRadius: 16, style: .continuous))
                    .onSubmit(save)
                Button("Зберегти", action: save).buttonStyle(InkButton())
                Button("Повернути стандартний") { server = AppModel.defaultServer.absoluteString; save() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(24)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрити") { dismiss() } } }
            .onAppear { server = model.serverURL.absoluteString }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        if let url = URL(string: server.trimmingCharacters(in: .whitespaces)), url.scheme != nil, AppModel.reachable(url) {
            model.serverURL = url
            dismiss()
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
                        .font(.display(30)).tracking(-0.8)
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
