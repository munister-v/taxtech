import Foundation

/// Графік відключень світла. Під час відключення мобільна мережа деградує,
/// тож метод заздалегідь, а не за фактом, зсуває рішення на телефон.
public struct OutageSchedule: Codable, Sendable, Equatable {
    public var intervals: [DateInterval]
    /// За скільки до відключення імовірність починає рости (базові станції сідають не одразу,
    /// але люди масово переходять на мобільний інтернет ще до початку).
    public var leadTime: TimeInterval

    public init(intervals: [DateInterval] = [], leadTime: TimeInterval = 15 * 60) {
        self.intervals = intervals
        self.leadTime = leadTime
    }

    /// 1 - усередині відключення, лінійне зростання протягом `leadTime` до нього, інакше 0.
    public func probability(at date: Date) -> Double {
        var p = 0.0
        for i in intervals {
            if i.contains(date) { return 1 }
            let until = i.start.timeIntervalSince(date)
            if until > 0, until < leadTime { p = max(p, 1 - until / leadTime) }
        }
        return p
    }
}
