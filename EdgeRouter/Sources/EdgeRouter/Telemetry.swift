import Foundation

/// Одне рішення з усім, що потрібно для аналізу: контекст, прогнози кандидатів, що вибрано,
/// що вийшло насправді. Журнал - JSON Lines, по рядку на запис; його експортують для статті.
public struct DecisionRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let task: String
    public let strategy: Strategy
    public let context: DeviceContext
    public let candidates: [Candidate]
    public let plan: Plan
    /// Де фактично отримано відповідь.
    public let placement: Placement
    public let escalated: Bool
    /// Сервер не відповів, відповідь дав телефон.
    public let fellBack: Bool
    public let uncertainty: Double?
    public let threshold: Double?
    public let energyQueue: Double
    public let latencyMs: Double
    public let energyJ: Double
    /// Скільки особистих даних замасковано перед відправкою.
    public let redactions: Int
    public let reason: String
    public let error: String?
}

public struct FeedbackRecord: Codable, Sendable, Equatable {
    public let decisionID: UUID
    public let date: Date
    public let correct: Bool
}

enum TelemetryLine: Codable {
    case decision(DecisionRecord)
    case feedback(FeedbackRecord)
}

public actor TelemetryStore {
    public let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(url: URL) {
        self.url = url
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func append(_ line: TelemetryLine) {
        guard var data = try? encoder.encode(line) else { return }
        data.append(0x0A)
        if let h = try? FileHandle(forWritingTo: url) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    /// Рішення разом із відгуками, найновіші першими.
    public func load() -> (decisions: [DecisionRecord], feedback: [UUID: Bool]) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return ([], [:]) }
        var decisions: [DecisionRecord] = []
        var feedback: [UUID: Bool] = [:]
        for line in text.split(separator: "\n") {
            switch try? decoder.decode(TelemetryLine.self, from: Data(line.utf8)) {
            case .decision(let d): decisions.append(d)
            case .feedback(let f): feedback[f.decisionID] = f.correct
            case nil: continue
            }
        }
        return (decisions.reversed(), feedback)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
