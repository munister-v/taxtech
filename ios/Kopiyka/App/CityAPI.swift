import Foundation

/// Roma Live QR payments (server/backend/routes/city_routes.py). A screen (the map on the site, a shop) shows a QR for a
/// place and an amount; the app scans it, the client confirms, the payment goes through the same POS pipeline as the
/// terminal (3-D Secure from 1000 TAX) and lands in the statement and on the city map.
extension API {
    struct QRInvoice: Decodable, Sendable, Identifiable, Hashable {
        let code: String
        let venue: Int
        let name: String
        let cat: String
        let rione: String
        let amount: Double
        let status: String          // pending | processing | paid | declined | expired | cancelled
        let expiresIn: Int
        let sca: Bool
        let responseCode: String?
        let authCode: String?
        let rrn: String?
        let who: String?
        let threeDs: Bool?
        // only on /confirm
        let outcome: String?
        let newBalance: Double?
        let message: String?
        let fee: Double?
        var id: String { code }
        var isOpen: Bool { status == "pending" || status == "processing" }
    }

    func qrInvoice(_ code: String) async throws -> QRInvoice {
        let w: Wrapped<QRInvoice> = try await send(request("city/qr/\(code)", method: "GET"))
        return w.data
    }

    func qrConfirm(_ code: String, cardId: Int?, tds: String?) async throws -> QRInvoice {
        var j: [String: Any] = [:]
        if let cardId { j["card_id"] = cardId }
        if let tds { j["tds_session"] = tds }
        let w: Wrapped<QRInvoice> = try await post("city/qr/\(code)/confirm", json: j)
        return w.data
    }

    struct CityMe: Decodable, Sendable { let name: String; let who: String; let balance: Double; let cardId: Int?; let cardLast4: String? }

    func cityMe() async throws -> CityMe {
        let w: Wrapped<CityMe> = try await send(request("city/me", method: "GET"))
        return w.data
    }
}

/// What a scanned code or an opened link means. Accepts the web link (any host, path /pay/<code>), the app scheme
/// (taxtech://pay/<code>) and a bare code typed or pasted by hand.
enum PayLink {
    static func code(from raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: s), url.scheme != nil {
            let parts = (url.host == "pay" ? ["pay"] : []) + url.pathComponents.filter { $0 != "/" }
            if let i = parts.firstIndex(of: "pay"), i + 1 < parts.count, valid(parts[i + 1]) { return parts[i + 1] }
            return nil
        }
        return valid(s) ? s : nil
    }

    static func valid(_ c: String) -> Bool {
        (6...24).contains(c.count) && c.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } && c.allSatisfy(\.isASCII)
    }

    /// The same invoice in the browser: the fallback when the app cannot pay it.
    static func web(_ code: String, base: URL) -> URL { base.appending(path: "pay").appending(path: code) }
}
