import Foundation

/// Layer 1 антифроду - ті самі п'ять правил, що й у `server/backend/services/fraud_engine.py`,
/// без жодного звернення до історії. Порт один до одного: однакові пороги, нечіткі функції,
/// обрізання `int()` і банківське округлення `round()` з Python. Збіг перевіряють
/// еталонні вектори в `Tests/FraudLiteTests` (генератор поруч із ними).
public enum RiskLevel: String, Sendable, Codable {
    case low, medium, high, critical
}

public struct RiskResult: Sendable, Equatable, Codable {
    public private(set) var score = 0
    public private(set) var level = RiskLevel.low
    public private(set) var flags: [String] = []
    var confidence = 1.0
    var ruleHits = 0
    var beliefs: [Double] = []

    public init() {}

    public var isCritical: Bool { level == .critical }

    /// Адитивний внесок. Внесок одного правила обмежено 70 балами.
    mutating func add(_ delta: Int, _ flag: String) {
        guard delta > 0 else { return }
        let capped = min(delta, 70)
        score = min(100, score + capped)
        ruleHits += 1
        flags.append(flag)
        level = Self.level(for: score)
        beliefs.append(Double(capped) / 100)
    }

    /// Кореляційний бонус і нормалізація, як `RiskResult.finalize` на сервері.
    mutating func finalize() {
        applyCorrelationBonus()
        score = min(100, pyRound(Double(score) * confidence))
        level = Self.level(for: score)
    }

    private mutating func applyCorrelationBonus() {
        guard !beliefs.isEmpty, ruleHits >= 3 else { return }
        let avg = beliefs.reduce(0, +) / Double(beliefs.count)
        let (weight, flag): (Double, String) =
            ruleHits >= 7 ? (35, "multi_rule_correlation_chain")
            : ruleHits >= 5 ? (20, "multi_rule_correlation_strong")
            : (10, "multi_rule_correlation")
        score = min(100, score + pyRound(weight * avg))
        flags.append(flag)
    }

    static func level(for score: Int) -> RiskLevel {
        switch score {
        case 76...: .critical
        case 51...: .high
        case 26...: .medium
        default: .low
        }
    }
}

/// Python `round()` - до найближчого парного.
func pyRound(_ x: Double) -> Int { Int(x.rounded(.toNearestOrEven)) }

/// Нечіткі функції належності (клас `FM` на сервері).
enum FM {
    static func sigmoid(_ x: Double, center: Double, slope: Double = 5) -> Double {
        let denom = center * 0.15 + 1e-9
        return 1 / (1 + exp(-slope * (x - center) / denom))
    }

    static func gaussian(_ x: Double, center: Double, sigma: Double) -> Double {
        if sigma <= 0 { return abs(x - center) < 1e-9 ? 1 : 0 }
        let z = (x - center) / sigma
        return exp(-0.5 * z * z)
    }

    static func trapezoid(_ x: Double, _ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        if x <= a || x >= d { return 0 }
        if b <= x && x <= c { return 1 }
        return x < b ? (x - a) / (b - a + 1e-12) : (d - x) / (d - c + 1e-12)
    }
}

public enum FraudLite {
    /// Оцінка переказу лише з його власних полів - те, що телефон може порахувати без мережі.
    public static func assess(amount: Double, balance: Double, description: String) -> RiskResult {
        var r = RiskResult()
        structuring(amount, &r)
        roundAmount(amount, &r)
        suspiciousDescription(description, &r)
        balanceDepletion(amount, balance, &r)
        thresholdMasking(amount, &r)
        r.finalize()
        return r
    }

    /// Суми трохи нижче контрольних порогів.
    static func structuring(_ amount: Double, _ r: inout RiskResult) {
        for t in [5_000.0, 10_000, 20_000, 50_000, 100_000] {
            let lo = t * 0.90, hi = t * 0.995
            if lo <= amount && amount < hi {
                r.add(Int(32 * FM.gaussian(amount, center: hi, sigma: (hi - lo) * 0.4)), "structuring")
                return
            }
        }
    }

    static func roundAmount(_ amount: Double, _ r: inout RiskResult) {
        for (modulo, threshold, maxDelta) in [(10_000.0, 50_000.0, 20.0), (1_000, 5_000, 14), (500, 1_000, 8)]
        where amount >= threshold && amount.truncatingRemainder(dividingBy: modulo) == 0 {
            r.add(Int(maxDelta * FM.sigmoid(amount, center: threshold, slope: 2)), "round_amount")
            return
        }
    }

    static let descriptionPattern = try! NSRegularExpression(
        pattern: #"\b(test|тест|debug|відмив|laundr|probe|зонд|dummy|fake|фейк|spam|скам|scam|urgent|терміново|crypto|крипто|нал|кеш|готів)\b"#,
        options: [.caseInsensitive]
    )

    static func suspiciousDescription(_ text: String, _ r: inout RiskResult) {
        let n = descriptionPattern.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
        if n > 0 { r.add(15 + min(n - 1, 3) * 8, "suspicious_description") }
    }

    static func balanceDepletion(_ amount: Double, _ balance: Double, _ r: inout RiskResult) {
        guard balance > 0 else { return }
        let pct = amount / balance
        if pct >= 0.95 {
            r.add(max(Int(45 * FM.trapezoid(pct, 0.95, 0.97, 1.0, 1.01)), 20), "balance_depletion_critical")
        } else if pct >= 0.80 {
            r.add(max(Int(20 * FM.trapezoid(pct, 0.80, 0.88, 0.95, 0.96)), 8), "balance_depletion")
        }
    }

    /// Суми «щойно під» порогами звітності.
    static func thresholdMasking(_ amount: Double, _ r: inout RiskResult) {
        for t in [50_000.0, 100_000, 200_000, 500_000, 1_000_000] {
            let lower = t * (1 - 0.005)
            if lower <= amount && amount < t {
                let proximity = (amount - lower) / (t - lower)
                r.add(Int(42 * FM.sigmoid(proximity, center: 0.3, slope: 6)), "threshold_masking")
                return
            }
        }
    }
}
