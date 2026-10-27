import Foundation

/// Клієнт навчального сервера (`server/`). Значення, а не клас: його копію безпечно
/// захоплюють виконавці EdgeRouter, що працюють поза головним потоком.
struct API: Sendable {
    var baseURL: URL
    var token: String?

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: Дослідницькі виклики

    struct FraudScore: Decodable, Sendable {
        let score: Int
        let level: String
        let flags: [String]
        let layersRun: [String]?
        let serverMs: Double?
    }

    func fraudScore(amount: Double, balance: Double, description: String, recipient: String?) async throws -> FraudScore {
        var body: [String: Any] = ["amount": amount, "balance": balance, "description": description]
        if let recipient { body["recipient_account"] = recipient }
        return try await post("research/fraud/score", json: body)
    }

    struct LLMReply: Decodable, Sendable {
        let text: String
        let model: String
        let inputTokens: Int?
        let outputTokens: Int?
        let serverMs: Double?
    }

    enum Tier: String { case small, large }

    func llm(task: String, prompt: String, tier: Tier = .small) async throws -> LLMReply {
        try await post("research/llm", json: ["task": task, "prompt": prompt, "tier": tier.rawValue])
    }

    struct Ping: Decodable, Sendable { let serverTime: String? }

    func ping() async throws -> Ping {
        try await send(request("research/ping", method: "GET"))
    }

    // MARK: Навчальний банк

    struct Session: Decodable, Sendable { let token: String }
    struct Wrapped<T: Decodable>: Decodable { let data: T }

    func login(email: String, password: String) async throws -> Session {
        let w: Wrapped<Session> = try await post("auth/login", json: ["identity": email, "password": password])
        return w.data
    }

    /// Вхід або реєстрація через Apple: токен Apple + «сирий» nonce (в токені лежить його SHA-256).
    func appleLogin(identityToken: String, nonce: String, fullName: String?) async throws -> Session {
        var body: [String: Any] = ["identity_token": identityToken, "nonce": nonce]
        if let fullName, !fullName.isEmpty { body["full_name"] = fullName }
        let w: Wrapped<Session> = try await post("auth/apple", json: body)
        return w.data
    }

    /// Назавжди видаляє акаунт і всі його дані на сервері.
    func deleteAccount() async throws {
        let _: Ignored = try await send(request("auth/account", method: "DELETE"))
    }

    struct Account: Decodable, Sendable {
        let accountNumber: String
        let balance: Double
    }

    struct Transaction: Decodable, Sendable, Identifiable {
        let id: Int
        let amount: Double
        let direction: String
        let txType: String
        let description: String?
        let relatedAccount: String?
        let createdAt: String
        let note: String?
        /// Хеш запису: ланка хеш-ланцюга рахунку або відбиток полів операції.
        let hash: String?

        var isIncome: Bool { direction == "in" }
        /// Сервер пише час у UTC без зони: «2026-10-26 06:48:41».
        var date: Date {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return f.date(from: String(createdAt.prefix(19))) ?? .distantPast
        }
    }

    struct Card: Decodable, Sendable, Identifiable {
        let id: Int
        let maskedNumber: String
        let expiryDisplay: String?
        let holderName: String?
        let status: String
        let design: String?
        let cardType: String?
        let isPrimary: Bool
        let displayBalance: Double?

        var isBlocked: Bool { status == "blocked" }
        var isClosed: Bool { status == "closed" }

        enum CodingKeys: String, CodingKey {
            case id, maskedNumber, expiryDisplay, holderName, status, design, cardType, isPrimary, displayBalance
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            maskedNumber = try c.decode(String.self, forKey: .maskedNumber)
            expiryDisplay = try c.decodeIfPresent(String.self, forKey: .expiryDisplay)
            holderName = try c.decodeIfPresent(String.self, forKey: .holderName)
            status = try c.decode(String.self, forKey: .status)
            design = try c.decodeIfPresent(String.self, forKey: .design)
            cardType = try c.decodeIfPresent(String.self, forKey: .cardType)
            displayBalance = try c.decodeIfPresent(Double.self, forKey: .displayBalance)
            // сервер віддає то true, то 0/1
            if let flag = try? c.decode(Bool.self, forKey: .isPrimary) {
                isPrimary = flag
            } else {
                isPrimary = ((try? c.decode(Int.self, forKey: .isPrimary)) ?? 0) != 0
            }
        }
    }

    func setCardDesign(_ id: Int, _ design: String) async throws {
        var r = request("cards/\(id)/design", method: "PATCH")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["design": design])
        let _: Wrapped<Card> = try await send(r)
    }

    func account() async throws -> Account {
        let w: Wrapped<Account> = try await send(request("accounts/main", method: "GET"))
        return w.data
    }

    func history() async throws -> [Transaction] {
        let w: Wrapped<[Transaction]> = try await send(request("transactions/history", method: "GET"))
        return w.data
    }

    func cards() async throws -> [Card] {
        let w: Wrapped<[Card]> = try await send(request("cards", method: "GET"))
        return w.data
    }

    /// Заморозити або розморозити - той самий виклик перемикає стан.
    func toggleCardBlock(_ id: Int) async throws {
        var r = request("cards/\(id)/block", method: "PATCH")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = Data("{}".utf8)
        let _: Wrapped<Card> = try await send(r)
    }

    /// Гроші віртуальні; ключ ідемпотентності - щоб повтор після обриву мережі не зарахував двічі.
    func topUp(_ amount: Double) async throws -> Account {
        let w: Wrapped<Account> = try await post("transactions/topup", json: ["amount": amount],
                                                 idempotencyKey: UUID().uuidString)
        return w.data
    }

    /// Сервер банку сам перевіряє переказ повним антифродом і може відмовити.
    func transfer(_ amount: Double, to recipient: String, description: String) async throws -> Account {
        let w: Wrapped<Account> = try await post(
            "transactions/transfer",
            json: ["amount": amount, "recipient_account_number": recipient, "description": description],
            idempotencyKey: UUID().uuidString)
        return w.data
    }

    // MARK: Транспорт

    func request(_ path: String, method: String) -> URLRequest {
        // «?» у шляху не можна віддавати в appending(path:) - він його закодує
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        var url = baseURL.appending(path: "api").appending(path: parts[0])
        if parts.count > 1, var c = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            c.percentEncodedQuery = parts[1]
            url = c.url ?? url
        }
        var r = URLRequest(url: url)
        r.httpMethod = method
        r.timeoutInterval = 15
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return r
    }

    func post<T: Decodable>(_ path: String, json: [String: Any], idempotencyKey: String? = nil) async throws -> T {
        var r = request(path, method: "POST")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey { r.setValue(idempotencyKey, forHTTPHeaderField: "Idempotency-Key") }
        r.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await send(r)
    }

    func send<T: Decodable>(_ r: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: r)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? String) ?? ($0["message"] as? String) }
            throw Failure(message: message ?? "Сервер відповів кодом \(status)")
        }
        return try decoder.decode(T.self, from: data)
    }
}
