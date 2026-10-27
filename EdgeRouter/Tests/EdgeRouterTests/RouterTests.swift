import Foundation
import Testing
@testable import EdgeRouter

struct Offline: Error {}

func makeRouter(_ strategy: Strategy, network: Network = .wifi) async -> EdgeRouter {
    let dir = FileManager.default.temporaryDirectory.appending(path: "er-\(UUID())")
    let r = EdgeRouter(directory: dir) { DeviceContext(network: network) }
    await r.update { $0.config.strategy = strategy }
    return r
}

@Test func cascadeAcceptsConfidentDeviceAnswer() async throws {
    let r = await makeRouter(.cascade)
    let ex = Executors<Int, String>(device: { _ in Attempt("телефон", uncertainty: 0.1) },
                                    cloud: { _ in Attempt("сервер") })
    let out = try await r.run(anyTask, input: 1, executors: ex)
    #expect(out.output == "телефон")
    #expect(out.record.placement == .device)
    #expect(!out.record.escalated)
}

@Test func cascadeEscalatesUnsureDeviceAnswer() async throws {
    let r = await makeRouter(.cascade)
    let ex = Executors<Int, String>(device: { _ in Attempt("телефон", uncertainty: 0.9) },
                                    cloud: { _ in Attempt("сервер") })
    let out = try await r.run(anyTask, input: 1, executors: ex)
    #expect(out.output == "сервер")
    #expect(out.record.escalated)
}

@Test func cloudFailureFallsBackToDevice() async throws {
    let r = await makeRouter(.alwaysCloud)
    let ex = Executors<Int, String>(device: { _ in Attempt("телефон") },
                                    cloud: { _ in throw Offline() })
    let out = try await r.run(anyTask, input: 1, executors: ex)
    #expect(out.output == "телефон")
    #expect(out.record.fellBack)
    #expect(out.record.reason == "Сервер не відповів - відповів телефон")
}

@Test func feedbackOnAcceptedAnswerTightensThreshold() async throws {
    let r = await makeRouter(.cascade)
    let ex = Executors<Int, String>(device: { _ in Attempt("телефон", uncertainty: 0.2) },
                                    cloud: { _ in Attempt("сервер") })
    let out = try await r.run(anyTask, input: 1, executors: ex)
    let before = await r.snapshot.state.lambda(anyTask.id)
    await r.feedback(out.record.id, correct: false)
    let after = await r.snapshot.state.lambda(anyTask.id)
    #expect(after < before)
}

@Test func journalRecordsDecisionsAndFeedback() async throws {
    let r = await makeRouter(.alwaysDevice)
    let ex = Executors<Int, String>(device: { _ in Attempt("телефон") })
    let out = try await r.run(anyTask, input: 1, executors: ex)
    await r.feedback(out.record.id, correct: true)
    let (decisions, feedback) = await r.telemetry.load()
    #expect(decisions.map(\.id) == [out.record.id])
    #expect(feedback[out.record.id] == true)
}
