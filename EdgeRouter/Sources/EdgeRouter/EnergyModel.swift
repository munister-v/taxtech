import Foundation

/// Модель енергії, Дж. iOS не віддає застосунку миттєву потужність, тому енергію рахуємо
/// з часу й коефіцієнтів, а коефіцієнти калібруємо в лабораторії: Power Profiler в Instruments
/// і довгі прогони з падінням заряду. Значення нижче - стартові, з літератури (MAUI, вимірювання
/// «хвоста» LTE), їх треба замінити на свої заміри для кожного класу iPhone.
public struct EnergyModel: Codable, Sendable, Equatable {
    /// Потужність обчислень на телефоні (CPU + GPU + Neural Engine під навантаженням), Вт.
    public var computeW: Double = 2.0
    /// Потужність радіо під час обміну, Вт.
    public var radioW: [Network: Double] = [.wifi: 0.8, .cellular: 1.6, .wired: 0.3, .other: 1.0]
    /// Радіо не засинає одразу після відповіді: «хвіст», с.
    public var tailSeconds: [Network: Double] = [.wifi: 0.2, .cellular: 5.0, .wired: 0, .other: 1.0]
    public var tailW: [Network: Double] = [.wifi: 0.3, .cellular: 0.9, .wired: 0, .other: 0.5]

    public init() {}

    public func estimate(_ placement: Placement, latencyMs: Double, network: Network) -> Double {
        let t = latencyMs / 1000
        switch placement {
        case .device:
            return computeW * t
        case .cloud, .redactedCloud:
            let radio = radioW[network] ?? 1
            let tail = (tailSeconds[network] ?? 0) * (tailW[network] ?? 0)
            // маскування на телефоні - коротке обчислення перед відправкою
            let redaction = placement == .redactedCloud ? computeW * 0.02 : 0
            return radio * t + tail + redaction
        }
    }
}
