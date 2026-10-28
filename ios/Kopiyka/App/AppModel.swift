import EdgeRouter
import Foundation
import Observation
import Security

/// Спільний стан застосунку: маршрутизатор, адреса навчального сервера, сесія, журнал для «Лабораторії».
@MainActor @Observable
final class AppModel {
    let router: EdgeRouter
    private let contextProvider = LiveContextProvider()

    var serverURL: URL {
        didSet { UserDefaults.standard.set(serverURL.absoluteString, forKey: "serverURL") }
    }
    private(set) var token: String? = Keychain.read("sandboxToken")
    private(set) var snapshot = RouterSnapshot()
    private(set) var decisions: [DecisionRecord] = []
    private(set) var feedback: [UUID: Bool] = [:]
    private(set) var context = DeviceContext()

    /// У симуляторі сервер на цьому ж Mac; на телефоні - навчальний банк на VPS.
    static var defaultServer: URL {
        #if targetEnvironment(simulator)
        URL(string: "http://localhost:5050")!
        #else
        URL(string: "https://bank.munister.com.ua")!
        #endif
    }

    var api: API { API(baseURL: serverURL, token: token) }
    /// Банк відкрито кодом у цьому сеансі; скидається, коли застосунок іде у фон.
    var bankUnlocked = false
    var signedIn: Bool { token != nil }

    /// Згода надсилати текст (уже без особистих даних) мовній моделі на сервері.
    /// Правило App Store 5.1.2: передачу даних сторонньому ІІ треба пояснити й отримати дозвіл.
    var cloudAIAllowed: Bool = UserDefaults.standard.bool(forKey: "cloudAIAllowed") {
        didSet { UserDefaults.standard.set(cloudAIAllowed, forKey: "cloudAIAllowed") }
    }
    /// Відмикати банк Face ID / Touch ID замість PIN.
    var biometricsEnabled: Bool = UserDefaults.standard.bool(forKey: "biometricsEnabled") {
        didSet { UserDefaults.standard.set(biometricsEnabled, forKey: "biometricsEnabled") }
    }
    /// Останній телефон чи пошта, з якими входили: підставляємо на екрані входу.
    var lastIdentity: String = UserDefaults.standard.string(forKey: "lastIdentity") ?? "" {
        didSet { UserDefaults.standard.set(lastIdentity, forKey: "lastIdentity") }
    }

    var consentAsked: Bool = UserDefaults.standard.bool(forKey: "consentAsked") {
        didSet { UserDefaults.standard.set(consentAsked, forKey: "consentAsked") }
    }

    /// Сервер для мовної моделі - лише зі згодою і після входу (ендпоінт захищений сесією банку).
    var cloudAI: API? { cloudAIAllowed && signedIn ? api : nil }

    init() {
        let dir = URL.applicationSupportDirectory.appending(path: "EdgeRouter")
        let provider = contextProvider
        router = EdgeRouter(directory: dir) { await provider.snapshot() }
        let saved = UserDefaults.standard.string(forKey: "serverURL").flatMap(URL.init(string:))
        serverURL = saved.flatMap { Self.reachable($0) ? $0 : nil } ?? Self.defaultServer
    }

    /// Чи має сенс збережена адреса. На телефоні localhost, 127.0.0.1 і Mac у домашній мережі (.local)
    /// лишилися від старих збірок: телефон шукав би сервер сам у собі.
    static func reachable(_ url: URL) -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let host = url.host() ?? ""
        return !(host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".local"))
        #endif
    }

    func signIn(email: String, password: String) async throws {
        adopt(try await api.login(email: email, password: password))
        lastIdentity = email.trimmingCharacters(in: .whitespaces)
    }

    func register(name: String, phone: String, email: String, password: String) async throws {
        adopt(try await api.register(name: name, phone: phone, email: email, password: password))
        lastIdentity = email.trimmingCharacters(in: .whitespaces)
    }

    func signInWithApple(identityToken: String, nonce: String, fullName: String?) async throws {
        adopt(try await api.appleLogin(identityToken: identityToken, nonce: nonce, fullName: fullName))
    }

    /// Новий пароль за кодом: сервер закриває всі старі сесії й одразу відкриває нову.
    func resetPassword(_ ticket: API.ResetTicket, code: String, newPassword: String) async throws {
        adopt(try await api.resetPassword(ticket, code: code, newPassword: newPassword))
    }

    private func adopt(_ session: API.Session) {
        token = session.token
        Keychain.write("sandboxToken", session.token)
    }

    func deleteAccount() async throws {
        try await api.deleteAccount()
        signOut()
    }

    func signOut() {
        token = nil
        bankUnlocked = false
        Keychain.write("sandboxToken", nil)
    }

    func run<Input: Sendable, Output: Sendable>(
        _ task: TaskProfile, input: Input, executors: Executors<Input, Output>
    ) async throws -> Routed<Output> {
        defer { Task { await refresh() } }
        return try await router.run(task, input: input, executors: executors)
    }

    func feedback(_ id: UUID, correct: Bool) async {
        await router.feedback(id, correct: correct)
        await refresh()
    }

    func configure(_ change: @escaping @Sendable (inout RouterSnapshot) -> Void) async {
        await router.update(change)
        await refresh()
    }

    func refresh() async {
        snapshot = await router.snapshot
        context = await router.currentContext()
        (decisions, feedback) = await router.telemetry.load()
    }

    func resetLearning() async {
        await router.resetLearning()
        await router.telemetry.clear()
        await refresh()
    }
}

/// Токен навчального банку - у Keychain, як у справжньому застосунку.
enum Keychain {
    static func read(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key,
                                kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, _ value: String?) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
        guard let value else { return }
        var add = q
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
