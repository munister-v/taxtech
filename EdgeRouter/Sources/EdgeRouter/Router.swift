import Foundation

/// Результат одного виконавця.
public struct Attempt<Output: Sendable>: Sendable {
    public let output: Output
    /// Оцінка невпевненості s(x) ∈ [0, 1]: 0 - упевнений, 1 - навмання. Для каскаду.
    public let uncertainty: Double
    /// Скільки особистих даних замасковано перед відправкою.
    public let redactions: Int

    public init(_ output: Output, uncertainty: Double = 0, redactions: Int = 0) {
        self.output = output
        self.uncertainty = uncertainty
        self.redactions = redactions
    }
}

public typealias Executor<Input: Sendable, Output: Sendable> = @Sendable (Input) async throws -> Attempt<Output>

public struct Executors<Input: Sendable, Output: Sendable>: Sendable {
    public var device: Executor<Input, Output>?
    public var cloud: Executor<Input, Output>?
    public var redactedCloud: Executor<Input, Output>?

    public init(device: Executor<Input, Output>? = nil, cloud: Executor<Input, Output>? = nil,
                redactedCloud: Executor<Input, Output>? = nil) {
        self.device = device
        self.cloud = cloud
        self.redactedCloud = redactedCloud
    }

    var available: Set<Placement> {
        var s: Set<Placement> = []
        if device != nil { s.insert(.device) }
        if cloud != nil { s.insert(.cloud) }
        if redactedCloud != nil { s.insert(.redactedCloud) }
        return s
    }

    func callAsFunction(_ p: Placement) -> Executor<Input, Output>? {
        switch p {
        case .device: device
        case .cloud: cloud
        case .redactedCloud: redactedCloud
        }
    }
}

public struct Routed<Output: Sendable>: Sendable {
    public let output: Output
    public let record: DecisionRecord
}

/// Що зберігається між запусками: налаштування і все, чого метод навчився.
public struct RouterSnapshot: Codable, Sendable {
    public var config = PolicyConfig()
    public var state = PolicyState()
    public var estimators = Estimators()
    public var energy = EnergyModel()
    public var outages = OutageSchedule()

    public init() {}
}

public actor EdgeRouter {
    public private(set) var snapshot: RouterSnapshot
    public let telemetry: TelemetryStore
    private let stateURL: URL?
    private let context: @Sendable () async -> DeviceContext
    /// Рішення каскаду, де прийнято відповідь телефона і чекаємо, чи вона правильна.
    private var pending: [UUID: (task: String, placement: Placement, acceptedDevice: Bool)] = [:]

    public init(directory: URL?, context: @escaping @Sendable () async -> DeviceContext) {
        let dir = directory ?? FileManager.default.temporaryDirectory.appending(path: "EdgeRouter")
        telemetry = TelemetryStore(url: dir.appending(path: "decisions.jsonl"))
        stateURL = directory?.appending(path: "router.json")
        self.context = context
        if let url = stateURL, let data = try? Data(contentsOf: url),
           let s = try? JSONDecoder().decode(RouterSnapshot.self, from: data) {
            snapshot = s
        } else {
            snapshot = RouterSnapshot()
        }
    }

    public func update(_ change: @Sendable (inout RouterSnapshot) -> Void) {
        change(&snapshot)
        persist()
    }

    /// Скинути навчене, лишивши налаштування.
    public func resetLearning() {
        snapshot.state = PolicyState()
        snapshot.estimators = Estimators()
        pending = [:]
        persist()
    }

    public func currentContext() async -> DeviceContext {
        var ctx = await context()
        ctx.outageProbability = snapshot.outages.probability(at: .now)
        return ctx
    }

    public func run<Input: Sendable, Output: Sendable>(
        _ base: TaskProfile, input: Input, executors: Executors<Input, Output>
    ) async throws -> Routed<Output> {
        let ctx = await currentContext()
        let task = TaskProfile(id: base.id, sensitivity: base.sensitivity, payloadBytes: base.payloadBytes,
                               available: base.available.intersection(executors.available), prior: base.prior)
        let decision = try Policy.decide(task, context: ctx, estimators: snapshot.estimators,
                                         energy: snapshot.energy, config: snapshot.config, state: snapshot.state)
        let clock = ContinuousClock()
        let started = clock.now
        var energy = 0.0
        var escalated = false
        var fellBack = false
        var uncertainty: Double?
        var threshold: Double?
        var failure: String?
        let canFallBack = task.allowed.contains(.device) && executors.device != nil

        let attempt: Attempt<Output>
        let placement: Placement
        switch decision.plan {
        case .run(.device):
            let r = await measure(task.id, .device, ctx.network, input, executors)
            energy += r.energy
            attempt = try r.result.get()
            placement = .device
        case .run(let p):
            let r = await measure(task.id, p, ctx.network, input, executors)
            energy += r.energy
            switch r.result {
            case .success(let a):
                (attempt, placement) = (a, p)
            case .failure(let error):
                // сервер не відповів - повертаємося на телефон, якщо можна
                guard canFallBack else { throw error }
                failure = error.localizedDescription
                fellBack = true
                let d = await measure(task.id, .device, ctx.network, input, executors)
                energy += d.energy
                (attempt, placement) = (try d.result.get(), .device)
            }
        case .cascade(let p):
            let d = await measure(task.id, .device, ctx.network, input, executors)
            energy += d.energy
            let local = try d.result.get()
            let lambda = snapshot.state.lambda(task.id)
            uncertainty = local.uncertainty
            threshold = lambda
            if local.uncertainty <= lambda {
                (attempt, placement) = (local, .device)
            } else {
                escalated = true
                // передача на сервер сама по собі не помилка: поріг можна трохи розширити
                snapshot.state.updateThreshold(task.id, error: false, alpha: snapshot.config.alpha,
                                               eta: snapshot.config.eta)
                let r = await measure(task.id, p, ctx.network, input, executors)
                energy += r.energy
                switch r.result {
                case .success(let a):
                    (attempt, placement) = (a, p)
                case .failure(let error):
                    failure = error.localizedDescription
                    fellBack = true
                    (attempt, placement) = (local, .device)
                }
            }
            snapshot.estimators.observeEscalation(task.id, escalated: escalated)
        }

        let latency = (clock.now - started).milliseconds
        let budget = PolicyState.budget(snapshot.config.energyBudgetJ, ctx)
        snapshot.state.updateQueue(energyJ: energy, budgetJ: budget)

        let record = DecisionRecord(
            id: UUID(), date: .now, task: task.id, strategy: snapshot.config.strategy, context: ctx,
            candidates: decision.candidates, plan: decision.plan, placement: placement, escalated: escalated,
            fellBack: fellBack, uncertainty: uncertainty, threshold: threshold,
            energyQueue: snapshot.state.energyQueue, latencyMs: latency, energyJ: energy,
            redactions: attempt.redactions, reason: fellBack ? "Сервер не відповів - відповів телефон" : decision.reason,
            error: failure)
        pending[record.id] = (task.id, placement, decision.plan.isCascade && !escalated)
        await telemetry.append(.decision(record))
        persist()
        return Routed(output: attempt.output, record: record)
    }

    /// Один виклик з заміром часу й енергії; успішні заміри одразу йдуть в оцінки.
    private func measure<Input: Sendable, Output: Sendable>(
        _ task: String, _ p: Placement, _ network: Network, _ input: Input, _ executors: Executors<Input, Output>
    ) async -> (result: Result<Attempt<Output>, any Error>, energy: Double) {
        let clock = ContinuousClock()
        let t0 = clock.now
        let result: Result<Attempt<Output>, any Error>
        do { result = .success(try await executors(p)!(input)) } catch { result = .failure(error) }
        let ms = (clock.now - t0).milliseconds
        if case .success = result { snapshot.estimators.observeLatency(task, p, network, ms: ms) }
        return (result, snapshot.energy.estimate(p, latencyMs: ms, network: network))
    }

    /// Відгук про правильність: користувач підтвердив або виправив результат.
    /// Оновлює оцінку якості, а для прийнятої відповіді каскаду - конформний поріг.
    public func feedback(_ id: UUID, correct: Bool) async {
        guard let p = pending.removeValue(forKey: id) else { return }
        snapshot.estimators.observeQuality(p.task, p.placement, correct: correct)
        if p.acceptedDevice {
            snapshot.state.updateThreshold(p.task, error: !correct, alpha: snapshot.config.alpha,
                                           eta: snapshot.config.eta)
        }
        await telemetry.append(.feedback(FeedbackRecord(decisionID: id, date: .now, correct: correct)))
        persist()
    }

    private func persist() {
        guard let url = stateURL, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

extension Plan {
    var isCascade: Bool { if case .cascade = self { true } else { false } }
}

extension Duration {
    var milliseconds: Double {
        let (s, atto) = components
        return Double(s) * 1000 + Double(atto) / 1e15
    }
}
