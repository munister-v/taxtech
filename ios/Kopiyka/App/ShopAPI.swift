import Foundation

/// Магазин, 3-D Secure і реєстрація - те, що було в мобільному застосунку ARM Bank.
extension API {
    // MARK: Магазин

    struct Product: Decodable, Sendable, Identifiable, Hashable {
        let id: Int
        let title: String
        let description: String?
        let price: Double
        let imageEmoji: String?
        /// Фото товару: повний URL або шлях на нашому сервері.
        let imageUrl: String?
        let imageCredit: String?
        let badge: String?
        let stock: Int?
    }

    struct Catalog: Decodable, Sendable {
        let items: [Product]
        let page: Int
        let pages: Int
        let total: Int
        /// Скільки товарів у кожній категорії (порожні не повертаються).
        let categories: [String: Int]?
    }

    struct Order: Decodable, Sendable, Identifiable {
        let id: Int
        let status: String
        let totalAmount: Double
        let itemsCount: Int?
        let invoiceNumber: String?
        let createdAt: String
    }

    struct Invoice: Decodable, Sendable, Identifiable {
        let invoiceNumber: String
        let orderId: Int
        let amount: Double
        let status: String
        let dueAt: String?
        let paidAt: String?
        let createdAt: String
        var id: String { invoiceNumber }
    }

    struct Purchase: Decodable, Sendable {
        let orderId: Int
        let invoiceNumber: String?
        let newBalance: Double?
    }

    private struct Orders: Decodable { let orders: [Order] }
    private struct Invoices: Decodable { let invoices: [Invoice] }

    func catalog(search: String, page: Int, category: String? = nil, sort: String? = nil, perPage: Int = 20) async throws -> Catalog {
        var q = URLComponents()
        q.queryItems = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "per_page", value: "\(perPage)")]
        if !search.isEmpty { q.queryItems?.append(URLQueryItem(name: "search", value: search)) }
        if let category { q.queryItems?.append(URLQueryItem(name: "category", value: category)) }
        if let sort { q.queryItems?.append(URLQueryItem(name: "sort", value: sort)) }
        return try await fetch("marketplace/catalog?\(q.percentEncodedQuery ?? "")")
    }

    func orders() async throws -> [Order] { (try await fetch("marketplace/orders") as Orders).orders }
    func invoices() async throws -> [Invoice] { (try await fetch("marketplace/invoices") as Invoices).invoices }

    func checkout(_ cart: [Product: Int], name: String, phone: String, address: String) async throws -> Purchase {
        let items = cart.map { ["product_id": $0.key.id, "qty": $0.value] }
        let w: Wrapped<Purchase> = try await post("marketplace/checkout", json: [
            "items": items, "shipping_name": name, "shipping_phone": phone, "shipping_address": address,
            "payment_mode": "pay_now",
        ], idempotencyKey: UUID().uuidString)
        return w.data
    }

    // MARK: 3-D Secure

    struct Challenge: Decodable, Sendable, Identifiable {
        let challengeId: String
        /// Навчальний банк показує код одразу - SMS немає.
        let demoOtp: String?
        let expiresIn: Int
        let maskedPhone: String?
        var id: String { challengeId }
    }

    private struct Verified: Decodable { let sessionToken: String? }

    func challenge(amount: Double, recipient: String) async throws -> Challenge {
        let w: Wrapped<Challenge> = try await post("3ds/challenge", json: ["amount": amount, "recipient": recipient])
        return w.data
    }

    func verify(_ challenge: Challenge, code: String) async throws {
        let _: Wrapped<Verified> = try await post("3ds/verify", json: ["challenge_id": challenge.challengeId, "otp_code": code])
    }

    // MARK: Реєстрація

    func register(name: String, phone: String, email: String, password: String) async throws -> Session {
        let w: Wrapped<Session> = try await post("auth/register", json: [
            "full_name": name, "phone": phone, "email": email, "password": password,
        ])
        return w.data
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let w: Wrapped<T> = try await send(request(path, method: "GET"))
        return w.data
    }
}
