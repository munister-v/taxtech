import Foundation

/// Валютні рахунки, курси, обмін, переказ на IBAN і довідки.
extension API {
    struct FXAccount: Decodable, Sendable, Identifiable, Hashable {
        let id: Int
        let currency: String
        let name: String
        let balance: Double
        let iban: String
        let ibanPretty: String
    }

    struct FXAccounts: Decodable, Sendable {
        let accounts: [FXAccount]
        let totalTax: Double
        let available: [String]
    }

    struct FXRate: Decodable, Sendable, Identifiable, Hashable {
        let currency: String
        let name: String
        let mid: Double, bid: Double, ask: Double
        var id: String { currency }
    }

    struct FXRates: Decodable, Sendable {
        let base: String
        let spread: Double
        let rates: [FXRate]
        let updatedAt: String
    }

    struct FXQuote: Decodable, Sendable, Hashable {
        let from: String, to: String
        let fromAmount: Double, toAmount: Double
        let rate: Double
        let spreadTax: Double
        let rrn: String?
    }

    struct FXTx: Decodable, Sendable, Identifiable, Hashable {
        let id: Int
        let kind: String
        let direction: String
        let amount: Double
        let description: String
        let createdAt: String
        var isIncome: Bool { direction == "in" }
    }

    struct FXTransfer: Decodable, Sendable {
        let amount: Double, fee: Double, total: Double
        let currency: String
        let isInternal: Bool
        let rail: String
        let reference: String
        enum CodingKeys: String, CodingKey { case amount, fee, total, currency, isInternal = "internal", rail, reference }
    }

    func fxAccounts() async throws -> FXAccounts {
        let w: Wrapped<FXAccounts> = try await send(request("fx/accounts", method: "GET"))
        return w.data
    }

    func fxRates() async throws -> FXRates {
        let w: Wrapped<FXRates> = try await send(request("fx/rates", method: "GET"))
        return w.data
    }

    func fxQuote(from: String, to: String, amount: Double) async throws -> FXQuote {
        let w: Wrapped<FXQuote> = try await send(request("fx/quote?from=\(from)&to=\(to)&amount=\(amount)", method: "GET"))
        return w.data
    }

    func fxOpen(_ currency: String) async throws -> FXAccount {
        let w: Wrapped<FXAccount> = try await post("fx/wallets", json: ["currency": currency])
        return w.data
    }

    func fxExchange(from: String, to: String, amount: Double) async throws -> FXQuote {
        let w: Wrapped<FXQuote> = try await post("fx/exchange", json: ["from": from, "to": to, "amount": amount])
        return w.data
    }

    func fxTopup(_ walletId: Int, amount: Double) async throws -> FXAccount {
        let w: Wrapped<FXAccount> = try await post("fx/wallets/\(walletId)/topup", json: ["amount": amount])
        return w.data
    }

    func fxTransfer(currency: String, iban: String, amount: Double, beneficiary: String, purpose: String) async throws -> FXTransfer {
        let w: Wrapped<FXTransfer> = try await post("fx/transfer", json: [
            "from_currency": currency, "iban": iban, "amount": amount, "beneficiary": beneficiary, "purpose": purpose,
        ])
        return w.data
    }

    func fxTransactions(_ walletId: Int) async throws -> [FXTx] {
        let w: Wrapped<[FXTx]> = try await send(request("fx/wallets/\(walletId)/transactions", method: "GET"))
        return w.data
    }

    func fxCertificate(type: String, currency: String, from: String?, to: String?) async throws -> DocumentRecord {
        var j: [String: Any] = ["type": type, "currency": currency]
        if let from { j["from_date"] = from }
        if let to { j["to_date"] = to }
        let w: Wrapped<DocumentRecord> = try await post("fx/certificates", json: j)
        return w.data
    }
}

/// IBAN за ISO 13616: та сама перевірка mod 97, що й на сервері.
enum IBAN {
    static func clean(_ s: String) -> String { s.filter { !$0.isWhitespace }.uppercased() }

    static func pretty(_ s: String) -> String {
        let c = Array(clean(s))
        return stride(from: 0, to: c.count, by: 4).map { String(c[$0..<min($0 + 4, c.count)]) }.joined(separator: " ")
    }

    static func isValid(_ raw: String) -> Bool {
        let s = clean(raw)
        guard s.count >= 15, s.count <= 34, s.prefix(2).allSatisfy(\.isLetter), s.dropFirst(2).prefix(2).allSatisfy(\.isNumber) else { return false }
        var rem = 0
        for ch in s.dropFirst(4) + s.prefix(4) {
            guard let v = ch.isNumber ? ch.wholeNumberValue : (ch.isLetter && ch.isASCII ? Int(ch.asciiValue!) - 55 : nil) else { return false }
            for d in String(v) { rem = (rem * 10 + Int(String(d))!) % 97 }
        }
        return rem == 1
    }
}
