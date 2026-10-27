import Foundation

/// Оцінки часу й якості для кожної пари «задача + місце», окремо для кожного типу мережі.
/// Час - експоненційне ковзне середнє (стара історія поступово забувається, що потрібно
/// при зміні режиму мережі). Якість - апостеріорне середнє Beta-розподілу з апріорі задачі.
public struct Estimators: Codable, Sendable {
    struct Key: Codable, Hashable, Sendable {
        let task: String
        let placement: Placement
        let network: Network
    }

    struct Latency: Codable, Sendable {
        var mean: Double
        var n: Int
    }

    struct Quality: Codable, Sendable {
        var correct: Double
        var wrong: Double
    }

    var latency: [Key: Latency] = [:]
    var quality: [String: Quality] = [:]
    /// Частка задач, які каскад передав на сервер.
    var escalation: [String: Latency] = [:]

    /// Вага нового заміру.
    public var smoothing = 0.2
    /// Скільки «уявних» спостережень важить апріорна якість.
    public var priorStrength = 10.0

    public init() {}

    public func latencyMs(_ task: TaskProfile, _ p: Placement, _ network: Network) -> Double {
        if let l = latency[Key(task: task.id, placement: p, network: network)] { return l.mean }
        let prior = task.prior.latencyMs[p] ?? 1000
        // без замірів на стільниковій мережі сервер повільніший
        return p == .device || network != .cellular ? prior : prior * 1.8
    }

    public func quality(_ task: TaskProfile, _ p: Placement) -> Double {
        let prior = task.prior.quality[p] ?? 0.5
        let q = quality["\(task.id)|\(p.rawValue)"] ?? Quality(correct: 0, wrong: 0)
        return (prior * priorStrength + q.correct) / (priorStrength + q.correct + q.wrong)
    }

    public func escalationRate(_ task: TaskProfile) -> Double {
        escalation[task.id]?.mean ?? 0.3
    }

    public func samples(_ task: String, _ p: Placement, _ network: Network) -> Int {
        latency[Key(task: task, placement: p, network: network)]?.n ?? 0
    }

    mutating func observeLatency(_ task: String, _ p: Placement, _ network: Network, ms: Double) {
        let k = Key(task: task, placement: p, network: network)
        if var l = latency[k] {
            l.mean += smoothing * (ms - l.mean)
            l.n += 1
            latency[k] = l
        } else {
            latency[k] = Latency(mean: ms, n: 1)
        }
    }

    mutating func observeQuality(_ task: String, _ p: Placement, correct: Bool) {
        var q = quality["\(task)|\(p.rawValue)"] ?? Quality(correct: 0, wrong: 0)
        if correct { q.correct += 1 } else { q.wrong += 1 }
        quality["\(task)|\(p.rawValue)"] = q
    }

    mutating func observeEscalation(_ task: String, escalated: Bool) {
        let x = escalated ? 1.0 : 0.0
        var e = escalation[task] ?? Latency(mean: 0.3, n: 0)
        e.mean += smoothing * (x - e.mean)
        e.n += 1
        escalation[task] = e
    }
}
