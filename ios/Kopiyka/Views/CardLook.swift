import SwiftUI

// MARK: Вигляд картки, який збирає користувач
// Ті самі значення, що приймає сервер (`PATCH /cards/{id}/style`, CardService._STYLE_CHOICES).

enum CardMaterial: String, CaseIterable, Identifiable, Codable, Sendable {
    case solid, gradient, metal, glass
    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: "Матова"
        case .gradient: "Градієнт"
        case .metal: "Метал"
        case .glass: "Скло"
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
        case .graphite: "Графіт"
        case .black: "Чорний"
        case .white: "Білий"
        case .gold: "Золото"
        case .navy: "Нічний синій"
        case .emerald: "Смарагд"
        case .burgundy: "Бордо"
        case .violet: "Фіалка"
        case .sky: "Небо"
        case .sand: "Пісок"
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
        case .none: "Без візерунка"
        case .guilloche: "Гільйош"
        case .microprint: "Мікродрук"
        case .lines: "Лінії"
        case .mark: "Знак"
        case .waves: "Хвилі"
        }
    }
}

enum CardEmblem: String, CaseIterable, Identifiable, Codable, Sendable {
    case none, seal, mark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "Без емблеми"
        case .seal: "Печатка"
        case .mark: "Знак"
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
        case .gold: self.init(material: .gradient, color: .gold, pattern: .guilloche)
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
            CardPatternLayer(pattern: look.pattern, ink: look.text)
                .opacity(look.material == .glass ? 0.8 : 1)
            if look.material == .metal { brushed }
            // відблиск зверху ліворуч: картка - предмет, а не плитка
            shape.fill(LinearGradient(colors: [.white.opacity(look.color.isLight ? 0.30 : 0.14), .clear],
                                      startPoint: .topLeading, endPoint: UnitPoint(x: 0.7, y: 0.6)))
            shape.strokeBorder(.white.opacity(look.material == .glass ? 0.45 : 0.18), lineWidth: look.material == .glass ? 1.2 : 0.75)
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
                let center = CGPoint(x: size.width * 0.78, y: size.height * 0.62)
                let r = size.height * 0.62
                for k in 0..<18 {
                    var p = Path()
                    let phase = Double(k) / 18 * .pi * 2
                    for i in 0...360 {
                        let t = Double(i) / 360 * .pi * 2
                        let rr = r * (0.72 + 0.28 * cos(7 * t + phase))
                        let pt = CGPoint(x: center.x + rr * cos(t), y: center.y + rr * sin(t))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                    ctx.stroke(p, with: .color(ink.opacity(0.11)), lineWidth: 0.6)
                }
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

/// Чип картки: золотий контакт із доріжками.
struct CardChip: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.93, green: 0.82, blue: 0.55), Color(red: 0.70, green: 0.55, blue: 0.28)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Canvas { ctx, size in
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: size.height / 3)); p.addLine(to: CGPoint(x: size.width, y: size.height / 3))
                    p.move(to: CGPoint(x: 0, y: size.height * 2 / 3)); p.addLine(to: CGPoint(x: size.width, y: size.height * 2 / 3))
                    p.move(to: CGPoint(x: size.width / 2, y: 0)); p.addLine(to: CGPoint(x: size.width / 2, y: size.height / 3))
                    p.move(to: CGPoint(x: size.width / 2, y: size.height * 2 / 3)); p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    ctx.stroke(p, with: .color(.black.opacity(0.28)), lineWidth: 0.8)
                }
            }
            .frame(width: 40, height: 30)
            .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
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
                Image(systemName: "building.columns.fill").font(.system(size: 13)).foregroundStyle(ink.opacity(0.8))
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
        CardPreset(title: "Обсидіан", look: CardLook(material: .metal, color: .black, pattern: .guilloche, emblem: .seal)),
        CardPreset(title: "Шампань", look: CardLook(material: .metal, color: .gold, pattern: .microprint, emblem: .seal)),
        CardPreset(title: "Аврора", look: CardLook(material: .gradient, color: .violet, pattern: .waves, emblem: .mark)),
        CardPreset(title: "Океан", look: CardLook(material: .glass, color: .sky, pattern: .waves)),
        CardPreset(title: "Смарагд", look: CardLook(material: .gradient, color: .emerald, pattern: .guilloche, emblem: .seal)),
        CardPreset(title: "Бордо", look: CardLook(material: .solid, color: .burgundy, pattern: .lines, emblem: .mark)),
        CardPreset(title: "Нічне місто", look: CardLook(material: .glass, color: .navy, pattern: .microprint)),
        CardPreset(title: "Пісок", look: CardLook(material: .solid, color: .sand, pattern: .none, emblem: .mark)),
        CardPreset(title: "Полярна", look: CardLook(material: .metal, color: .white, pattern: .lines)),
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
                        Text("CVV · дійсна до \(expiry ?? "—")")
                        Spacer()
                        Text("Тільки для навчання").opacity(0.7)
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
