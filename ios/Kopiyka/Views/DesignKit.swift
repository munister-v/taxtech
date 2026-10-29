import SwiftUI

// Сміливіші елементи TaxTech: інвертовані панелі, великий заголовок екрана, власний перемикач,
// круглі дії. Як і решта - лише чорне, біле й сірі, без градієнтів.

/// Великий заголовок екрана з підписом і місцем праворуч.
struct ScreenTitle<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle { Text(subtitle).font(.footnote.weight(.medium)).foregroundStyle(.secondary) }
                Text(title).font(.display(30)).tracking(-0.6)
            }
            Spacer()
            trailing
        }
        .padding(.top, 10)
    }
}

extension ScreenTitle where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
    }
}

/// Чи лежить вміст на жовтій панелі - тоді підписи й смуги беруть чорний замість сірого.
private struct OnYellowKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var onYellow: Bool {
        get { self[OnYellowKey.self] }
        set { self[OnYellowKey.self] = newValue }
    }
}

/// Панель головної цифри екрана. Жовта - лише одна на застосунок (баланс), решта - спокійні.
struct HeroPanel<Content: View>: View {
    var yellow = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .foregroundStyle(yellow ? Theme.onAccent : Theme.ink)
            .environment(\.onYellow, yellow)
            .background {
                if !yellow {
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width * 0.95, y: sz.height * 0.12)
                        let r = min(sz.width, sz.height) * 0.55
                        Engraving.rosette(in: &ctx, center: c, radius: r, curves: 22, lobes: 7, depth: 0.24, second: 0.06,
                                          steps: 220, color: Theme.accent.opacity(0.07), width: 0.4)
                        Engraving.rings(in: &ctx, center: c, from: r * 0.1, to: r * 0.26, count: 6, color: Theme.accent.opacity(0.08))
                    }
                    .allowsHitTesting(false)
                }
            }
            .background(alignment: .bottomTrailing) {
                if !yellow {
                    MarkView(height: 150, color: Theme.ink.opacity(0.04))
                        .offset(x: 34, y: 34)
                        .parallax(0.14)
                }
            }
            .background(yellow ? Theme.accent : Theme.surface)
            .overlay {
                // рамка банкноти: тонка лінія всередині краю
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(yellow ? Theme.onAccent.opacity(0.18) : Theme.accent.opacity(0.22), lineWidth: 0.6)
                    .padding(5)
                    .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
    }
}

/// Підпис-мітка всередині інвертованої панелі.
struct HeroCaption: View {
    @Environment(\.onYellow) private var onYellow
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(onYellow ? AnyShapeStyle(Theme.onAccent.opacity(0.75)) : AnyShapeStyle(.secondary))
    }
}

/// Пара «цифра - підпис» для рядів показників.
struct Stat: View {
    @Environment(\.onYellow) private var onYellow
    let value: String
    let label: String
    var inverted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(onYellow ? AnyShapeStyle(Theme.onAccent.opacity(0.7)) : AnyShapeStyle(.secondary))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Власний перемикач розділів: вибраний - суцільна плитка кольору тексту.
struct SegmentBar<Value: Hashable>: View {
    let items: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var ns

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.0) { value, title in
                    let on = selection == value
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { selection = value }
                    } label: {
                        Text(title)
                            .font(.subheadline.weight(on ? .semibold : .medium))
                            .padding(.horizontal, 15)
                            .padding(.vertical, 9)
                            .foregroundStyle(on ? Theme.onInk : Theme.ink)
                            .background {
                                if on {
                                    Capsule().fill(Theme.ink).matchedGeometryEffect(id: "seg", in: ns)
                                } else {
                                    Capsule().stroke(Theme.ink.opacity(0.14), lineWidth: 1)
                                }
                            }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Кругла дія: значок у колі кольору тексту і підпис під ним.
struct CircleAction: View {
    let title: String
    let symbol: String
    var primary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 60, height: 60)
                    .background(primary ? Theme.accent : Theme.surface, in: .circle)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(primary ? 0 : 0.09), lineWidth: Theme.hairline))
                    .foregroundStyle(primary ? Theme.onAccent : Theme.ink)
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(PressScale())
    }
}

/// Легке стискання під пальцем.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Смуга з кількох частин, що разом дають ціле: куди йдуть гроші.
struct SplitBar: View {
    @Environment(\.onYellow) private var onYellow
    let parts: [(label: String, value: Double)]
    var inverted = false

    var body: some View {
        let total = max(parts.reduce(0) { $0 + $1.value }, 0.0001)
        let ink = onYellow ? Theme.onAccent : Theme.ink
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                        Rectangle()
                            .fill(ink.opacity(1 - Double(i) * 0.28))
                            .frame(width: max(0, g.size.width * p.value / total - 2))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(.rect(cornerRadius: 3))
            HStack(spacing: 14) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                    HStack(spacing: 5) {
                        Rectangle().fill(ink.opacity(1 - Double(i) * 0.28)).frame(width: 10, height: 10)
                        Text("\(p.label) \(Int((p.value / total * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(onYellow ? AnyShapeStyle(Theme.onAccent.opacity(0.7)) : AnyShapeStyle(.secondary))
                    }
                }
            }
        }
    }
}

/// Поле для суми у формах-калькуляторах.
struct MoneyField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).caption()
            HStack {
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .semibold))
                    .monospacedDigit()
                Text("TAX").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
        }
    }
}

/// Порожній стан: великий знак TaxTech, заголовок і, якщо є, головна дія.
struct BrandEmpty: View {
    let title: String
    var action: String?
    var perform: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            MarkView(height: 84, color: Theme.accent)
                .padding(22)
                .background(Theme.surface, in: .circle)
            Text(title).font(.title3.weight(.bold)).multilineTextAlignment(.center)
            if let action, let perform {
                Button(action, action: perform).buttonStyle(InkButton()).frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

/// Рядок переходу: назва, значення праворуч і шеврон.
struct IconRow: View {
    let title: String
    let symbol: String
    var detail: String?

    var body: some View {
        HStack(spacing: 14) {
            Text(title).font(.body.weight(.medium))
            Spacer()
            if let detail { Text(detail).foregroundStyle(.secondary).monospacedDigit() }
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(.rect)
    }
}

/// Група рядків на поверхні з тонкими лініями між ними.
struct RowGroup<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title { Text(title).font(.title3.weight(.bold)) }
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.offset) { i, v in
                        if i > 0 { Rule() }
                        v
                    }
                }
            }
            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
        }
    }
}


/// Вкладки-текст із підкресленням активної: легша заміна сегмент-плашки.
struct TextTabs<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 22) {
            ForEach(items.indices, id: \.self) { i in
                let on = selection == items[i].0
                Button { withAnimation(.snappy(duration: 0.25)) { selection = items[i].0 } } label: {
                    VStack(spacing: 6) {
                        Text(items[i].1).font(.system(size: 17, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? Theme.ink : Color.secondary)
                        ZStack {
                            Capsule().fill(Color.clear).frame(height: 3)
                            if on { Capsule().fill(Theme.accent).frame(height: 3).matchedGeometryEffect(id: "tab", in: ns) }
                        }
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Гравюрні примітиви захисного друку: розетка, концентричні кільця, хвильові смуги. Одна лінія - 0.4-0.6 pt, як на банкноті.
enum Engraving {
    /// Розетка гільйошу: кілька кривих зі зсувом фази й другою гармонікою - перетин дає муар.
    static func rosette(in ctx: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, curves: Int, lobes: Int,
                        depth: Double = 0.26, second: Double = 0.07, steps: Int = 240, color: Color, width: CGFloat = 0.45) {
        for k in 0..<curves {
            let phase = Double(k) / Double(curves) * .pi * 2
            var p = Path()
            for i in 0...steps {
                let t = Double(i) / Double(steps) * .pi * 2
                let rr = r * (1 - depth - second + depth * cos(Double(lobes) * t + phase) + second * cos(Double(lobes * 2) * t - phase))
                let pt = CGPoint(x: c.x + rr * cos(t), y: c.y + rr * sin(t))
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            ctx.stroke(p, with: .color(color), lineWidth: width)
        }
    }

    /// Тонкі концентричні кільця між двома радіусами.
    static func rings(in ctx: inout GraphicsContext, center c: CGPoint, from r0: CGFloat, to r1: CGFloat, count: Int,
                      color: Color, width: CGFloat = 0.4) {
        guard count > 0 else { return }
        for i in 0..<count {
            let r = r0 + (r1 - r0) * CGFloat(i) / CGFloat(max(count - 1, 1))
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(color), lineWidth: width)
        }
    }

    /// Смуга з сплетених хвиль уздовж ширини: рамка банкноти.
    static func band(in ctx: inout GraphicsContext, y: CGFloat, width w: CGFloat, height h: CGFloat, lines: Int,
                     color: Color, lineWidth: CGFloat = 0.4) {
        for k in 0..<lines {
            let phase = Double(k) / Double(lines) * .pi * 2
            var p = Path()
            let steps = 160
            for i in 0...steps {
                let x = w * CGFloat(i) / CGFloat(steps)
                let t = Double(i) / Double(steps) * .pi * 2 * 9
                let yy = y + h / 2 + (h / 2) * CGFloat(sin(t + phase) * 0.55 + sin(t * 0.5 - phase) * 0.45)
                i == 0 ? p.move(to: CGPoint(x: x, y: yy)) : p.addLine(to: CGPoint(x: x, y: yy))
            }
            ctx.stroke(p, with: .color(color), lineWidth: lineWidth)
        }
    }
}

/// Значок-печатка: гравійований медальйон. Тонований круг, розетка гільйошу, подвійне металеве кільце, мікрошкала
/// по краю й рельєфний символ у центрі.
struct GuillocheBadge: View {
    let symbol: String
    var tint: Color = Theme.accent
    var size: CGFloat = 42
    /// Для темної шапки: біла лінія розетки замість тону.
    var onDark = false

    var body: some View {
        let ink = onDark ? Color.white : tint
        ZStack {
            Circle().fill(
                RadialGradient(colors: [tint.opacity(onDark ? 0.36 : 0.42), tint.opacity(onDark ? 0.10 : 0.12)],
                               center: .topLeading, startRadius: 0, endRadius: size * 1.1)
            )
            Canvas { ctx, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let r = sz.width / 2
                Engraving.rosette(in: &ctx, center: c, radius: r * 0.94, curves: 12, lobes: 6, depth: 0.2, second: 0.06,
                                  steps: 96, color: ink.opacity(0.30), width: 0.45)
                Engraving.rings(in: &ctx, center: c, from: r * 0.5, to: r * 0.58, count: 3, color: ink.opacity(0.35), width: 0.4)
                // мікрошкала по краю
                for i in 0..<60 {
                    let a = Double(i) / 60 * .pi * 2
                    var p = Path()
                    let long = i % 5 == 0
                    p.move(to: CGPoint(x: c.x + (r - 1.2) * cos(a), y: c.y + (r - 1.2) * sin(a)))
                    p.addLine(to: CGPoint(x: c.x + (r - (long ? 4.2 : 3)) * cos(a), y: c.y + (r - (long ? 4.2 : 3)) * sin(a)))
                    ctx.stroke(p, with: .color(ink.opacity(long ? 0.5 : 0.3)), lineWidth: 0.5)
                }
            }
            // центральний диск: темніший, щоб символ читався
            Circle().fill(tint.opacity(onDark ? 0.22 : 0.20)).frame(width: size * 0.54, height: size * 0.54)
            Circle().strokeBorder(
                LinearGradient(colors: [.white.opacity(0.75), tint.opacity(0.25), .white.opacity(0.15)],
                               startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                .frame(width: size * 0.54, height: size * 0.54)
            // зовнішнє металеве кільце + внутрішня тонка лінія
            Circle().strokeBorder(
                AngularGradient(colors: [tint, .white.opacity(0.9), tint.opacity(0.35), .white.opacity(0.75), tint],
                                center: .center), lineWidth: 1.3)
            Circle().strokeBorder(tint.opacity(0.35), lineWidth: 0.5).padding(2.4)
            Image(systemName: symbol)
                .font(.system(size: size * 0.3, weight: .bold))
                .foregroundStyle(onDark ? .white : tint)
                .shadow(color: .white.opacity(0.35), radius: 0, y: -0.6)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .drawingGroup()
    }
}


// MARK: Гравійовані елементи оформлення

/// Стрічка з плетених хвиль, як рамка банкноти, із написом по центру.
struct GuillocheRibbon: View {
    let label: String
    var height: CGFloat = 30

    var body: some View {
        ZStack {
            Canvas { ctx, sz in
                Engraving.band(in: &ctx, y: 0, width: sz.width, height: sz.height, lines: 9,
                               color: Theme.accent.opacity(0.55), lineWidth: 0.45)
            }
            Text(label)
                .font(.system(size: 9.5, weight: .bold)).tracking(2.2)
                .foregroundStyle(Theme.tint)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Theme.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.55), lineWidth: 0.6))
        }
        .frame(height: height)
        .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                                     .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                             startPoint: .leading, endPoint: .trailing))
    }
}

/// Заголовок дня: напис великими літерами, гравійована лінія, підсумок із засічками.
struct DayRibbon: View {
    let title: String
    let trailing: String
    var positive = false

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.6).foregroundStyle(Theme.tint)
            Rectangle().fill(LinearGradient(colors: [Theme.accent.opacity(0.6), Theme.accent.opacity(0)],
                                            startPoint: .leading, endPoint: .trailing))
                .frame(height: 0.6)
            Text(trailing).font(.system(.footnote, design: .serif).weight(.semibold)).monospacedDigit()
                .foregroundStyle(positive ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 4)
    }
}

/// Рядок реквізиту з пунктирним виводом між підписом і значенням, як у бухгалтерській книзі.
struct LeaderRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).foregroundStyle(.secondary)
            Canvas { ctx, sz in
                var p = Path()
                p.move(to: CGPoint(x: 0, y: sz.height - 3)); p.addLine(to: CGPoint(x: sz.width, y: sz.height - 3))
                ctx.stroke(p, with: .color(Theme.ink.opacity(0.22)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [0.1, 3.4]))
            }
            .frame(height: 12)
            Text(value).multilineTextAlignment(.trailing).monospacedDigit()
        }
        .font(.subheadline)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

/// Мікродрук: рядок дрібного тексту, який не читається на око, але видно в захисті.
struct Microprint: View {
    var text = "STATE TAX UNIVERSITY · TAXTECH · VIRTUAL FINANCE · "
    var body: some View {
        // Текст лежить в overlay: його довжина не бере участі в розкладці батьківського стеку.
        Color.clear.frame(height: 8)
            .overlay(alignment: .leading) {
                Text(String(repeating: text, count: 6))
                    .font(.system(size: 5.5, weight: .semibold, design: .monospaced)).tracking(1)
                    .lineLimit(1).fixedSize()
                    .foregroundStyle(Theme.accent.opacity(0.4))
            }
            .clipped()
    }
}

/// Перфорація: лінія з півколами по краях, як відривний корінець.
struct Perforation: View {
    var body: some View {
        Canvas { ctx, sz in
            var p = Path()
            p.move(to: CGPoint(x: 14, y: sz.height / 2)); p.addLine(to: CGPoint(x: sz.width - 14, y: sz.height / 2))
            ctx.stroke(p, with: .color(Theme.ink.opacity(0.25)), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 6]))
        }
        .frame(height: 14)
    }
}
