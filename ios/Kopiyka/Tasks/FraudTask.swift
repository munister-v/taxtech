import EdgeRouter
import FraudLite
import Foundation

/// Перевірка переказу на шахрайство. На телефоні - Layer 1 (ті самі правила, що й на сервері),
/// на сервері - усі три шари з історією й графом переказів.
enum FraudTask {
    struct Input: Sendable {
        let amount: Double
        let balance: Double
        let description: String
        let recipient: String?
    }

    struct Verdict: Sendable {
        let score: Int
        let level: String
        let flags: [String]
        /// Скільки шарів правил побачило переказ.
        let layers: Int
    }

    static let profile = TaskProfile(
        id: "fraud", sensitivity: .open, payloadBytes: 400,
        available: [.device, .cloud],
        prior: .init(latencyMs: [.device: 2, .cloud: 250], quality: [.device: 0.6, .cloud: 0.9])
    )

    static func executors(api: API) -> Executors<Input, Verdict> {
        var ex = Executors<Input, Verdict>(device: { input in
            let r = FraudLite.assess(amount: input.amount, balance: input.balance, description: input.description)
            return Attempt(Verdict(score: r.score, level: r.level.rawValue, flags: r.flags, layers: 1),
                           uncertainty: uncertainty(score: r.score, input: input))
        })
        if api.token != nil {
            ex.cloud = { input in
                let s = try await api.fraudScore(amount: input.amount, balance: input.balance,
                                                 description: input.description, recipient: input.recipient)
                return Attempt(Verdict(score: s.score, level: s.level, flags: s.flags, layers: s.layersRun?.count ?? 3))
            }
        }
        return ex
    }

    /// Чого телефон не бачить: історії й графа. Невпевненість росте, коли бал у «сірій» зоні,
    /// коли сума велика і коли одержувач новий. Початкова евристика - її калібрують
    /// на розмічених даних PaySim (`research_labels`) і замінюють навченою.
    static func uncertainty(score: Int, input: Input) -> Double {
        let grey = (15...60).contains(score) ? 0.45 : 0
        let size = min(1, input.amount / 20_000) * 0.35
        let newRecipient = input.recipient == nil ? 0 : 0.1
        return min(1, 0.1 + grey + size + newRecipient)
    }
}
