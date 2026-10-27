import Foundation

/// Стратегії для порівняння в роботі: чотири базові лінії і власний метод.
public enum Strategy: String, Codable, Sendable, CaseIterable {
    case alwaysDevice, alwaysCloud, rules, cascade, adaptive

    public var title: String {
        switch self {
        case .alwaysDevice: "Завжди телефон"
        case .alwaysCloud: "Завжди сервер"
        case .rules: "Прості правила"
        case .cascade: "Каскад"
        case .adaptive: "Метод EdgeRouter"
        }
    }
}

/// План виконання: одне місце або каскад «спершу телефон, за сумніву - сервер».
public enum Plan: Codable, Sendable, Hashable {
    case run(Placement)
    case cascade(to: Placement)

    public var title: String {
        switch self {
        case .run(let p): p.title
        case .cascade(let p): "Телефон, за сумніву - \(p == .cloud ? "сервер" : "сервер без особистих даних")"
        }
    }
}

public struct PolicyConfig: Codable, Sendable, Equatable {
    public var strategy = Strategy.adaptive
    /// Ціна секунди очікування.
    public var latencyWeight = 1.0
    /// Ціна одиниці якості (1.0 - ідеальна відповідь) у тих самих одиницях, що й секунда.
    public var qualityWeight = 4.0
    /// Ціна умовної одиниці вартості виклику сервера.
    public var cloudCostWeight = 0.0
    /// Компроміс Ляпунова: більше V - важливіші затримка й якість, менше - бюджет енергії.
    public var lyapunovV = 1.0
    /// Середній бюджет енергії на одну задачу, Дж.
    public var energyBudgetJ = 1.5
    /// Цільова частка помилок прийнятих відповідей телефона в каскаді.
    public var alpha = 0.05
    /// Крок адаптивного конформного порога.
    public var eta = 0.05
    /// Скільки чекаємо сервер, перш ніж повернутися на телефон.
    public var cloudTimeoutMs = 8000.0

    public init() {}
}

/// Змінні, що навчаються на льоту: черга перевитрати енергії і пороги каскаду.
public struct PolicyState: Codable, Sendable, Equatable {
    /// Віртуальна черга Ляпунова: Z ← max(Z + E − Ē, 0).
    public var energyQueue = 0.0
    /// Поріг невпевненості λ для кожної задачі: відповідь телефона приймаємо, якщо s(x) ≤ λ.
    public var threshold: [String: Double] = [:]

    public init() {}

    public func lambda(_ task: String) -> Double { threshold[task] ?? 0.5 }

    /// Адаптивний конформний вивід (Gibbs & Candès, 2021): λ ← λ + η(α − err).
    /// Помилка прийнятої відповіді звужує поріг, правильна - розширює. Довгострокова частка
    /// помилок прийнятих відповідей сходиться до α навіть при зсуві розподілу.
    public mutating func updateThreshold(_ task: String, error: Bool, alpha: Double, eta: Double) {
        let next = lambda(task) + eta * (alpha - (error ? 1 : 0))
        threshold[task] = min(1, max(0, next))
    }

    /// Ефективний бюджет залежить від заряду: на зарядці щедріший, на низькому заряді скупіший.
    public static func budget(_ base: Double, _ ctx: DeviceContext) -> Double {
        if ctx.isCharging { return base * 2 }
        if ctx.lowPowerMode || (ctx.batteryLevel ?? 1) < 0.2 { return base * 0.5 }
        return base
    }

    public mutating func updateQueue(energyJ: Double, budgetJ: Double) {
        energyQueue = max(energyQueue + energyJ - budgetJ, 0)
    }
}

public struct Candidate: Codable, Sendable, Equatable {
    public let plan: Plan
    public let latencyMs: Double
    public let energyJ: Double
    public let quality: Double
    /// Значення цільової функції drift-plus-penalty, менше - краще.
    public let objective: Double
}

public struct Decision: Codable, Sendable, Equatable {
    public let plan: Plan
    public let candidates: [Candidate]
    public let reason: String
}

public enum RouterError: Error, LocalizedError {
    case nothingAllowed(String)

    public var errorDescription: String? {
        switch self {
        case .nothingAllowed(let why): why
        }
    }
}

public enum Policy {
    /// Чисте рішення без побічних ефектів - його й перевіряють тести.
    public static func decide(_ task: TaskProfile, context ctx: DeviceContext, estimators est: Estimators,
                              energy: EnergyModel, config cfg: PolicyConfig, state: PolicyState) throws -> Decision {
        var allowed = task.allowed
        if !ctx.isOnline { allowed.remove(.cloud); allowed.remove(.redactedCloud) }
        guard !allowed.isEmpty else {
            throw RouterError.nothingAllowed(ctx.isOnline ? "Для цих даних немає дозволеного виконавця"
                                                          : "Немає мережі, а на телефоні ця задача недоступна")
        }

        let deviceAllowed = allowed.contains(.device)
        let remote = [Placement.cloud, .redactedCloud].filter(allowed.contains)

        // Оцінки для одного місця з урахуванням відмови сервера й повернення на телефон.
        func estimate(_ p: Placement) -> (t: Double, e: Double, q: Double) {
            var t = est.latencyMs(task, p, ctx.network)
            var q = est.quality(task, p)
            if p == .device {
                if ctx.thermal >= .serious { t *= 1.5 }   // троттлінг
                return (t, energy.estimate(.device, latencyMs: t, network: ctx.network), q)
            }
            // відмова сервера: прогноз відключення світла плюс обмежена мережа
            let fail = min(1, ctx.outageProbability * 0.7 + (ctx.isConstrained ? 0.1 : 0))
            let e = energy.estimate(p, latencyMs: t, network: ctx.network)
            if fail > 0 {
                let dev = deviceAllowed ? est.latencyMs(task, .device, ctx.network) : 0
                let devQ = deviceAllowed ? est.quality(task, .device) : 0
                let failT = cfg.cloudTimeoutMs + dev
                let failE = energy.estimate(p, latencyMs: cfg.cloudTimeoutMs, network: ctx.network)
                    + energy.estimate(.device, latencyMs: dev, network: ctx.network)
                t = (1 - fail) * t + fail * failT
                q = (1 - fail) * q + fail * devQ
                return (t, (1 - fail) * e + fail * failE, q)
            }
            return (t, e, q)
        }

        func objective(_ plan: Plan, t: Double, e: Double, q: Double) -> Double {
            let usesCloud: Double = switch plan {
            case .run(.device): 0
            case .run: 1
            case .cascade: est.escalationRate(task)
            }
            let penalty = cfg.latencyWeight * t / 1000 - cfg.qualityWeight * q
                + cfg.cloudCostWeight * task.prior.cloudCost * usesCloud
            return cfg.lyapunovV * penalty + state.energyQueue * e
        }

        var candidates: [Candidate] = []
        var single: [Placement: (t: Double, e: Double, q: Double)] = [:]
        for p in Placement.allCases where allowed.contains(p) {
            let x = estimate(p)
            single[p] = x
            candidates.append(Candidate(plan: .run(p), latencyMs: x.t, energyJ: x.e, quality: x.q,
                                        objective: objective(.run(p), t: x.t, e: x.e, q: x.q)))
        }
        if let d = single[.device] {
            for r in remote {
                let c = single[r]!
                let rate = est.escalationRate(task)
                let t = d.t + rate * c.t
                let e = d.e + rate * c.e
                // прийняті відповіді телефона помиляються не частіше за α відносно сервера
                let q = (1 - rate) * max(d.q, c.q - cfg.alpha) + rate * c.q
                candidates.append(Candidate(plan: .cascade(to: r), latencyMs: t, energyJ: e, quality: q,
                                            objective: objective(.cascade(to: r), t: t, e: e, q: q)))
            }
        }

        let bestRemote = remote.min { single[$0]!.t < single[$1]!.t }
        let plan: Plan
        var reason: String
        switch cfg.strategy {
        case .alwaysDevice:
            plan = deviceAllowed ? .run(.device) : .run(bestRemote!)
            reason = deviceAllowed ? "Стратегія: завжди телефон" : "На телефоні недоступно"
        case .alwaysCloud:
            plan = bestRemote.map(Plan.run) ?? .run(.device)
            reason = bestRemote == nil ? "Сервер недоступний" : "Стратегія: завжди сервер"
        case .rules:
            // типові правила з застосунків: вайфай - сервер, мало заряду - сервер, інакше телефон
            let lowBattery = ctx.lowPowerMode || (ctx.batteryLevel ?? 1) < 0.2
            if let r = bestRemote, ctx.network == .wifi || lowBattery {
                plan = .run(r)
                reason = lowBattery ? "Правило: мало заряду - сервер" : "Правило: вайфай - сервер"
            } else {
                plan = deviceAllowed ? .run(.device) : .run(bestRemote!)
                reason = "Правило: без вайфаю - телефон"
            }
        case .cascade:
            if deviceAllowed, let r = bestRemote {
                plan = .cascade(to: r)
                reason = "Стратегія: каскад"
            } else {
                plan = .run(deviceAllowed ? .device : bestRemote!)
                reason = "Каскад неможливий, одне місце"
            }
        case .adaptive:
            let best = candidates.min { $0.objective < $1.objective }!
            plan = best.plan
            reason = explain(best, ctx: ctx, task: task, state: state)
        }
        if !ctx.isOnline { reason = "Немає мережі - лише телефон" }
        else if task.sensitivity == .secret { reason = "Приватні дані не залишають телефон" }
        return Decision(plan: plan, candidates: candidates, reason: reason)
    }

    static func explain(_ best: Candidate, ctx: DeviceContext, task: TaskProfile, state: PolicyState) -> String {
        if ctx.outageProbability >= 0.5, best.plan == .run(.device) { return "Очікується відключення світла" }
        if state.energyQueue > 0, best.plan == .run(.device) || best.plan == .run(.cloud) {
            return "Бюджет енергії перевищено на \(String(format: "%.1f", state.energyQueue)) Дж"
        }
        if ctx.thermal >= .serious, best.plan != .run(.device) { return "Телефон перегрітий" }
        return switch best.plan {
        case .run(.device): "Найвигідніше на телефоні"
        case .run(.cloud): "Найвигідніше на сервері"
        case .run(.redactedCloud): "Сервер, особисті дані замасковано"
        case .cascade: "Каскад вигідніший за одне місце"
        }
    }
}
