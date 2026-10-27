import Foundation

/// Решта ендпоїнтів навчального банку: картки, депозити, кредити, цілі, контакти,
/// ліміти, регулярні платежі, аналітика. Усі суми віртуальні.
extension API {
    struct Ignored: Decodable, Sendable { init(from decoder: Decoder) throws {} }

    // MARK: Моделі

    struct Deposit: Decodable, Sendable, Identifiable {
        let id: Int
        let amount: Double
        let interestRate: Double
        let termMonths: Int
        let interestEarned: Double
        let daysLeft: Int?
        let maturityDate: String?
        let progress: Double?
        let status: String
        let matured: Bool?
        let autoRenew: Bool?
        let description: String?

        var isActive: Bool { status == "active" }
    }

    struct Credit: Decodable, Sendable, Identifiable {
        let id: Int
        let principal: Double
        let interestRate: Double
        let termMonths: Int
        let monthlyPayment: Double
        let balanceRemaining: Double
        let scheduledTotal: Double
        let nextPaymentDate: String?
        let daysToPayment: Int?
        let progress: Double?
        let totalPaid: Double
        let status: String
        let description: String?

        var isActive: Bool { status == "active" }
    }

    struct Goal: Decodable, Sendable, Identifiable {
        let id: Int
        let title: String
        let currentAmount: Double
        let targetAmount: Double
        let deadline: String?
        let status: String

        var progress: Double { targetAmount > 0 ? min(currentAmount / targetAmount, 1) : 0 }
    }

    struct Contact: Decodable, Sendable, Identifiable {
        let id: Int
        let contactName: String
        let relationType: String
        let phone: String?
        let accountNumber: String?
    }

    struct Template: Decodable, Sendable, Identifiable {
        let id: Int
        let name: String
        let recipientAccount: String?
        let amount: Double?
        let description: String?
    }

    struct BudgetLimit: Decodable, Sendable, Identifiable {
        let id: Int
        let txType: String
        let monthlyLimit: Double
        let pct: Double?
        let spent: Double?
    }

    struct Recurring: Decodable, Sendable, Identifiable {
        let id: Int
        let title: String
        let amount: Double
        let frequency: String
        let isActive: Int
        let nextRunDate: String?
        let recipientAccount: String?
    }

    struct Month: Decodable, Sendable, Identifiable {
        let month: String
        let totalIn: Double
        let totalOut: Double
        var id: String { month }
    }

    struct Totals: Decodable, Sendable {
        let totalIn: Double
        let totalOut: Double
        let txCount: Int
    }

    struct ByType: Decodable, Sendable, Identifiable {
        let txType: String
        let direction: String
        let total: Double
        let cnt: Int
        var id: String { txType + direction }
    }

    struct Analytics: Decodable, Sendable {
        let currentMonth: Totals
        let prevMonth: Totals
        let monthly: [Month]
        let byType: [ByType]
    }

    struct BalancePoint: Decodable, Sendable, Identifiable {
        let day: String
        let balance: Double
        var id: String { day }
    }

    struct Insight: Decodable, Sendable { let text: String }
    private struct InsightList: Decodable { let insights: [Insight] }

    struct Achievement: Decodable, Sendable, Identifiable {
        let id: String
        let title: String
        let desc: String
        let done: Bool
    }

    struct AchievementList: Decodable, Sendable {
        let achievements: [Achievement]
        let done: Int
        let total: Int
    }

    struct Revealed: Decodable, Sendable {
        let cardNumber: String
        let cvv: String
        let expiryDisplay: String?
    }

    // MARK: Транспорт для змін

    private func change(_ method: String, _ path: String, _ json: [String: Any]? = nil) async throws {
        var r = request(path, method: method)
        if let json {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        let _: Ignored = try await send(r)
    }

    private func list<T: Decodable>(_ path: String) async throws -> T {
        let w: Wrapped<T> = try await send(request(path, method: "GET"))
        return w.data
    }

    private func money(_ path: String, _ json: [String: Any]) async throws {
        let _: Ignored = try await post(path, json: json, idempotencyKey: UUID().uuidString)
    }

    // MARK: Рахунок і історія

    struct HistoryFilter: Sendable {
        var search = ""
        var direction: String?
        var txType: String?
    }

    func history(_ f: HistoryFilter) async throws -> [Transaction] {
        var comps = URLComponents()
        comps.queryItems = [
            f.search.isEmpty ? nil : URLQueryItem(name: "search", value: f.search),
            f.direction.map { URLQueryItem(name: "direction", value: $0) },
            f.txType.map { URLQueryItem(name: "tx_type", value: $0) },
        ].compactMap { $0 }
        let q = comps.percentEncodedQuery.map { "?" + $0 } ?? ""
        let w: Wrapped<[Transaction]> = try await send(request("transactions/history" + q, method: "GET"))
        return w.data
    }

    func setNote(_ id: Int, _ note: String) async throws { try await change("PATCH", "transactions/\(id)/note", ["note": note]) }

    func transferByCard(_ amount: Double, cardNumber: String, description: String) async throws {
        try await money("transactions/transfer-by-card",
                        ["amount": amount, "card_number": cardNumber, "description": description])
    }

    func analytics() async throws -> Analytics { try await list("analytics/summary") }
    func balanceHistory(days: Int) async throws -> [BalancePoint] { try await list("analytics/balance-history?days=\(days)") }
    func insights() async throws -> [Insight] {
        let l: InsightList = try await list("analytics/insights")
        return l.insights
    }
    func achievements() async throws -> AchievementList { try await list("achievements") }

    // MARK: Картки

    func issueCard(design: String) async throws {
        let _: Ignored = try await post("cards", json: ["card_type": "virtual", "design": design])
    }
    func reveal(_ id: Int) async throws -> Revealed { try await list("cards/\(id)/reveal") }
    func setPrimary(_ id: Int) async throws { try await change("PATCH", "cards/\(id)/set_primary", [:]) }
    func closeCard(_ id: Int) async throws { try await change("PATCH", "cards/\(id)/close", [:]) }
    func topUpCard(_ id: Int, _ amount: Double) async throws { try await change("POST", "cards/\(id)/topup", ["amount": amount]) }

    // MARK: Депозити й кредити

    func deposits() async throws -> [Deposit] { try await list("deposits") }
    func openDeposit(amount: Double, months: Int, autoRenew: Bool, note: String) async throws {
        let _: Ignored = try await post("deposits", json: ["amount": amount, "term_months": months,
                                                          "auto_renew": autoRenew, "description": note])
    }
    func closeDeposit(_ id: Int, early: Bool) async throws { try await change("POST", "deposits/\(id)/close", ["early": early]) }

    func credits() async throws -> [Credit] { try await list("credits") }
    func takeCredit(amount: Double, months: Int, note: String) async throws {
        try await money("credits", ["amount": amount, "term_months": months, "description": note])
    }
    func repayCredit(_ id: Int, amount: Double?) async throws {
        try await money("credits/\(id)/repay", amount.map { ["amount": $0] } ?? [:])
    }

    // MARK: Цілі, контакти, шаблони

    func goals() async throws -> [Goal] { try await list("savings-goals") }
    func addGoal(title: String, target: Double, deadline: String?) async throws {
        var j: [String: Any] = ["title": title, "target_amount": target]
        if let deadline { j["deadline"] = deadline }
        let _: Ignored = try await post("savings-goals", json: j)
    }
    func contribute(_ id: Int, _ amount: Double) async throws { try await change("POST", "savings-goals/\(id)/contribute", ["amount": amount]) }
    func deleteGoal(_ id: Int) async throws { try await change("DELETE", "savings-goals/\(id)") }

    func contacts() async throws -> [Contact] { try await list("family-contacts") }
    func addContact(name: String, relation: String, account: String, phone: String) async throws {
        let _: Ignored = try await post("family-contacts", json: ["contact_name": name, "relation_type": relation,
                                                                 "account_number": account, "phone": phone])
    }
    func deleteContact(_ id: Int) async throws { try await change("DELETE", "family-contacts/\(id)") }

    func templates() async throws -> [Template] { try await list("payment-templates") }
    func addTemplate(name: String, recipient: String, amount: Double?, note: String) async throws {
        var j: [String: Any] = ["name": name, "recipient_account": recipient, "description": note]
        if let amount { j["amount"] = amount }
        let _: Ignored = try await post("payment-templates", json: j)
    }
    func deleteTemplate(_ id: Int) async throws { try await change("DELETE", "payment-templates/\(id)") }

    // MARK: Ліміти й регулярні платежі

    func limits() async throws -> [BudgetLimit] { try await list("budget-limits") }
    func setLimit(txType: String, amount: Double) async throws {
        let _: Ignored = try await post("budget-limits", json: ["tx_type": txType, "monthly_limit": amount])
    }
    func deleteLimit(_ txType: String) async throws { try await change("DELETE", "budget-limits/\(txType)") }

    func recurring() async throws -> [Recurring] { try await list("recurring-transactions") }
    func addRecurring(title: String, recipient: String, amount: Double, frequency: String, first: String) async throws {
        let _: Ignored = try await post("recurring-transactions", json: [
            "title": title, "recipient_account": recipient, "amount": amount,
            "frequency": frequency, "next_run_date": first, "description": title,
        ])
    }
    func toggleRecurring(_ id: Int) async throws { try await change("PATCH", "recurring-transactions/\(id)/toggle", [:]) }
    func deleteRecurring(_ id: Int) async throws { try await change("DELETE", "recurring-transactions/\(id)") }
}
