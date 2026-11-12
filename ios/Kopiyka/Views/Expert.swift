import SwiftUI

/// Усе, що пояснює механізми, живе за експертним режимом: звичайний екран лишається чистим.
private struct ExpertOnly: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        if model.expert { content.transition(.opacity) }
    }
}

extension View {
    /// Показує вміст лише в експертному режимі.
    func expertOnly() -> some View { modifier(ExpertOnly()) }
}

/// Пояснення під елементом: видно лише в експертному режимі.
struct ExpertNote: View {
    @Environment(AppModel.self) private var model
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        if model.expert {
            Text(text).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Шестерня: єдине місце, де вмикається експертний режим.
struct GearButton: View {
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            Image(systemName: "gearshape")
                .font(Theme.ui(16, .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 40, height: 40)
                .glassCircle()
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(L("Налаштування").s)
        .sheet(isPresented: $open) { SettingsSheet().presentationDetents([.medium, .large]).presentationDragIndicator(.visible) }
    }
}

struct SettingsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(L("Налаштування").s).font(.display(38, .medium)).tracking(-1).padding(.top, 8)
                    Button { withAnimation(.smooth) { model.expert.toggle() } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "flask").font(Theme.mono(style: .title3)).foregroundStyle(Theme.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L("Експертний режим").s).font(Theme.ui(style: .body, .semibold))
                                Text(L("Лабораторія, пояснення, журнал рішень").s).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: .constant(model.expert)).labelsHidden().tint(Theme.accent).allowsHitTesting(false)
                        }
                        .padding(18)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
                    .goldEdge(22)
                    .sensoryFeedback(.selection, trigger: model.expert)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Мова").s).caption()
                        VStack(spacing: 0) {
                            ForEach(Array(Lang.allCases.enumerated()), id: \.element) { i, l in
                                if i > 0 { Rectangle().fill(Theme.line).frame(height: Theme.hairline).padding(.leading, 18) }
                                Button { Lang.set(l) } label: {
                                    HStack {
                                        Text(l.title).font(Theme.ui(style: .body))
                                        Spacer()
                                        if Lang.current == l { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                                    }
                                    .padding(.horizontal, 18).padding(.vertical, 14)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
                        .goldEdge(22)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Готово").s) { dismiss() } } }
        }
    }
}

extension View {
    /// Тло екрана з тихою живою плямою вгорі: однаково на всіх вкладках банку.
    func auroraBackground(_ strength: Double = 0.55) -> some View {
        background(alignment: .top) {
            ZStack(alignment: .top) {
                Theme.bg
                AuroraField().frame(height: 420).opacity(strength)
            }
            .ignoresSafeArea()
        }
    }

    /// Скляний круг для кнопок на шапці.
    func glassCircle() -> some View {
        background(.ultraThinMaterial, in: .circle)
            .overlay(Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.9))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    func glassCapsule() -> some View {
        background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.9))
    }
}

/// Живий фон шапки: три м'які плями тепла дрейфують по чорному.
/// Плями - готові радіальні градієнти без фільтра розмиття: їх малюють раз, далі GPU лише зсуває шари.
struct AuroraField: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var p = false
    @State private var q = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                SoftOrb(color: Theme.auraGold.opacity(0.55), radius: w * 0.42, blur: 70)
                    .position(x: w * (p ? 0.44 : 0.16), y: h * (q ? 0.32 : 0.12))
                SoftOrb(color: Theme.auraCool.opacity(0.55), radius: w * 0.40, blur: 70)
                    .position(x: w * (q ? 0.64 : 0.92), y: h * (p ? 0.42 : 0.22))
                SoftOrb(color: Theme.auraBronze.opacity(0.22), radius: w * 0.45, blur: 70)
                    .position(x: w * (p ? 0.50 : 0.74), y: h * (q ? 0.0 : 0.16))
            }
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.7), location: 0.55),
                                     .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .drift(reduce: reduce, $p, 13, $q, 10)
    }
}
