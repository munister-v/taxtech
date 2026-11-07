import Foundation

/// Емуляція еквайрингу: платіж на віртуальному терміналі проходить термінал, еквайр, мережу й емітента.
extension API {
    struct PosStage: Decodable, Sendable, Hashable { let stage: String; let ms: Int }

    struct PosIso: Decodable, Sendable, Hashable, Identifiable { let field: String; let name: String; let value: String; var id: String { field } }

    struct PosSettlement: Decodable, Sendable, Hashable {
        let clearingDate: String, payoutDate: String
        let paidOut: Bool
        let gross: Double, mdr: Double, fee: Double, net: Double
    }

    struct PosDispute: Decodable, Sendable, Hashable { let reason: String; let status: String; let verdict: String? }

    struct PosMerchantSummary: Decodable, Sendable {
        struct Totals: Decodable, Sendable {
            let gross: Double, fee: Double, net: Double, refunded: Double, approvalRate: Double, mdr: Double
            let count: Int, declined: Int
            let disputes: Int?, chargebacks: Int?, holds: Double?, holdsCount: Int?
        }
        struct Shop: Decodable, Sendable, Identifiable { let merchant: String; let gross: Double, fee: Double, net: Double; let count: Int; var id: String { merchant } }
        struct Payout: Decodable, Sendable, Identifiable { let date: String; let gross: Double, fee: Double, net: Double; let count: Int; let paidOut: Bool; var id: String { date } }
        let totals: Totals
        let merchants: [Shop]
        let payouts: [Payout]
    }

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
        let outcome: String?
        let refunded: Double?
        let authAmount: Double?
        let dispute: PosDispute?
        let iso: [PosIso]?
        let settlement: PosSettlement?

        var isApproved: Bool { approved ?? (status == "captured") }
        var isRefunded: Bool { status == "refunded" }
        var isHeld: Bool { status == "authorized" }
        var isDisputed: Bool { status == "disputed" }
        /// Усе, що ще лишилося повернути з captured-платежу.
        var refundable: Double { max(0, (amount ?? 0) - (refunded ?? 0)) }
    }

    func posPay(merchant: String, category: String, amount: Double, cardId: Int?, tds: String?, preauth: Bool = false) async throws -> PosPayment {
        var j: [String: Any] = ["merchant": merchant, "category": category, "amount": amount]
        if let cardId { j["card_id"] = cardId }
        if let tds { j["tds_session"] = tds }
        let w: Wrapped<PosPayment> = try await post(preauth ? "pos/preauth" : "pos/pay", json: j)
        return w.data
    }

    func posCapture(_ id: Int, amount: Double?) async throws -> PosPayment {
        let w: Wrapped<PosPayment> = try await post("pos/payments/\(id)/capture", json: Self.amountBody(amount))
        return w.data
    }

    private static func amountBody(_ amount: Double?) -> [String: Any] {
        var j: [String: Any] = [:]
        if let amount { j["amount"] = amount }
        return j
    }

    func posVoid(_ id: Int) async throws -> PosPayment {
        let w: Wrapped<PosPayment> = try await post("pos/payments/\(id)/void", json: [:])
        return w.data
    }

    func posDispute(_ id: Int, reason: String) async throws -> PosPayment {
        let w: Wrapped<PosPayment> = try await post("pos/payments/\(id)/dispute", json: ["reason": reason])
        return w.data
    }

    func posDisputeRespond(_ id: Int, contest: Bool) async throws -> PosPayment {
        let w: Wrapped<PosPayment> = try await post("pos/payments/\(id)/dispute/respond", json: ["action": contest ? "contest" : "accept"])
        return w.data
    }

    func posPayments() async throws -> [PosPayment] {
        let w: Wrapped<[PosPayment]> = try await send(request("pos/payments", method: "GET"))
        return w.data
    }

    func posMerchant() async throws -> PosMerchantSummary {
        let w: Wrapped<PosMerchantSummary> = try await send(request("pos/merchant", method: "GET"))
        return w.data
    }

    func posRefund(_ id: Int, amount: Double? = nil) async throws -> PosPayment {
        let w: Wrapped<PosPayment> = try await post("pos/payments/\(id)/refund", json: Self.amountBody(amount))
        return w.data
    }

    private struct TdsToken: Decodable { let sessionToken: String }

    /// Те саме підтвердження 3-D Secure, що й для переказів, але повертає одноразовий токен для платежу.
    func verifyForPayment(_ challenge: Challenge, code: String) async throws -> String {
        let w: Wrapped<TdsToken> = try await post("3ds/verify", json: ["challenge_id": challenge.challengeId, "otp_code": code])
        return w.data.sessionToken
    }
}
