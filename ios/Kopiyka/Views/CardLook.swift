import SwiftUI

// MARK: Вигляд картки, який збирає користувач
// Ті самі значення, що приймає сервер (`PATCH /cards/{id}/style`, CardService._STYLE_CHOICES).

enum CardMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case solid, gradient, metal, glass
    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: L("Матова").s
        case .gradient: L("Градієнт").s
        case .metal: L("Метал").s
        case .glass: L("Скло").s
        }
    }

    var symbol: String {
        switch self {
        case .solid: "square.fill"
        case .gradient: "square.lefthalf.filled"
        case .metal: "sparkles"
        case .glass: "drop"
        }
    }
}

enum CardColor: String, CaseIterable, Identifiable, Codable, Sendable {
    case graphite, black, white, gold, navy, emerald, burgundy, violet, sky, sand
    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphite: L("Графіт").s
        case .black: L("Чорний").s
        case .white: L("Білий").s
        case .gold: L("Золото").s
        case .navy: L("Нічний синій").s
        case .emerald: L("Смарагд").s
        case .burgundy: L("Бордо").s
        case .violet: L("Фіалка").s
        case .sky: L("Небо").s
        case .sand: L("Пісок").s
        }
    }

    var base: Color {
        switch self {
        case .graphite: Color(red: 0.19, green: 0.20, blue: 0.22)
        case .black: Color(white: 0.04)
        case .white: Color(red: 0.95, green: 0.95, blue: 0.93)
        case .gold: Color(red: 0.80, green: 0.64, blue: 0.35)
        case .navy: Color(red: 0.10, green: 0.16, blue: 0.32)
        case .emerald: Color(red: 0.04, green: 0.37, blue: 0.29)
        case .burgundy: Color(red: 0.42, green: 0.10, blue: 0.17)
        case .violet: Color(red: 0.32, green: 0.20, blue: 0.52)
        case .sky: Color(red: 0.50, green: 0.73, blue: 0.91)
        case .sand: Color(red: 0.85, green: 0.78, blue: 0.65)
        }
    }

    /// Друга точка градієнта: зсув відтінку, щоб градієнт жив, а не просто темнішав.
    var partner: Color {
        switch self {
        case .graphite: Color(red: 0.36, green: 0.38, blue: 0.42)
        case .black: Color(red: 0.18, green: 0.18, blue: 0.24)
        case .white: Color(red: 0.80, green: 0.84, blue: 0.90)
        case .gold: Color(red: 0.55, green: 0.38, blue: 0.16)
        case .navy: Color(red: 0.22, green: 0.38, blue: 0.68)
        case .emerald: Color(red: 0.10, green: 0.62, blue: 0.52)
        case .burgundy: Color(red: 0.75, green: 0.22, blue: 0.30)
        case .violet: Color(red: 0.70, green: 0.36, blue: 0.70)
        case .sky: Color(red: 0.62, green: 0.55, blue: 0.92)
        case .sand: Color(red: 0.92, green: 0.62, blue: 0.48)
        }
    }

    var isLight: Bool { [.white, .gold, .sky, .sand].contains(self) }
}

enum CardPattern: String, CaseIterable, Identifiable, Codable, Sendable {
    case none, guilloche, microprint, lines, mark, waves
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: L("Без візерунка").s
        case .guilloche: L("Гільйош").s
        case .microprint: L("Мікродрук").s
        case .lines: L("Лінії").s
        case .mark: L("Знак").s
        case .waves: L("Хвилі").s
        }
    }
}

enum CardEmblem: String, CaseIterable, Identifiable, Codable, Sendable {
    case none, seal, mark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: L("Без емблеми").s
        case .seal: L("Печатка").s
        case .mark: L("Знак").s
        }
    }
}

/// Зібраний вигляд картки. Порожня назва - на картці бренд.
struct CardLook: Codable, Equatable, Sendable {
    var material: CardMaterial = .solid
    var color: CardColor = .graphite
    var pattern: CardPattern = .mark
    var emblem: CardEmblem = .none
    var name: String = ""

    static let nameLimit = 24

    /// Старі дизайни (`design`) у новій мові - щоб картки без власного вигляду теж мали чип, візерунок і матеріал.
    init(legacy design: CardDesign) {
        switch design {
        case .dark: self.init(material: .solid, color: .black, pattern: .mark)
        case .slate: self.init(material: .solid, color: .graphite, pattern: .mark)
        case .navy: self.init(material: .metal, color: .graphite, pattern: .lines)
        case .forest: self.init(material: .solid, color: .white, pattern: .mark)
        case .gold: self.init(material: .solid, color: .black, pattern: .guilloche)
        case .rose: self.init(material: .glass, color: .graphite, pattern: .waves)
        }
    }

    init(material: CardMaterial = .solid, color: CardColor = .graphite, pattern: CardPattern = .mark,
         emblem: CardEmblem = .none, name: String = "") {
        self.material = material
        self.color = color
        self.pattern = pattern
        self.emblem = emblem
        self.name = name
    }

    static func random() -> CardLook {
        CardLook(material: CardMaterial.allCases.randomElement()!, color: CardColor.allCases.randomElement()!,
                 pattern: CardPattern.allCases.randomElement()!, emblem: CardEmblem.allCases.randomElement()!)
    }

    var text: Color { color.isLight && material != .glass ? Color(white: 0.08) : .white }
}

extension API.Card {
    /// Вигляд для показу: власний, якщо зібраний, інакше - зі старого дизайну.
    var look: CardLook { style ?? CardLook(legacy: CardDesign(server: design)) }
}

// MARK: Малювання

/// Тло картки: матеріал, колір і візерунок, без тексту.
struct CardSurface: View {
    let look: CardLook
    var corner: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            fill
            CardPatternLayer(pattern: look.pattern, ink: look.color == .black && look.pattern == .guilloche ? Theme.goldLight : look.text)
                .opacity(look.material == .glass ? 0.8 : 1)
            if look.material == .metal { brushed }
            CardGrain(light: look.color.isLight)
            // відблиск зверху ліворуч: картка - предмет, а не плитка
            shape.fill(LinearGradient(colors: [.white.opacity(look.color.isLight ? 0.30 : 0.14), .clear],
                                      startPoint: .topLeading, endPoint: UnitPoint(x: 0.7, y: 0.6)))
            // м'яка діагональна смуга глянцю
            shape.fill(LinearGradient(stops: [
                .init(color: .clear, location: 0.30),
                .init(color: .white.opacity(look.color.isLight ? 0.22 : 0.09), location: 0.42),
                .init(color: .white.opacity(look.color.isLight ? 0.10 : 0.03), location: 0.52),
                .init(color: .clear, location: 0.64),
            ], startPoint: UnitPoint(x: 0.1, y: 0.0), endPoint: UnitPoint(x: 0.9, y: 1.0)))
            // фаска: світла кромка зверху-ліворуч, темна знизу-праворуч, і внутрішня тонка лінія
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(look.material == .glass ? 0.55 : 0.38), .white.opacity(0.04),
                                                       .black.opacity(0.35)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                               lineWidth: look.material == .glass ? 1.2 : 1)
            RoundedRectangle(cornerRadius: max(corner - 1.5, 2), style: .continuous)
                .strokeBorder(.white.opacity(0.07), lineWidth: 0.5).padding(1.5)
            // гравійована рамка всередині краю: тонка лінія
            if look.pattern == .guilloche {
                RoundedRectangle(cornerRadius: max(corner - 5, 4), style: .continuous)
                    .strokeBorder(look.text.opacity(0.16), lineWidth: 0.5).padding(5)
            }
        }
        .clipShape(shape)
    }

    @ViewBuilder private var fill: some View {
        let c = look.color
        switch look.material {
        case .solid:
            c.base
        case .gradient:
            LinearGradient(colors: [c.partner, c.base], startPoint: .topTrailing, endPoint: .bottomLeading)
                .overlay(RadialGradient(colors: [c.partner.opacity(0.7), .clear], center: .bottomTrailing,
                                        startRadius: 0, endRadius: 260))
        case .metal:
            LinearGradient(stops: [
                .init(color: c.base, location: 0),
                .init(color: c.partner, location: 0.38),
                .init(color: .white.opacity(0.85).mix(with: c.base, by: 0.55), location: 0.5),
                .init(color: c.partner, location: 0.62),
                .init(color: c.base, location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .glass:
            ZStack {
                LinearGradient(colors: [c.base.opacity(0.85), c.partner.opacity(0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Rectangle().fill(.ultraThinMaterial).opacity(0.55)
            }
        }
    }

    /// Шліфування металу: тонкі горизонтальні риски.
    private var brushed: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            var seed: UInt64 = 7
            while y < size.height {
                seed = seed &* 6364136223846793005 &+ 1
                let a = Double(seed >> 58) / 64
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(.white.opacity(0.03 + a * 0.06)), lineWidth: 0.5)
                y += 1.5
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

/// Візерунок захисного друку поверх заливки.
struct CardPatternLayer: View {
    let pattern: CardPattern
    let ink: Color

    var body: some View {
        switch pattern {
        case .none:
            Color.clear
        case .mark:
            GeometryReader { g in
                Image("Mark")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(height: g.size.height * 1.05)
                    .foregroundStyle(ink.opacity(0.1))
                    .position(x: g.size.width * 0.86, y: g.size.height * 0.72)
            }
        case .guilloche:
            Canvas { ctx, size in
                // головна розетка праворуч, мала ліворуч-вгорі: два центри дають муар на перетині
                let main = CGPoint(x: size.width * 0.78, y: size.height * 0.60)
                let r = size.height * 0.68
                Engraving.rosette(in: &ctx, center: main, radius: r, curves: 30, lobes: 7, depth: 0.26, second: 0.07,
                                  steps: 300, color: ink.opacity(0.10), width: 0.45)
                Engraving.rosette(in: &ctx, center: main, radius: r * 0.52, curves: 18, lobes: 5, depth: 0.22, second: 0.06,
                                  steps: 200, color: ink.opacity(0.14), width: 0.4)
                Engraving.rings(in: &ctx, center: main, from: r * 0.06, to: r * 0.2, count: 6, color: ink.opacity(0.16))
                let small = CGPoint(x: size.width * 0.12, y: size.height * 0.18)
                Engraving.rosette(in: &ctx, center: small, radius: size.height * 0.34, curves: 16, lobes: 6, depth: 0.24,
                                  second: 0.06, steps: 160, color: ink.opacity(0.08), width: 0.4)
                // смуги плетених хвиль уздовж верху й низу
                Engraving.band(in: &ctx, y: 6, width: size.width, height: 9, lines: 6, color: ink.opacity(0.10))
                Engraving.band(in: &ctx, y: size.height - 15, width: size.width, height: 9, lines: 6, color: ink.opacity(0.10))
            }
        case .microprint:
            Canvas { ctx, size in
                let line = String(repeating: "TAXTECH · VIRTUAL · ", count: 8)
                var y: CGFloat = 4
                var row = 0
                while y < size.height {
                    let text = Text(line).font(.system(size: 5, weight: .medium, design: .monospaced))
                        .foregroundStyle(ink.opacity(0.13))
                    ctx.draw(text, at: CGPoint(x: row.isMultiple(of: 2) ? 0 : -18, y: y), anchor: .topLeading)
                    y += 7
                    row += 1
                }
            }
        case .lines:
            Canvas { ctx, size in
                var x: CGFloat = -size.height
                while x < size.width {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    ctx.stroke(p, with: .color(ink.opacity(0.08)), lineWidth: 1)
                    x += 9
                }
            }
        case .waves:
            Canvas { ctx, size in
                for k in 0..<14 {
                    var p = Path()
                    let base = size.height * (0.25 + Double(k) * 0.055)
                    for i in 0...80 {
                        let x = size.width * Double(i) / 80
                        let y = base + sin(Double(i) / 80 * .pi * 2.4 + Double(k) * 0.35) * size.height * 0.08
                        i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                    }
                    ctx.stroke(p, with: .color(ink.opacity(0.12)), lineWidth: 0.8)
                }
            }
        }
    }
}

/// Чип EMV: золота пластина з контактними майданчиками, фаскою й бліком.
struct CardChip: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(stops: [
                .init(color: Color(red: 0.97, green: 0.88, blue: 0.62), location: 0),
                .init(color: Color(red: 0.84, green: 0.68, blue: 0.36), location: 0.5),
                .init(color: Color(red: 0.66, green: 0.50, blue: 0.24), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            Canvas { ctx, size in
                let w = size.width, h = size.height
                let line = Color.black.opacity(0.32)
                var p = Path()
                // дві горизонтальні розділові лінії
                p.move(to: CGPoint(x: 0, y: h * 0.34)); p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.34))
                p.move(to: CGPoint(x: w * 0.70, y: h * 0.34)); p.addLine(to: CGPoint(x: w, y: h * 0.34))
                p.move(to: CGPoint(x: 0, y: h * 0.66)); p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.66))
                p.move(to: CGPoint(x: w * 0.70, y: h * 0.66)); p.addLine(to: CGPoint(x: w, y: h * 0.66))
                // центральна пластина
                p.addRoundedRect(in: CGRect(x: w * 0.30, y: h * 0.18, width: w * 0.40, height: h * 0.64),
                                 cornerSize: CGSize(width: 3, height: 3))
                // стики до центру
                p.move(to: CGPoint(x: w * 0.30, y: h * 0.5)); p.addLine(to: CGPoint(x: 0, y: h * 0.5))
                p.move(to: CGPoint(x: w * 0.70, y: h * 0.5)); p.addLine(to: CGPoint(x: w, y: h * 0.5))
                ctx.stroke(p, with: .color(line), lineWidth: 0.7)
            }
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.65), .black.opacity(0.3)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            shape.fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: UnitPoint(x: 0.6, y: 0.5)))
        }
        .frame(width: 42, height: 32)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.28), radius: 1.2, y: 0.8)
    }
}

/// Знак безконтактної оплати (NFC): чотири дуги.
struct ContactlessMark: View {
    var body: some View {
        Canvas { ctx, size in
            let origin = CGPoint(x: size.width * 0.12, y: size.height / 2)
            for i in 0..<4 {
                let r = size.height * (0.18 + 0.2 * Double(i))
                var p = Path()
                p.addArc(center: origin, radius: r, startAngle: .degrees(-42), endAngle: .degrees(42), clockwise: false)
                ctx.stroke(p, with: .foreground, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            }
        }
        .frame(width: 22, height: 24)
    }
}

/// Дрібне зерно пластику: статичний детермінований шум, щоб заливка не була цифрово гладкою.
struct CardGrain: View {
    let light: Bool

    var body: some View {
        Canvas { ctx, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            let count = Int(size.width * size.height / 14)
            for _ in 0..<count {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let x = Double(seed >> 40 & 0xFFFF) / 65535 * size.width
                let y = Double(seed >> 24 & 0xFFFF) / 65535 * size.height
                let a = Double(seed >> 58) / 64
                let color: Color = seed & 1 == 0 ? .white : .black
                ctx.fill(Path(CGRect(x: x, y: y, width: 0.8, height: 0.8)),
                         with: .color(color.opacity((light ? 0.05 : 0.04) + a * 0.05)))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

/// Емблема в правому верхньому куті.
struct CardEmblemView: View {
    let emblem: CardEmblem
    let ink: Color

    var body: some View {
        switch emblem {
        case .none: EmptyView()
        case .seal:
            ZStack {
                Circle().strokeBorder(ink.opacity(0.55), lineWidth: 1)
                Circle().strokeBorder(ink.opacity(0.35), style: StrokeStyle(lineWidth: 0.8, dash: [1.5, 2])).padding(3)
                Image("Mark").renderingMode(.template).resizable().scaledToFit()
                    .frame(height: 14).foregroundStyle(ink.opacity(0.8))
            }
            .frame(width: 34, height: 34)
        case .mark:
            Image("Mark").renderingMode(.template).resizable().scaledToFit()
                .frame(height: 26).foregroundStyle(ink.opacity(0.85))
        }
    }
}

// MARK: Колекції - готові вигляди одним дотиком

struct CardPreset: Identifiable {
    let title: String
    let look: CardLook
    var id: String { title }

    static let all: [CardPreset] = [
        CardPreset(title: L("Обсидіан").s, look: CardLook(material: .metal, color: .black, pattern: .guilloche, emblem: .seal)),
        CardPreset(title: L("Шампань").s, look: CardLook(material: .metal, color: .gold, pattern: .microprint, emblem: .seal)),
        CardPreset(title: L("Аврора").s, look: CardLook(material: .gradient, color: .violet, pattern: .waves, emblem: .mark)),
        CardPreset(title: L("Океан").s, look: CardLook(material: .glass, color: .sky, pattern: .waves)),
        CardPreset(title: L("Смарагд").s, look: CardLook(material: .gradient, color: .emerald, pattern: .guilloche, emblem: .seal)),
        CardPreset(title: L("Бордо").s, look: CardLook(material: .solid, color: .burgundy, pattern: .lines, emblem: .mark)),
        CardPreset(title: L("Нічне місто").s, look: CardLook(material: .glass, color: .navy, pattern: .microprint)),
        CardPreset(title: L("Пісок").s, look: CardLook(material: .solid, color: .sand, pattern: .none, emblem: .mark)),
        CardPreset(title: L("Полярна").s, look: CardLook(material: .metal, color: .white, pattern: .lines)),
    ]
}

// MARK: Голограма й зворот

/// Райдужний перелив, що їде за нахилом телефона: метал і скло виглядають як справжні.
struct HoloSheen: View {
    let look: CardLook
    @State private var tilt = DeviceTilt.shared
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let x = reduce ? 0 : tilt.x, y = reduce ? 0 : tilt.y
        let strength: Double = switch look.material {
        case .metal: 0.32
        case .glass: 0.26
        case .gradient: 0.14
        case .solid: 0.06
        }
        AngularGradient(colors: [.pink, .orange, .yellow, .green, .cyan, .blue, .purple, .pink],
                        center: UnitPoint(x: 0.5 + x * 0.6, y: 0.5 + y * 0.6),
                        angle: .degrees(x * 120 + y * 60))
            .blur(radius: 18)
            .opacity(strength)
            .blendMode(look.color.isLight ? .multiply : .overlay)
            .allowsHitTesting(false)
            .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.85), value: x)
    }
}

/// Зворот картки: магнітна смуга, підпис із CVV, повний номер.
struct CardBack: View {
    let look: CardLook
    let number: String
    let cvv: String
    let expiry: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            CardSurface(look: CardLook(material: look.material, color: look.color, pattern: .none))
            VStack(alignment: .leading, spacing: 14) {
                Rectangle().fill(.black.opacity(0.85)).frame(height: 40).padding(.top, 22)
                HStack(spacing: 10) {
                    // смуга підпису з дрібним візерунком
                    ZStack(alignment: .leading) {
                        Rectangle().fill(.white.opacity(0.9))
                        CardPatternLayer(pattern: .lines, ink: .black).opacity(0.6)
                    }
                    .frame(height: 34)
                    Text(cvv)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .background(.white, in: .rect(cornerRadius: 4))
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text(number)
                        .font(.system(.title3, design: .monospaced, weight: .medium))
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .textSelection(.enabled)
                    HStack {
                        Text(L("CVV · дійсна до \(expiry ?? "—")").s)
                        Spacer()
                        Text(L("Тільки для навчання").s).opacity(0.7)
                    }
                    .font(.caption2.weight(.semibold))
                }
                .padding(.horizontal, 20)
                .foregroundStyle(look.text)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
    }
}

/// Перевертає вміст навколо вертикальної осі: лице до 90°, далі зворот (кут анімується, тож заміна - рівно на ребрі).
struct FlipCard<Front: View, Back: View>: View, @preconcurrency Animatable {
    var angle: Double
    let front: Front
    let back: Back

    init(flipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        angle = flipped ? 180 : 0
        self.front = front()
        self.back = back()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        ZStack {
            front.opacity(angle < 90 ? 1 : 0)
            back.opacity(angle < 90 ? 0 : 1)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
    }
}
