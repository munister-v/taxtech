import Foundation

/// Решта функцій банку: донати, виплати, борги, сповіщення, PIN, профіль і сесії, виписки.
extension API {
    // MARK: Моделі

    struct Donation: Decodable, Sendable, Identifiable {
        let id: Int
        let fundName: String
        let amount: Double
        let comment: String?
        let createdAt: String
    }

    struct Payout: Decodable, Sendable, Identifiable {
        let id: Int
        let title: String
        let amount: Double
        let payoutType: String?
        let createdAt: String
    }

    struct Debt: Decodable, Sendable, Identifiable {
        let id: Int
        let contactName: String
        let amount: Double
        let direction: String
        let description: String?
        let isSettled: Bool
        let createdAt: String

        var owedToMe: Bool { direction == "owed_to_me" }

        enum CodingKeys: String, CodingKey { case id, contactName, amount, direction, description, isSettled, createdAt }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(Int.self, forKey: .id)
            contactName = try c.decode(String.self, forKey: .contactName)
            amount = try c.decode(Double.self, forKey: .amount)
            direction = try c.decode(String.self, forKey: .direction)
            description = try c.decodeIfPresent(String.self, forKey: .description)
            createdAt = try c.decode(String.self, forKey: .createdAt)
            // SQLite віддає 0/1, Postgres - true/false
            isSettled = (try? c.decode(Bool.self, forKey: .isSettled)) ?? ((try? c.decode(Int.self, forKey: .isSettled)) ?? 0 != 0)
        }
    }

    struct Notice: Decodable, Sendable, Identifiable {
        let id: Int
        let title: String
        let body: String?
        let type: String?
        let isRead: Bool
        let createdAt: String
    }

    struct Velocity: Decodable, Sendable {
        let avgDailySpend: Double
        let balance: Double
        let daysUntilZero: Int?
        let totalOut30d: Double?
    }

    struct Recipient: Decodable, Sendable, Identifiable {
        let relatedAccount: String
        let totalSent: Double
        let txCount: Int
        var id: String { relatedAccount }
    }

    struct Me: Decodable, Sendable {
        let fullName: String
        let email: String?
        let phone: String?
        let bankAccountNumber: String?
    }

    struct Device: Decodable, Sendable, Identifiable {
        let id: Int
        let authMethod: String?
        let createdAt: String
        let lastSeenAt: String?
        let ipAddress: String?
        let userAgent: String?
        let isCurrent: Bool
    }

    private struct Count: Decodable { let count: Int }
    private struct PinState: Decodable { let hasPin: Bool }

    // MARK: Донати й виплати

    func donations() async throws -> [Donation] { try await get("donations") }
    func donate(fund: String, amount: Double, comment: String) async throws {
        try await write("POST", "donations", ["fund_name": fund, "amount": amount, "comment": comment])
    }

    func payouts() async throws -> [Payout] { try await get("payouts") }
    func accruePayout(title: String, amount: Double, type: String) async throws {
        try await write("POST", "payouts/demo-accrual", ["title": title, "amount": amount, "payout_type": type])
    }

    // MARK: Борги

    func debts() async throws -> [Debt] { try await get("debts") }
    func addDebt(name: String, amount: Double, owedToMe: Bool, note: String) async throws {
        try await write("POST", "debts", ["contact_name": name, "amount": amount,
                                          "direction": owedToMe ? "owed_to_me" : "i_owe", "description": note])
    }
    func settleDebt(_ id: Int) async throws { try await write("POST", "debts/\(id)/settle", [:]) }
    func deleteDebt(_ id: Int) async throws { try await write("DELETE", "debts/\(id)", nil) }

    // MARK: Сповіщення

    func notices() async throws -> [Notice] { try await get("notifications") }
    func unreadCount() async throws -> Int { (try await get("notifications/unread-count") as Count).count }
    func readAll() async throws { try await write("POST", "notifications/read-all", [:]) }

    // MARK: Аналітика

    func velocity() async throws -> Velocity { try await get("analytics/velocity") }
    func topRecipients() async throws -> [Recipient] { try await get("analytics/top-recipients") }

    // MARK: Позначки

    func setTags(_ id: Int, _ tags: String) async throws {
        try await write("PATCH", "transactions/\(id)/tags", ["tags": tags])
    }

    // MARK: PIN, профіль, сесії

    func hasPin() async throws -> Bool { (try await get("auth/pin/status") as PinState).hasPin }
    func setPin(_ pin: String) async throws { try await write("PUT", "auth/pin", ["pin": pin]) }
    func verifyPin(_ pin: String) async throws { try await write("POST", "auth/pin/verify", ["pin": pin]) }
    func clearPin() async throws { try await write("DELETE", "auth/pin", nil) }

    func me() async throws -> Me { try await get("auth/me") }
    func sessions() async throws -> [Device] { try await get("auth/sessions") }
    func endSession(_ id: Int) async throws { try await write("DELETE", "auth/sessions/\(id)", nil) }
    func endOtherSessions() async throws { try await write("DELETE", "auth/sessions", nil) }
    func changePassword(old: String, new: String) async throws {
        try await write("PUT", "auth/password", ["old_password": old, "new_password": new])
    }

    /// Квиток відновлення пароля. SMS і пошти в пісочниці немає, тож код приходить тут же (demoCode).
    struct ResetTicket: Decodable, Sendable {
        let resetId: String
        let sentTo: String
        let expiresIn: Int
        let demoCode: String?
    }

    func forgotPassword(identity: String) async throws -> ResetTicket {
        let w: Wrapped<ResetTicket> = try await post("auth/password/forgot", json: ["identity": identity])
        return w.data
    }

    func resetPassword(_ ticket: ResetTicket, code: String, newPassword: String) async throws -> Session {
        let w: Wrapped<Session> = try await post("auth/password/reset", json: [
            "reset_id": ticket.resetId, "code": code, "new_password": newPassword,
        ])
        return w.data
    }

    // MARK: Документи

    /// PDF чи CSV від сервера - у тимчасовий файл, щоб віддати в «Поділитися».
    func document(_ path: String, name: String) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(for: request(path, method: "GET"))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure(message: L("Сервер не віддав документ").s)
        }
        let url = URL.temporaryDirectory.appending(path: name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Транспорт

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let w: Wrapped<T> = try await send(request(path, method: "GET"))
        return w.data
    }

    private func write(_ method: String, _ path: String, _ json: [String: Any]?) async throws {
        var r = request(path, method: method)
        if let json {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let _: Ignored = try await send(r)
    }
}
