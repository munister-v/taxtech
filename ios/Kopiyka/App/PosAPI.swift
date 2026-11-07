import Foundation

/// Емуляція еквайрингу: платіж на віртуальному терміналі проходить термінал, еквайр, мережу й емітента.
extension API {
    struct PosStage: Decodable, Sendable, Hashable { let stage: String; let ms: Int }

    struct PosPayment: Decodable, Sendable, Identifiable, Hashable {
        let id: Int?
        let merchant: String?
        let category: String?
        let amount: Double?
        let fee: Double?
        let net: Double?
        let status: String?
        let responseCode: String
        let message: String
        let authCode: String?
        let rrn: String?
        let cardLast4: String?
        let threeDs: Bool?
        let latencyMs: Int?
        let createdAt: String?
        let approved: Bool?
        let needs3Ds: Bool?
        let newBalance: Double?
        let stages: [PosStage]?

        var isApproved: Bool { approved ?? (status == "captured") }
        var isRefunded: Bool { status == "refunded" }
    }

    func posPay(merchant: String, category: String, amount: Double, cardId: Int?, tds: String?) async throws -> PosPayment {
        var j: [String: Any] = ["merchant": merchant, "category": category, "amount": amount]
        if let cardId { j["card_id"] = cardId }
        if let tds { j["tds_session"] = tds }
        let w: Wrapped<PosPayment> = try await post("pos/pay", json: j)
        return w.data
    }

    func posPayments() async throws -> [PosPayment] {
        let w: Wrapped<[PosPayment]> = try await send(request("pos/payments", method: "GET"))
        return w.data
    }

    func posRefund(_ id: Int) async throws -> PosPayment {
        let w: Wrapped<PosPayment> = try await post("pos/payments/\(id)/refund", json: [:])
        return w.data
    }

    private struct TdsToken: Decodable { let sessionToken: String }

    /// Те саме підтвердження 3-D Secure, що й для переказів, але повертає одноразовий токен для платежу.
    func verifyForPayment(_ challenge: Challenge, code: String) async throws -> String {
        let w: Wrapped<TdsToken> = try await post("3ds/verify", json: ["challenge_id": challenge.challengeId, "otp_code": code])
        return w.data.sessionToken
    }
}
