import Foundation

/// Де виконується задача.
public enum Placement: String, Codable, Sendable, CaseIterable, Hashable {
    /// На телефоні: Core ML, Vision, Foundation Models, правила.
    case device
    /// На сервері з повними даними.
    case cloud
    /// На сервері, але телефон спершу маскує персональні дані.
    case redactedCloud

    public var title: String {
        switch self {
        case .device: "На телефоні"
        case .cloud: "На сервері"
        case .redactedCloud: "На сервері без особистих даних"
        }
    }
}

/// Наскільки чутливі вхідні дані задачі. Це жорстке обмеження, а не вага.
public enum Sensitivity: String, Codable, Sendable {
    /// Можна відправляти як є.
    case open
    /// Можна відправляти лише після маскування.
    case personal
    /// Не залишає телефон ніколи.
    case secret

    var allowed: Set<Placement> {
        switch self {
        case .open: [.device, .cloud, .redactedCloud]
        case .personal: [.device, .redactedCloud]
        case .secret: [.device]
        }
    }
}

public enum Network: String, Codable, Sendable, CaseIterable {
    case offline, wifi, cellular, wired, other
}

public enum Thermal: Int, Codable, Sendable, Comparable {
    case nominal, fair, serious, critical
    public static func < (a: Thermal, b: Thermal) -> Bool { a.rawValue < b.rawValue }
}

/// Стан телефона в момент рішення. Пишеться в журнал разом із рішенням.
public struct DeviceContext: Codable, Sendable, Equatable {
    public var network: Network
    public var isExpensive: Bool
    public var isConstrained: Bool
    /// 0...1, nil - невідомо (симулятор).
    public var batteryLevel: Double?
    public var isCharging: Bool
    public var lowPowerMode: Bool
    public var thermal: Thermal
    /// Імовірність відключення світла в найближчий час, з графіка (0...1).
    public var outageProbability: Double

    public init(network: Network = .wifi, isExpensive: Bool = false, isConstrained: Bool = false,
                batteryLevel: Double? = nil, isCharging: Bool = false, lowPowerMode: Bool = false,
                thermal: Thermal = .nominal, outageProbability: Double = 0) {
        self.network = network
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
        self.lowPowerMode = lowPowerMode
        self.thermal = thermal
        self.outageProbability = outageProbability
    }

    public var isOnline: Bool { network != .offline }
}

/// Що відомо про задачу до її виконання.
public struct TaskProfile: Sendable {
    public let id: String
    public let sensitivity: Sensitivity
    /// Скільки байтів піде на сервер (для оцінки часу передачі).
    public let payloadBytes: Int
    /// Які виконавці взагалі є (наприклад, Foundation Models може бути недоступна).
    public let available: Set<Placement>
    /// Початкові оцінки до перших замірів.
    public let prior: Prior

    public init(id: String, sensitivity: Sensitivity, payloadBytes: Int,
                available: Set<Placement>, prior: Prior) {
        self.id = id
        self.sensitivity = sensitivity
        self.payloadBytes = payloadBytes
        self.available = available
        self.prior = prior
    }

    public var allowed: Set<Placement> { available.intersection(sensitivity.allowed) }

    public struct Prior: Sendable {
        public var latencyMs: [Placement: Double]
        public var quality: [Placement: Double]
        /// Ціна одного виклику на сервері, умовні одиниці (токени тощо).
        public var cloudCost: Double

        public init(latencyMs: [Placement: Double], quality: [Placement: Double], cloudCost: Double = 0) {
            self.latencyMs = latencyMs
            self.quality = quality
            self.cloudCost = cloudCost
        }
    }
}
