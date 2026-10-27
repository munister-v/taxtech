#if canImport(UIKit)
import Network
import os
import UIKit

/// Живий контекст телефона: мережа з `NWPathMonitor`, заряд, режим енергозбереження, нагрів.
public final class LiveContextProvider: Sendable {
    private let monitor = NWPathMonitor()
    private let path = OSAllocatedUnfairLock<NWPath?>(initialState: nil)

    public init() {
        monitor.pathUpdateHandler = { [path] p in path.withLock { $0 = p } }
        monitor.start(queue: DispatchQueue(label: "EdgeRouter.path"))
    }

    deinit { monitor.cancel() }

    @MainActor
    public func snapshot() -> DeviceContext {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let p = path.withLock { $0 }
        let network: Network = switch p {
        case .none: .other
        case .some(let p) where p.status != .satisfied: .offline
        case .some(let p) where p.usesInterfaceType(.wifi): .wifi
        case .some(let p) where p.usesInterfaceType(.cellular): .cellular
        case .some(let p) where p.usesInterfaceType(.wiredEthernet): .wired
        default: .other
        }
        let info = ProcessInfo.processInfo
        let thermal: Thermal = switch info.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        default: .critical
        }
        return DeviceContext(
            network: network,
            isExpensive: p?.isExpensive ?? false,
            isConstrained: p?.isConstrained ?? false,
            batteryLevel: device.batteryLevel < 0 ? nil : Double(device.batteryLevel),
            isCharging: device.batteryState == .charging || device.batteryState == .full,
            lowPowerMode: info.isLowPowerModeEnabled,
            thermal: thermal
        )
    }
}
#endif
