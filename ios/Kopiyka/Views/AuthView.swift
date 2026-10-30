import AuthenticationServices
import CryptoKit
import SwiftUI

/// Вітальний екран: живий стос карток, сильний заголовок і три шляхи - Apple, вхід, новий акаунт.
/// Форми не тут: вхід відкривається аркушем, реєстрація - кроками по одному питанню.
struct AuthView: View {
    @Environment(AppModel.self) private var model
    @State private var status: String?
    @State private var working = false
    @State private var nonce = ""
    @State private var signingIn = false
    @State private var signingUp = false
    @State private var server = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                MarkView(height: 26, color: .white)
                (Text("Tax").fontWeight(.medium) + Text("Tech").fontWeight(.light))
                    .font(.custom("Futura-Medium", size: 22)).tracking(0.6).foregroundStyle(.white)
                Spacer()
                Menu {
                    ForEach(Lang.allCases) { l in
                        Button { Lang.set(l) } label: { Label(l.title, systemImage: Lang.current == l ? "checkmark" : "") }
                    }
                } label: {
                    Text(Lang.current.rawValue.uppercased())
                        .font(.system(size: 13, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 12).frame(height: 32)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                }
                .accessibilityLabel(L("Мова").s)
                Button { server = true } label: {
                    Image(systemName: "network").font(.system(size: 16, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Адреса сервера").s)
            }
            .padding(.top, 4)
            .rise(0)

            Spacer(minLength: 0)

            WelcomeCard()
                .frame(maxWidth: .infinity)
                .rise(1)

            VStack(alignment: .leading, spacing: 0) {
                Text(L("Платіть,").s)
                    .foregroundStyle(.white)
                Text(L("як у Римі.").s)
                    .foregroundStyle(Theme.goldFill)
            }
            .font(.system(size: 44, weight: .medium)).tracking(-1)
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.top, 30)
            .rise(2)

            if let status {
                Label(status, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
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
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(.capsule)
                .disabled(working)

                Button(L("Увійти телефоном або поштою").s) { signingIn = true }
                    .buttonStyle(InkButton())

                Button { signingUp = true } label: {
                    (Text(L("Немає акаунта? ").s).foregroundStyle(.white.opacity(0.6)) + Text(L("Створити").s).fontWeight(.semibold).foregroundStyle(Theme.goldLight))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
            .rise(4)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .background { WelcomeBackdrop() }
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
                status = L("Apple не віддала токен входу.").s
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
                status = L("Сервер не прийняв вхід через Apple: \(error.localizedDescription)").s
            }
        }
    }

    /// Людське пояснення, чому Apple не пустила; nil - користувач сам закрив вікно.
    private static func appleMessage(_ error: Error) -> String? {
        guard let e = error as? ASAuthorizationError else { return "Apple: \(error.localizedDescription)" }
        switch e.code {
        case .canceled: return nil
        case .unknown:
            return L("Apple не відповіла (код 1000). Перевірте, що в Параметрах виконано вхід в Apple ID з двоетапною перевіркою, і спробуйте ще раз.").s
        case .notInteractive: return L("Apple не змогла показати вікно входу. Спробуйте ще раз.").s
        case .failed, .invalidResponse, .notHandled:
            return L("Apple не завершила вхід (код \(e.code.rawValue)). Спробуйте ще раз або увійдіть поштою.").s
        default: return L("Apple: код \(e.code.rawValue). \(e.localizedDescription)").s
        }
    }

    private static func randomNonce() -> String {
        (0..<32).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }

    private static func sha256(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Одна пряма чорна картка із золотим гільйошем: без нахилу й поворотів, лише ковзний золотий відблиск.
struct WelcomeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    private let look = CardLook(material: .solid, color: .black, pattern: .guilloche)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { tl in
            let t = reduce ? 0.5 : (tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5.5) / 5.5)
            VirtualCardView(number: "•••• 2048", expiry: "09/29", holder: nil, design: .gold, look: look)
                .background(.black, in: shape)
                .overlay {
                    // золотий відблиск проходить картку зліва направо й зникає
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Theme.goldLight.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.35)
                            .rotationEffect(.degrees(18))
                            .offset(x: -g.size.width * 0.4 + g.size.width * 1.5 * t)
                            .blendMode(.plusLighter)
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
                .overlay(shape.strokeBorder(Theme.edge, lineWidth: 1.2))
                .shadow(color: Theme.accent.opacity(0.22), radius: 46, y: 6)
                .shadow(color: .black.opacity(0.7), radius: 24, y: 18)
        }
        .frame(width: 304)
    }
}

/// Тло вітання: римське фото під затемненням, розетка гільйошу, золоте сяйво зверху.
struct WelcomeBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.015)
            GeometryReader { g in
                Image("RomeHero").resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height * 0.62, alignment: .top)
                    .clipped()
                    .saturation(0.55)
                    .opacity(0.5)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width * 0.5, y: size.height * 0.30)
                    Engraving.rosette(in: &ctx, center: c, radius: size.width * 0.78, curves: 28, lobes: 8, depth: 0.2, second: 0.06,
                                      steps: 240, color: Theme.goldLight.opacity(0.10), width: 0.4)
                    Engraving.rings(in: &ctx, center: c, from: size.width * 0.74, to: size.width * 0.77, count: 3, color: Theme.goldLight.opacity(0.14))
                    // медальйон за карткою: подвійне кільце й шкала, як на римській монеті
                    let m = CGPoint(x: size.width * 0.5, y: size.height * 0.455)
                    let R = size.width * 0.56
                    for (r, w, o) in [(R, 1.2, 0.5), (R * 0.965, 0.5, 0.35), (R * 0.78, 0.5, 0.22)] as [(CGFloat, CGFloat, Double)] {
                        ctx.stroke(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: r * 2, height: r * 2)),
                                   with: .color(Theme.goldLight.opacity(o)), lineWidth: w)
                    }
                    for i in 0..<120 {
                        let a = Double(i) / 120 * .pi * 2, long = i % 10 == 0
                        var p = Path()
                        p.move(to: CGPoint(x: m.x + R * 0.965 * cos(a), y: m.y + R * 0.965 * sin(a)))
                        p.addLine(to: CGPoint(x: m.x + R * (long ? 0.915 : 0.94) * cos(a), y: m.y + R * (long ? 0.915 : 0.94) * sin(a)))
                        ctx.stroke(p, with: .color(Theme.goldLight.opacity(long ? 0.5 : 0.28)), lineWidth: long ? 1 : 0.5)
                    }
                }
                RadialGradient(colors: [Theme.accent.opacity(0.16), .clear], center: .init(x: 0.5, y: 0.46), startRadius: 0, endRadius: 360)
            }
            LinearGradient(colors: [.clear, Color(red: 0.02, green: 0.02, blue: 0.015).opacity(0.85), Color(red: 0.02, green: 0.02, blue: 0.015)],
                           startPoint: .init(x: 0.5, y: 0.35), endPoint: .init(x: 0.5, y: 0.7))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Тло аркушів входу: чорне, золота розетка гільйошу в кутку, мʼяке сяйво й римське фото під затемненням.
struct SheetBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.015)
            Image("RomeHero").resizable().scaledToFill()
                .frame(height: 260, alignment: .top).clipped()
                .saturation(0.5).opacity(0.28)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .frame(maxHeight: .infinity, alignment: .top)
            Canvas { ctx, size in
                let c = CGPoint(x: size.width * 0.92, y: size.height * 0.1)
                Engraving.rosette(in: &ctx, center: c, radius: size.width * 0.8, curves: 26, lobes: 8, depth: 0.2, second: 0.06,
                                  steps: 220, color: Theme.goldLight.opacity(0.13), width: 0.4)
                Engraving.rings(in: &ctx, center: c, from: size.width * 0.74, to: size.width * 0.77, count: 3, color: Theme.goldLight.opacity(0.16))
            }
            RadialGradient(colors: [Theme.accent.opacity(0.14), .clear], center: .init(x: 0.9, y: 0.06), startRadius: 0, endRadius: 320)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
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
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 10) {
                        MarkView(height: 24, color: Theme.accent)
                        (Text("Tax").fontWeight(.medium) + Text("Tech").fontWeight(.light))
                            .font(.custom("Futura-Medium", size: 20)).tracking(0.6).foregroundStyle(.white)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.08), in: .circle)
                                .overlay(Circle().strokeBorder(Theme.edge, lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("Закрити").s)
                    }
                    .rise(0)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(L("З поверненням").s).foregroundStyle(.white)
                        Text(L("у Рим.").s).foregroundStyle(Theme.goldFill)
                    }
                    .font(.system(size: 42, weight: .medium)).tracking(-1)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .padding(.top, 18).padding(.bottom, 6)
                    .rise(1)

                    VStack(alignment: .leading, spacing: 16) {
                        AuthField(title: L("Телефон або пошта").s, placeholder: L("+380… або you@example.com").s, text: $identity,
                                  content: .username, keyboard: .emailAddress, plain: true)
                        VStack(alignment: .leading, spacing: 12) {
                            AuthField(title: L("Пароль").s, placeholder: L("Пароль").s, text: $password, secure: true,
                                      content: .password, submit: .go) { Task { await submit() } }
                            Button(L("Забули пароль?").s) { forgot = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .rise(2)

                    if let status {
                        Label(status, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(Color(red: 1, green: 0.62, blue: 0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(red: 1, green: 0.4, blue: 0.3).opacity(0.1), in: .rect(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color(red: 1, green: 0.4, blue: 0.3).opacity(0.35), lineWidth: 0.8))
                            .modifier(Shake(animatableData: CGFloat(shakes)))
                    }
                    Button { Task { await submit() } } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView().tint(Theme.onAccent) }
                            Text(L("Увійти").s)
                        }
                    }
                    .buttonStyle(InkButton())
                    .disabled(!valid || working)
                    .padding(.top, 4)
                    .rise(3)
                }
                .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { SheetBackdrop() }
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.error, trigger: shakes)
            .sheet(isPresented: $forgot) { ForgotPasswordView(identity: identity) }
            .onAppear {
                if identity.isEmpty { identity = model.lastIdentity }
                #if DEBUG
                let env = ProcessInfo.processInfo.environment
                if let id = env["KOPIYKA_DEMO_IDENTITY"] { identity = id }
                if password.isEmpty, let pw = env["KOPIYKA_DEMO_PASSWORD"] { password = pw }
                #endif
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Color(red: 0.02, green: 0.02, blue: 0.015))
        .presentationCornerRadius(34)
        .presentationDragIndicator(.hidden)
    }

    private func submit() async {
        guard valid, !working else { return }
        working = true
        defer { working = false }
        do {
            try await model.signIn(email: identity, password: password)
        } catch {
            let m = error.localizedDescription
            status = m.contains("Невірні облікові дані") ? L("Пароль або логін не підходять. Перевірте або відновіть пароль.").s : m
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
                    case 0: bigField(L("Олена Коваленко").s, $name, .name)
                    case 1: bigField("+380 …", $phone, .telephoneNumber, keyboard: .phonePad)
                    case 2: bigField("you@example.com", $email, .emailAddress, keyboard: .emailAddress, plain: true)
                    default:
                        VStack(alignment: .leading, spacing: 14) {
                            SecureField(L("Щонайменше 8 символів").s, text: $password)
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
                    Text(L("Створюючи акаунт, ви погоджуєтеся, що це навчальний банк: токени TAX не мають грошової цінності.").s)
                        .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 12)
                }
                Button { Task { await next() } } label: {
                    HStack(spacing: 8) {
                        if working { ProgressView().tint(Theme.onAccent) }
                        Text(step == steps - 1 ? L("Створити акаунт").s : L("Далі").s)
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
                    .accessibilityLabel(step > 0 ? L("Назад").s : L("Закрити").s)
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
        [L("Як вас звати?").s, L("Ваш номер телефону").s, L("Пошта для входу").s, L("Придумайте пароль").s][step]
    }

    private var hint: String {
        [L("Так звертатимемося в застосунку й підписуватимемо картки.").s,
         L("Ним теж можна входити. SMS не надсилаємо.").s,
         L("Нею входитимете й відновлюватимете пароль.").s,
         L("Довгий пароль із цифрами й символами - найкращий.").s][step]
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
                Text(L("Сервер").s).font(.system(size: 30, weight: .bold)).tracking(-0.8)
                Text(L("Застосунок працює з навчальним банком. За замовчуванням - публічний сервер; для занять у класі вкажіть адресу локального.").s)
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
                Button(L("Зберегти").s, action: save).buttonStyle(InkButton())
                Button(L("Повернути стандартний").s) { server = AppModel.defaultServer.absoluteString; save() }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
            .padding(24)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Закрити").s) { dismiss() } } }
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
            Text(title).caption()
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
                    .accessibilityLabel(reveal ? L("Сховати пароль").s : L("Показати пароль").s)
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, secure ? 8 : 16)
            .frame(minHeight: 54)
            .background(Theme.surface.opacity(0.9), in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(focused ? AnyShapeStyle(Theme.accent) : (hint != nil ? AnyShapeStyle(Theme.accent.opacity(0.5)) : AnyShapeStyle(Theme.edge)),
                                  lineWidth: focused ? 1.4 : 0.9)
            )
            .shadow(color: focused ? Theme.accent.opacity(0.25) : .clear, radius: 12)
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
            (L("8+ символів").s, password.count >= 8),
            (L("Літери й цифри").s, password.rangeOfCharacter(from: .letters) != nil && password.rangeOfCharacter(from: .decimalDigits) != nil),
            (L("Великі й малі").s, password.rangeOfCharacter(from: .uppercaseLetters) != nil && password.rangeOfCharacter(from: .lowercaseLetters) != nil),
            (L("Спецсимвол").s, password.rangeOfCharacter(from: CharacterSet.alphanumerics.union(.whitespaces).inverted) != nil),
        ]
    }

    private var score: Int {
        guard password.count >= 8 else { return password.isEmpty ? 0 : 1 }
        return min(4, rules.filter(\.1).count + (password.count >= 12 ? 1 : 0))
    }

    private var label: String {
        ["", L("Слабкий").s, L("Середній").s, L("Надійний").s, L("Дуже надійний").s][score]
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
                    Text(ticket == nil ? L("Відновлення пароля").s : L("Новий пароль").s)
                        .font(.display(30)).tracking(-0.8)
                    if let ticket {
                        Text(ticket.demoCode == nil ? L("Код надіслано на \(ticket.sentTo). Він діє \(ticket.expiresIn / 60) хвилин.").s
                                                    : L("Код для \(ticket.sentTo) діє \(ticket.expiresIn / 60) хвилин.").s)
                            .foregroundStyle(.secondary)
                        if let demo = ticket.demoCode {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("Навчальний банк: SMS не надсилаємо").s).font(.footnote).foregroundStyle(.secondary)
                                    Text(demo).font(.system(size: 24, weight: .bold).monospaced()).tracking(4)
                                }
                                Spacer()
                                Button(L("Вставити").s) { code = demo }
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
                            Text(L("Код із 6 цифр").s).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
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
                            AuthField(title: L("Новий пароль").s, placeholder: L("Щонайменше 8 символів").s, text: $newPassword,
                                      secure: true, content: .newPassword, submit: .done) { Task { await reset() } }
                            if !newPassword.isEmpty { PasswordStrength(password: newPassword) }
                        }
                        Button(L("Змінити пароль і увійти").s) { Task { await reset() } }
                            .buttonStyle(InkButton())
                            .disabled(code.count != 6 || newPassword.count < 8 || screen.busy)
                        HStack {
                            Text(left > 0 ? String(format: L("Повторно через %d:%02d").s, left / 60, left % 60) : L("Код не прийшов?").s)
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                            Spacer()
                            Button(L("Надіслати ще раз").s) { Task { await request() } }
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .disabled(left > 0 || screen.busy)
                        }
                    } else {
                        Text(L("Вкажіть телефон або пошту акаунта. Надішлемо код, після нього задасте новий пароль, а всі старі сесії буде завершено.").s)
                            .foregroundStyle(.secondary)
                        AuthField(title: L("Телефон або пошта").s, placeholder: L("+380… або you@example.com").s, text: $identity,
                                  content: .username, keyboard: .emailAddress, plain: true, submit: .send) { Task { await request() } }
                        Button(L("Надіслати код").s) { Task { await request() } }
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
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
