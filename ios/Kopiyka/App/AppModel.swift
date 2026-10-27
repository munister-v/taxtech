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
    var signedIn: Bool { token != nil }

    /// Згода надсилати текст (уже без особистих даних) мовній моделі на сервері.
    /// Правило App Store 5.1.2: передачу даних сторонньому ІІ треба пояснити й отримати дозвіл.
    var cloudAIAllowed: Bool = UserDefaults.standard.bool(forKey: "cloudAIAllowed") {
        didSet { UserDefaults.standard.set(cloudAIAllowed, forKey: "cloudAIAllowed") }
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
        // адреса Mac у домашній мережі, збережена старими збірками, на телефоні вже не потрібна
        serverURL = saved.flatMap { $0.host()?.hasSuffix(".local") == true ? nil : $0 } ?? Self.defaultServer
    }

    func signIn(email: String, password: String) async throws {
        let session = try await api.login(email: email, password: password)
        token = session.token
        Keychain.write("sandboxToken", session.token)
    }

    func signInWithApple(identityToken: String, nonce: String, fullName: String?) async throws {
        let session = try await api.appleLogin(identityToken: identityToken, nonce: nonce, fullName: fullName)
        token = session.token
        Keychain.write("sandboxToken", session.token)
    }

    func deleteAccount() async throws {
        try await api.deleteAccount()
        signOut()
    }

    func signOut() {
        token = nil
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
