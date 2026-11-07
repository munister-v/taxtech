import SwiftUI

// MARK: Бенто: плитки різного кольору й розміру.

extension Font {
    /// Заголовки й великі цифри: системний шрифт без засічок, жирний для сум, напівжирний для решти.
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight == .heavy ? .bold : .semibold)
    }
}

/// Тон плитки: жовтий лише для балансу, чорнильний і поверхня для решти.
enum BentoTone {
    case yellow, ink, surface

    var background: Color {
        switch self {
        case .yellow: Theme.accent
        case .ink: Theme.ink
        case .surface: Theme.surface
        }
    }

    var foreground: Color {
        switch self {
        case .yellow: Theme.onAccent
        case .ink: Theme.onInk
        case .surface: Theme.ink
        }
    }
}

/// Плитка: великий радіус, вміст від верхнього лівого кута, тонкий край лише на світлій поверхні.
struct BentoTile<Content: View>: View {
    var tone = BentoTone.surface
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(padding)
            .foregroundStyle(tone.foreground)
            .environment(\.onYellow, tone == .yellow)
            .background(tone.background)
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .overlay {
                if tone == .surface {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.ink.opacity(0.06), lineWidth: 1)
                }
            }
            .contentShape(.rect(cornerRadius: 24, style: .continuous))
    }
}

/// Підпис плитки зверху: дрібно, приглушено, у тоні плитки.
struct BentoCaption: View {
    let text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Стрілка в куті плитки, що веде далі: гліф без підкладки.
struct BentoArrow: View {
    var body: some View {
        Image(systemName: "arrow.up.right").font(.system(size: 15, weight: .bold)).foregroundStyle(.secondary)
    }
}

// MARK: Айдентика: монета TAX і візерунок зі знака

/// Токен TAX: чорна монета з емблемою університету, повільно обертається й має товщину ребра.
struct TaxCoin: View {
    var size: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduce)) { tl in
            let t = reduce ? 0.35 : tl.date.timeIntervalSinceReferenceDate
            // повільне обертання з паузами: монета «дихає», а не крутиться як дзиґа
            let angle = sin(t * 0.9) * 0.95
            let squash = max(0.08, abs(cos(angle)))
            let edge = CGFloat(sin(angle)) * size * 0.07
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Circle().fill(Color(white: 0.16 - Double(i) * 0.015))
                        .frame(width: size, height: size)
                        .scaleEffect(x: squash, y: 1)
                        .offset(x: edge * CGFloat(i) / 5)
                }
                face(back: cos(angle) < 0)
                    .scaleEffect(x: squash, y: 1)
                    .offset(x: -edge * 0.2)
            }
            .frame(width: size * 1.15, height: size)
        }
        .accessibilityHidden(true)
    }

    private func face(back: Bool) -> some View {
        ZStack {
            Circle().fill(Theme.onAccent)
            Circle().strokeBorder(Theme.accent.opacity(0.9), lineWidth: size * 0.035).padding(size * 0.07)
            if back {
                Text("TAX").font(.system(size: size * 0.24, weight: .bold)).foregroundStyle(Theme.accent)
            } else {
                BrandSeal(size: size * 0.66, color: Theme.accent)
            }
            // відблиск по верхньому краю
            Circle().fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
        }
        .frame(width: size, height: size)
    }
}

/// Візерунок зі знака TaxTech: сітка дрібних знаків, кожен трохи повернутий.
struct MarkPattern: View {
    var color: Color = Theme.onInk
    var opacity: Double = 0.08
    var step: CGFloat = 34

    var body: some View {
        GeometryReader { g in
            let cols = Int(g.size.width / step) + 2, rows = Int(g.size.height / step) + 2
            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<cols, id: \.self) { c in
                        Image("Mark").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: step * 0.42)
                            .rotationEffect(.degrees(Double((r + c) % 4) * 90))
                            .position(x: CGFloat(c) * step + (r % 2 == 0 ? 0 : step / 2), y: CGFloat(r) * step)
                    }
                }
            }
            .foregroundStyle(color.opacity(opacity))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}


/// Знак Державного податкового університету: емблема, «STU» і State Tax University - з оригінального файлу,
/// без перемальовування; колір підставляється під тему.
struct BrandLockup: View {
    var height: CGFloat = 60
    var color: Color = Theme.ink

    var body: some View {
        Image("STULogo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(color)
            .accessibilityLabel("State Tax University")
    }
}

/// Емблема університету окремо: для монети, заставки й дрібних місць.
struct BrandSeal: View {
    var size: CGFloat = 74
    var color: Color = Theme.ink

    var body: some View {
        Image("STUSeal")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
