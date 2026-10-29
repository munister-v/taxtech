import CoreMotion
import SwiftUI

// MARK: Рух інтерфейсу: поява, нахил карток, відблиск, трусіння, заставка.
// Усе поважає «Зменшити рух»: тоді лишаються тільки прозорість і миттєві стани.

/// Поява блоку каскадом: знизу, з розмиттям, із затримкою за порядком.
struct Rise: ViewModifier {
    let order: Int
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduce ? 0 : 22)
            .blur(radius: shown || reduce ? 0 : 6)
            .onAppear {
                guard !shown else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.82).delay(Double(order) * 0.06)) { shown = true }
            }
    }
}

extension View {
    func rise(_ order: Int = 0) -> some View { modifier(Rise(order: order)) }

    /// Картка-предмет: нахиляється за телефоном, відблиск біжить слідом.
    func tilt(cornerRadius: CGFloat = 18) -> some View { modifier(MotionTilt(cornerRadius: cornerRadius)) }

    /// Одноразовий світловий проблиск по поверхні (після завантаження, після оплати).
    func glint<T: Equatable>(trigger: T, cornerRadius: CGFloat = 26) -> some View {
        modifier(Glint(trigger: trigger, cornerRadius: cornerRadius))
    }

    /// Паралакс усередині прокрутки: елемент їде повільніше за вміст.
    func parallax(_ factor: CGFloat = 0.18) -> some View {
        visualEffect { content, proxy in
            content.offset(y: -proxy.frame(in: .scrollView).minY * factor)
        }
    }
}

/// Нахил телефона з гіроскопа, спільний на весь застосунок: оновлюється, поки на екрані є хоч одна картка.
@MainActor @Observable
final class DeviceTilt {
    static let shared = DeviceTilt()
    private let manager = CMMotionManager()
    private var users = 0
    /// Вліво-вправо і на себе-від себе, обидва в межах -1…1.
    private(set) var x: Double = 0
    private(set) var y: Double = 0

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1 / 30
        manager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let g = motion?.gravity else { return }
            MainActor.assumeIsolated {
                // телефон у руці тримають під нахилом: g.y близько -0.6 - це «рівно»
                DeviceTilt.shared.x = max(-1, min(1, g.x * 1.6))
                DeviceTilt.shared.y = max(-1, min(1, (g.y + 0.6) * 1.6))
            }
        }
    }

    func stop() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}

/// Картка-предмет: ледь нахиляється за телефоном, смуга світла ковзає по поверхні, тінь зсувається.
/// Жестів не чіпає, тож каруселі гортаються як завжди.
struct MotionTilt: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var tilt = DeviceTilt.shared

    func body(content: Content) -> some View {
        let x = reduce ? 0 : tilt.x, y = reduce ? 0 : tilt.y
        content
            .overlay {
                LinearGradient(colors: [.clear, .white.opacity(0.2), .clear],
                               startPoint: UnitPoint(x: x * 0.9 - 0.2, y: 0), endPoint: UnitPoint(x: x * 0.9 + 1.2, y: 1))
                    .blendMode(.plusLighter)
                    .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
            .rotation3DEffect(.degrees(y * 7), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(x * 9), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .shadow(color: .black.opacity(0.3), radius: 18, x: -x * 8, y: 12 + y * 4)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: x)
            .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85), value: y)
            .onAppear { tilt.start() }
            .onDisappear { tilt.stop() }
    }
}

/// Діагональна смуга світла пробігає по поверхні раз на зміну trigger.
struct Glint<T: Equatable>: ViewModifier {
    let trigger: T
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.35)
                        .rotationEffect(.degrees(18))
                        .offset(x: phase * g.size.width * 1.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .blendMode(.softLight)
                }
                .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .onChange(of: trigger, initial: true) {
                guard !reduce else { return }
                phase = -1
                withAnimation(.easeInOut(duration: 1.1).delay(0.35)) { phase = 1 }
            }
    }
}

/// Трусіння вбік: невірний PIN чи код.
struct Shake: GeometryEffect {
    var travel: CGFloat = 10
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Тло екрана входу: плоске, як і решта застосунку.
struct Aurora: View {
    var body: some View { Theme.bg.ignoresSafeArea() }
}

/// Заставка на старті: знак виростає й обертається, жовте коло розкривається й відкриває застосунок.
struct LaunchSplash: View {
    let finished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var markIn = false
    @State private var open = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea().opacity(open ? 0 : 1)
            Circle()
                .fill(Theme.accent)
                .frame(width: 120, height: 120)
                .scaleEffect(open ? 16 : (markIn ? 1 : 0.2))
                .opacity(open ? 0 : 1)
            BrandSeal(size: 86, color: Theme.onAccent)
                .scaleEffect(markIn ? 1 : 0.4)
                .rotationEffect(.degrees(markIn || reduce ? 0 : -90))
                .opacity(open ? 0 : (markIn ? 1 : 0))
        }
        .allowsHitTesting(false)
        .task {
            if reduce {
                markIn = true
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.easeOut(duration: 0.25)) { open = true }
                try? await Task.sleep(for: .milliseconds(250))
                finished()
                return
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { markIn = true }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.easeIn(duration: 0.5)) { open = true }
            try? await Task.sleep(for: .milliseconds(480))
            finished()
        }
    }
}
