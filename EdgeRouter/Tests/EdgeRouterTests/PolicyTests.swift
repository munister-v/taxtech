import Foundation
import Testing
@testable import EdgeRouter

let anyTask = TaskProfile(
    id: "t", sensitivity: .open, payloadBytes: 1000, available: [.device, .cloud, .redactedCloud],
    prior: .init(latencyMs: [.device: 300, .cloud: 400, .redactedCloud: 420],
                 quality: [.device: 0.7, .cloud: 0.95, .redactedCloud: 0.93])
)

func decide(_ task: TaskProfile = anyTask, _ ctx: DeviceContext = DeviceContext(),
            config: PolicyConfig = PolicyConfig(), state: PolicyState = PolicyState()) throws -> Decision {
    try Policy.decide(task, context: ctx, estimators: Estimators(), energy: EnergyModel(),
                      config: config, state: state)
}

@Test func offlineForcesDevice() throws {
    let d = try decide(anyTask, DeviceContext(network: .offline))
    #expect(d.plan == .run(.device))
    #expect(d.candidates.allSatisfy { $0.plan == .run(.device) })
}

@Test func secretNeverLeavesPhone() throws {
    let secret = TaskProfile(id: "doc", sensitivity: .secret, payloadBytes: 0, available: anyTask.available,
                             prior: anyTask.prior)
    for s in Strategy.allCases {
        var c = PolicyConfig()
        c.strategy = s
        #expect(try decide(secret, config: c).plan == .run(.device))
    }
}

@Test func personalDataGoesOnlyRedacted() throws {
    let personal = TaskProfile(id: "r", sensitivity: .personal, payloadBytes: 0, available: anyTask.available,
                               prior: anyTask.prior)
    var c = PolicyConfig()
    c.strategy = .alwaysCloud
    #expect(try decide(personal, config: c).plan == .run(.redactedCloud))
}

@Test func offlineWithoutDeviceExecutorThrows() {
    let cloudOnly = TaskProfile(id: "c", sensitivity: .open, payloadBytes: 0, available: [.cloud], prior: anyTask.prior)
    #expect(throws: RouterError.self) { try decide(cloudOnly, DeviceContext(network: .offline)) }
}

@Test func qualityPullsToCloudWhenHealthy() throws {
    // сервер помітно якісніший і ненабагато повільніший - метод іде на сервер або в каскад
    let d = try decide()
    #expect(d.plan != .run(.device))
}

@Test func forecastOutageShiftsToDevice() throws {
    var calm = DeviceContext(network: .cellular)
    calm.outageProbability = 0
    var storm = calm
    storm.outageProbability = 1
    #expect(try decide(anyTask, calm).plan != .run(.device))
    let d = try decide(anyTask, storm)
    #expect(d.plan == .run(.device))
    #expect(d.reason == "Очікується відключення світла")
}

@Test func energyQueuePenalisesHungryPlacement() throws {
    // телефон дешевший за якістю, але дорожчий за енергією: велика черга штовхає до економнішого
    var c = PolicyConfig()
    c.qualityWeight = 0
    var hungry = PolicyState()
    hungry.energyQueue = 100
    let d = try decide(anyTask, DeviceContext(network: .wifi), config: c, state: hungry)
    let chosen = d.candidates.first { $0.plan == d.plan }!
    #expect(d.candidates.allSatisfy { chosen.energyJ <= $0.energyJ + 1e-9 })
}

@Test func lyapunovQueueTracksOverspend() {
    var s = PolicyState()
    s.updateQueue(energyJ: 3, budgetJ: 1)
    #expect(s.energyQueue == 2)
    s.updateQueue(energyJ: 0, budgetJ: 1)
    #expect(s.energyQueue == 1)
    s.updateQueue(energyJ: 0, budgetJ: 5)
    #expect(s.energyQueue == 0)
}

@Test func adaptiveConformalErrorConvergesToAlpha() {
    // модель телефона: невпевненість s ~ U(0,1), помилка тим імовірніша, чим більше s.
    // Частка помилок серед усіх кроків має прямувати до α.
    var rng = SystemRandomNumberGenerator()
    var s = PolicyState()
    let alpha = 0.1
    var errors = 0
    let steps = 20_000
    for _ in 0..<steps {
        let u = Double.random(in: 0...1, using: &rng)
        let accepted = u <= s.lambda("t")
        let wrong = accepted && Double.random(in: 0...1, using: &rng) < u
        s.updateThreshold("t", error: wrong, alpha: alpha, eta: 0.01)
        if wrong { errors += 1 }
    }
    #expect(abs(Double(errors) / Double(steps) - alpha) < 0.01)
}

@Test func outageScheduleRampsBeforeStart() {
    let start = Date(timeIntervalSince1970: 10_000)
    let s = OutageSchedule(intervals: [DateInterval(start: start, duration: 3600)], leadTime: 600)
    #expect(s.probability(at: start.addingTimeInterval(-1200)) == 0)
    #expect(abs(s.probability(at: start.addingTimeInterval(-300)) - 0.5) < 1e-9)
    #expect(s.probability(at: start.addingTimeInterval(60)) == 1)
    #expect(s.probability(at: start.addingTimeInterval(4000)) == 0)
}

@Test func redactorMasksPersonalData() {
    let (text, n) = Redactor.redact("Картка 4441 1144 2233 5566, тел +380 67 123 45 67, UA213223130000026007233566001, a@b.ua. Разом 245,50 грн")
    #expect(!text.contains("4441"))
    #expect(!text.contains("123 45 67"))
    #expect(!text.contains("UA2132"))
    #expect(!text.contains("a@b.ua"))
    #expect(text.contains("245,50"))
    #expect(n == 4)
}
