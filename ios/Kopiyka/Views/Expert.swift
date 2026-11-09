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
                            Image(systemName: "flask").font(Theme.ui(style: .title3)).foregroundStyle(Theme.accent).frame(width: 28)
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
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: Theme.hairline))
    }

    func glassCapsule() -> some View {
        background(.ultraThinMaterial, in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: Theme.hairline))
    }
}

/// Живий фон шапки: три розмиті плями тепла дрейфують по чорному. Рух повільний, поверх нього - зерно.
struct AuroraField: View {
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { ctx in
            let t = reduce ? 0 : ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                g.addFilter(.blur(radius: 70))
                let orbs: [(Color, Double, Double, Double, Double, Double)] = [
                    (Color(red: 0.86, green: 0.07, blue: 0.17), 0.30, 0.22, 0.23, 0.17, 0.55),
                    (Color(red: 0.55, green: 0.03, blue: 0.15), 0.78, 0.32, 0.19, 0.23, 0.55),
                    (Color(red: 0.95, green: 0.60, blue: 0.24), 0.62, 0.08, 0.31, 0.12, 0.22),
                ]
                for (i, o) in orbs.enumerated() {
                    let k = Double(i) * 2.1
                    let cx = size.width * (o.1 + 0.16 * sin(t * o.3 + k))
                    let cy = size.height * (o.2 + 0.12 * cos(t * o.4 * 1.3 + k))
                    let r = size.width * (0.42 + 0.05 * sin(t * 0.5 + k))
                    g.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                           with: .color(o.0.opacity(o.5)))
                }
            }
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black.opacity(0.7), location: 0.55),
                                     .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
