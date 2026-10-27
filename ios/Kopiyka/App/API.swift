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
    private struct Wrapped<T: Decodable>: Decodable { let data: T }

    func login(email: String, password: String) async throws -> Session {
        let w: Wrapped<Session> = try await post("auth/login", json: ["identity": email, "password": password])
        return w.data
    }

    // MARK: Транспорт

    private func request(_ path: String, method: String) -> URLRequest {
        var r = URLRequest(url: baseURL.appending(path: "api").appending(path: path))
        r.httpMethod = method
        r.timeoutInterval = 15
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return r
    }

    private func post<T: Decodable>(_ path: String, json: [String: Any]) async throws -> T {
        var r = request(path, method: "POST")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: json)
        return try await send(r)
    }

    private func send<T: Decodable>(_ r: URLRequest) async throws -> T {
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
