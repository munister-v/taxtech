import SwiftUI

/// Назва й позиціонування. Одне місце, щоб не розходилось між екранами.
enum Brand {
    static let name = "TaxTech"
    static var lab: String { L("Віртуальна лабораторія цифрових фінансів і технологій розподіленого реєстру").s }
}

/// Візуальна мова TaxTech: чорне тло й теплий папір, один сигнальний жовтий - колір токена TAX.
/// Без градієнтів: різницю дають площини кольору, вага шрифту й тонкі лінії.
enum Theme {
    static let corner: CGFloat = 20
    static let gutter: CGFloat = 16
    static let hairline: CGFloat = 0.5

    /// Тема одна - темна. Пари (світла, темна) лишилися з часів двох тем: береться темне значення.
    private static func dynamic(light: UInt32, dark: UInt32) -> Color { Color(UIColor(hex: dark)) }

    static let bg = dynamic(light: 0xF2F2F5, dark: 0x050504)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x171614)
    static let line = dynamic(light: 0xE3E3E8, dark: 0x3A3427)
    static let ink = dynamic(light: 0x111114, dark: 0xF2F2F5)
    /// Текст на заливці кольору тексту.
    static let onInk = dynamic(light: 0xFFFFFF, dark: 0x111114)
    /// Світле золото - єдиний акцент: головні кнопки, вибране, суми TAX.
    static let accent = Color(UIColor(hex: 0xDCC195))
    /// Збій у досліді: розбіжність, підробка, високий ризик.
    static let alert = Color(UIColor(hex: 0xE05A47))
    /// Текст на жовтому - завжди чорний.
    static let onAccent = Color(UIColor(hex: 0x0E0E0C))
    /// Колір вибраного: золото.
    static let tint = dynamic(light: 0x0E0E0C, dark: 0xDCC195)
    /// Тепле золото лендингу: рамки, капітелі, гільйош.
    static let gold = Color(UIColor(hex: 0xC7A46F))
    static let goldLight = Color(UIColor(hex: 0xDCC195))
    /// Палітра фону: шампанське золото й глибокий графітово-синій. Без жовтого й бірюзового, що давали болотний відтінок.
    static let auraGold = Color(UIColor(hex: 0xC7A46F))
    static let auraCool = Color(UIColor(hex: 0x2A3F66))
    static let auraBronze = Color(UIColor(hex: 0x8A5A3C))
    /// Золотий градієнт для великих цифр і заголовків.
    static let goldFill = LinearGradient(colors: [Color(UIColor(hex: 0xDCC195)), Color(UIColor(hex: 0xDCC195))],
                                         startPoint: .top, endPoint: .bottom)
    /// Золота волоскова рамка поверхні: світліша зверху-ліворуч, тихіша в середині.
    static let edge = LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom)
    /// Плита: єдина поверхня всіх карток і панелей. Суцільна заливка замість розмиття тла - її не треба
    /// перераховувати на кожен кадр прокрутки.
    static let plate = LinearGradient(colors: [Color(UIColor(hex: 0x211F1B)).opacity(0.94), Color(UIColor(hex: 0x141311)).opacity(0.94)],
                                      startPoint: .top, endPoint: .bottom)
    /// Кромка плити: світліша зверху-ліворуч, майже зникає внизу.
    static let rim = LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.07), .white.opacity(0.03)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
    /// Напівпрозора підкладка кнопок і плиток на місці колишнього матеріалу.
    static let frost = Color(UIColor(white: 0.62, alpha: 0.16))

    static func balance(_ size: CGFloat = 46) -> Font {
        Theme.mono(size, .bold)
    }

    /// Відтінок за місцем у переліку: найбільша категорія найтемніша.
    static func shade(_ rank: Int) -> Color {
        ink.opacity(max(0.14, 1 - 0.17 * Double(rank)))
    }
}

private extension UIColor {
    convenience init(hex v: UInt32) {
        self.init(red: CGFloat(v >> 16 & 0xFF) / 255, green: CGFloat(v >> 8 & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }
}

extension View {
    /// Тло екрана.
    func screenBackground(_ style: BackdropStyle = .logo) -> some View {
        background { GlassAura(style: style).ignoresSafeArea() }
    }

    /// Скляна панель: матеріал, світлий торець зверху, тонка лінія, м'яка тінь.
    func glass(_ radius: CGFloat = 22) -> some View {
        background(Theme.plate, in: .rect(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.rim, lineWidth: 0.8)
            }
    }

    /// Контент, що з'їжджає вгору, розчиняється під годинником, а не налазить на нього.
    /// `amount` 0...1: у спокої затемнення не видно, воно проявляється разом із прокруткою.
    func statusScrim(_ amount: CGFloat = 1) -> some View {
        overlay(alignment: .top) {
            Rectangle().fill(.ultraThinMaterial)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.55), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 76)
                .ignoresSafeArea(edges: .top)
                .opacity(amount)
                .allowsHitTesting(false)
        }
    }

    /// Тло форми: без стандартного тла груп.
    func labForm() -> some View {
        scrollContentBackground(.hidden).screenBackground()
    }
}

/// Форма на плоских поверхнях лабораторії замість стандартних груп iOS.
struct LabForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            Group { content }.listRowBackground(Theme.surface)
        }
        .tint(Theme.ink)
    }
}

// MARK: Знак

/// Знак лабораторії - векторний, малюється кольором тексту.
struct MarkView: View {
    var height: CGFloat = 44
    var color: Color = Theme.ink

    var body: some View {
        Image("Mark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}

// MARK: Типографіка

extension View {
    /// Мала підпис-мітка над блоком: капітель, розряджений набір.
    func caption() -> some View {
        font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
    }

    /// Золота волоскова рамка, як на панелях лендингу.
    func goldEdge(_ radius: CGFloat = 22) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Theme.edge, lineWidth: 0.8))
    }
}

// MARK: Поверхні

/// Плоска поверхня: біла (в темній темі - графітова) площина з тонкою лінією по краю, без градієнтів і тіней.
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .clipShape(.rect(cornerRadius: 22, style: .continuous))
            .glass(22)
    }
}

/// Тло під склом: темна основа з двома розмитими золотими й бірюзовими плямами.
struct GlassAura: View {
    var style: BackdropStyle = .logo
    var body: some View {
        // тло нерухоме й зведене в одну текстуру: воно лежить під кожним екраном, тож не має коштувати нічого
        ZStack {
            Theme.bg
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                SoftOrb(color: Theme.auraGold.opacity(0.24), radius: w * 0.42, blur: 110)
                    .position(x: w * 0.10, y: w * 0.22)
                SoftOrb(color: Theme.auraCool.opacity(0.42), radius: w * 0.40, blur: 120)
                    .position(x: w * 0.92, y: h * 0.46 + w * 0.40)
                SoftOrb(color: Theme.auraBronze.opacity(0.14), radius: w * 0.30, blur: 100)
                    .position(x: w * 0.30, y: h * 0.58 + w * 0.30)
            }
            LogoBackdrop(style: style)
            // глибина: низ екрана темніший, картки на ньому читаються чіткіше
            LinearGradient(colors: [.clear, Theme.bg.opacity(0.55)], startPoint: .center, endPoint: .bottom)
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// М'яка пляма кольору: те саме, що коло під .blur, але як радіальний градієнт - без фільтра на кожен кадр.
struct SoftOrb: View {
    let color: Color
    let radius: CGFloat
    var blur: CGFloat = 70

    var body: some View {
        let outer = max(radius + blur * 1.3, 1)
        let core = max(radius - blur, 0) / outer
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: color, location: 0),
                .init(color: color, location: core),
                .init(color: color.opacity(0.5), location: radius / outer),
                .init(color: color.opacity(0.12), location: (radius + blur * 0.7) / outer),
                .init(color: color.opacity(0), location: 1),
            ], center: .center, startRadius: 0, endRadius: outer))
            .frame(width: outer * 2, height: outer * 2)
    }
}

extension View {
    /// Повільний нескінченний дрейф: вмикається, коли екран видно, і зупиняється, коли його сховали.
    func drift(reduce: Bool, _ a: Binding<Bool>, _ da: Double, _ b: Binding<Bool>? = nil, _ db: Double = 0) -> some View {
        onAppear {
            guard !reduce else { return }
            withAnimation(.easeInOut(duration: da).repeatForever(autoreverses: true)) { a.wrappedValue = true }
            if let b { withAnimation(.easeInOut(duration: db).repeatForever(autoreverses: true)) { b.wrappedValue = true } }
        }
        .onDisappear {
            var t = Transaction(); t.disablesAnimations = true
            withTransaction(t) { a.wrappedValue = false; b?.wrappedValue = false }
        }
    }
}

/// Затухання тла під рядком стану: заголовки не налазять на годинник при прокрутці.
struct TopFade: View {
    var body: some View {
        GeometryReader { g in
            let top = g.safeAreaInsets.top
            LinearGradient(stops: [
                .init(color: Theme.bg, location: 0),
                .init(color: Theme.bg.opacity(0.96), location: top / (top + 10)),
                .init(color: Theme.bg.opacity(0), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .frame(height: top + 10)
            .offset(y: -top)
        }
        .allowsHitTesting(false)
    }
}

/// Заголовок блоку над поверхнею.
struct BlockTitle: View {
    let text: String
    var trailing: String?

    init(_ text: String, trailing: String? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(Theme.mono(19, .bold))
            Spacer()
            if let trailing {
                Text(trailing).font(Theme.ui(style: .subheadline, .semibold)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

/// Тонка роздільна лінія між рядками поверхні.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Theme.line, Theme.line, .clear], startPoint: .leading, endPoint: .trailing))
            .frame(height: Theme.hairline).padding(.horizontal, 16)
    }
}

/// Головна дія: плоска жовта капсула з чорним текстом. Жовтий - єдиний акцент, тож лише тут і на головних значках.
struct InkButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(style: .body, .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                Capsule().fill(LinearGradient(colors: [Theme.goldLight, Theme.accent], startPoint: .top, endPoint: .bottom))
                    .brightness(configuration.isPressed ? -0.08 : 0)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 0.8).mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)))
            .shadow(color: Theme.accent.opacity(enabled ? 0.28 : 0), radius: configuration.isPressed ? 4 : 10, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, new in new }
            .opacity(enabled ? 1 : 0.35)
    }
}

/// Другорядна дія: плоска капсула з тонким контуром.
struct LineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(style: .body, .medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.frost, in: .capsule)
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom), lineWidth: 0.9))
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Ряд дій: гліф над підписом, у спільній плоскій поверхні, між діями - тонкі лінії.
struct ActionBar: View {
    struct Item: Identifiable {
        let title: String
        let symbol: String
        let action: () -> Void
        var id: String { title }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                if i > 0 { Rectangle().fill(Theme.line).frame(width: Theme.hairline).padding(.vertical, 14) }
                Button(action: item.action) {
                    VStack(spacing: 8) {
                        Image(systemName: item.symbol)
                            .font(Theme.ui(19, .regular))
                            .frame(height: 24)
                        Text(item.title).font(Theme.ui(style: .footnote, .medium)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .glass(Theme.corner)
        .sensoryFeedback(.selection, trigger: items.count)
    }
}

/// Рядок у поверхні: назва, підпис, сума праворуч.
struct AmountRow: View {
    let title: String
    let subtitle: String
    let amount: String
    /// Надходження виділяємо вагою шрифту, списання - спокійніші.
    var positive = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).lineLimit(2)
                Text(subtitle)
                    .font(Theme.ui(style: .footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(Theme.ui(style: .body, positive ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(positive ? Theme.ink : Theme.ink.opacity(0.82))
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: Картка

/// Дизайни віртуальної картки - ті самі ідентифікатори, що приймає сервер (`PATCH /cards/{id}/design`).
/// Усі плоскі: заливка, колір тексту, знак-водяний на кутку.
enum CardDesign: String, CaseIterable, Identifiable {
    case dark, slate, navy, forest, gold, rose

    var id: String { rawValue }

    init(server: String?) { self = CardDesign(rawValue: server ?? "") ?? .dark }

    var title: String {
        switch self {
        case .dark: L("Чорний").s
        case .slate: L("Графіт").s
        case .navy: L("Сталь").s
        case .forest: L("Білий").s
        case .gold: L("Золото").s
        case .rose: L("Скло").s
        }
    }

    var fill: Color {
        switch self {
        case .dark: Color(white: 0)
        case .slate: Color(white: 0.17)
        case .navy: Color(white: 0.56)
        case .forest: Color(white: 0.85)
        case .gold: Theme.accent
        case .rose: .clear
        }
    }

    var text: Color {
        switch self {
        case .dark, .slate: .white
        case .navy, .forest, .gold: .black
        case .rose: Theme.ink
        }
    }

    /// Рамка потрібна там, де заливка зливається з тлом екрана.
    var border: Color? {
        switch self {
        case .dark: Color.white.opacity(0.25)
        case .rose: Theme.ink
        default: nil
        }
    }
}

/// Віртуальна картка: матеріал, колір і візерунок з `CardLook`, чип, безконтакт, власна назва.
struct VirtualCardView: View {
    let number: String
    let expiry: String?
    let holder: String?
    var design = CardDesign.dark
    /// Зібраний вигляд; без нього картка малюється зі старого дизайну.
    var look: CardLook?
    var frozen = false
    var compact = false

    private var resolved: CardLook { look ?? CardLook(legacy: design) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        ZStack {
            CardSurface(look: resolved, corner: corner).equatable()
            if !compact { HoloSheen(look: resolved).clipShape(shape) }
            if !compact { face }
            if frozen {
                shape.fill(.black.opacity(0.62))
                Label(L("Заморожена").s, systemImage: "snowflake")
                    .font(compact ? .caption2 : .headline)
                    .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
                    .foregroundStyle(.white)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(shape)
        .shadow(color: .black.opacity(compact ? 0.12 : 0.28), radius: compact ? 4 : 16, y: compact ? 2 : 10)
    }

    private var corner: CGFloat { compact ? 8 : 18 }

    private var face: some View {
        let l = resolved
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.name.isEmpty ? Brand.name : l.name)
                        .font(Theme.mono(style: .title3, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !l.name.isEmpty {
                        Text(Brand.name.uppercased()).font(Theme.ui(style: .caption2, .semibold)).tracking(1.4).opacity(0.6)
                    }
                }
                Spacer()
                CardEmblemView(emblem: l.emblem, ink: l.text)
            }
            Spacer(minLength: 6)
            HStack(spacing: 12) {
                CardChip()
                ContactlessMark().opacity(0.8)
            }
            Spacer(minLength: 6)
            // тиснений номер: світла кромка зверху-ліворуч і тінь знизу-праворуч
            Text(number)
                .font(Theme.ui(21, .bold)).tracking(1.6).monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .shadow(color: .white.opacity(l.color.isLight ? 0.55 : 0.28), radius: 0, x: -0.6, y: -0.6)
                .shadow(color: .black.opacity(l.color.isLight ? 0.28 : 0.5), radius: 0.6, x: 0.7, y: 0.9)
            HStack(alignment: .lastTextBaseline) {
                Text(holder ?? "").lineLimit(1)
                Spacer()
                if let expiry { Text(expiry).monospacedDigit() }
                Text(L("ВІРТУАЛЬНА").s).font(Theme.ui(9, .bold)).tracking(1.4).opacity(0.7)
                NetworkMark().padding(.leading, 4)
            }
            .font(Theme.ui(style: .caption1, .medium))
            .opacity(0.85)
            .padding(.top, 10)
        }
        .padding(20)
        .foregroundStyle(l.text)
    }
}

/// Стиль підпису, обраний під час виконання.
struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView
    init<S: LabelStyle>(_ style: S) { make = { AnyView(Label($0).labelStyle(style)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}


/// Знак на картці: власний логотип у золоті.
struct NetworkMark: View {
    var body: some View {
        Image("Mark").renderingMode(.template).resizable().scaledToFit()
            .frame(height: 26)
            .foregroundStyle(LinearGradient(colors: [Theme.goldLight, Theme.gold], startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}


enum BackdropStyle { case logo, orbit, grid, hatch, clean }

/// Графіка у стилі логотипу за склом: у кожного розділу своя конструкція.
struct LogoBackdrop: View {
    var style: BackdropStyle = .logo
    private let gold = Theme.auraGold

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            switch style {
            case .clean:
                // головна: лише тонкі кільця в куті, без знаків - там говорять баланс і картка
                Canvas { ctx, size in
                    var r = ctx; r.opacity = 0.20
                    Engraving.rings(in: &r, center: CGPoint(x: size.width * 1.02, y: size.height * 0.16),
                                    from: 50, to: size.width * 0.9, count: 16, color: gold)
                }
            case .logo:
                Canvas { ctx, size in
                    var r = ctx; r.opacity = 0.26
                    Engraving.rings(in: &r, center: CGPoint(x: size.width * 0.95, y: size.height * 0.18),
                                    from: 40, to: size.width * 0.75, count: 14, color: gold)
                    var q = ctx; q.opacity = 0.18
                    Engraving.rosette(in: &q, center: CGPoint(x: size.width * 0.05, y: size.height * 0.78),
                                      radius: size.width * 0.62, curves: 36, lobes: 9, color: gold)
                }
                mark(w * 1.1, 0.05).rotationEffect(.degrees(-14)).position(x: w * 0.9, y: h * 0.72)
                mark(w * 0.42, 0.07, tint: gold).rotationEffect(.degrees(12)).position(x: w * 0.12, y: h * 0.2)
            case .orbit:
                Canvas { ctx, size in
                    let c = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
                    var r = ctx; r.opacity = 0.30
                    Engraving.rings(in: &r, center: c, from: 30, to: size.width * 0.95, count: 22, color: gold)
                    var q = ctx; q.opacity = 0.16
                    Engraving.rosette(in: &q, center: c, radius: size.width * 0.5, curves: 30, lobes: 12, color: gold)
                }
                mark(w * 0.55, 0.10, tint: gold).position(x: w * 0.5, y: h * 0.34)
            case .grid:
                let step: CGFloat = 64
                let cols = Int(w / step) + 2, rows = Int(h / step) + 2
                ForEach(0..<rows, id: \.self) { j in
                    ForEach(0..<cols, id: \.self) { i in
                        Image("Mark").renderingMode(.template).resizable().scaledToFit()
                            .frame(width: 22)
                            .foregroundStyle(Color.white.opacity(0.07))
                            .rotationEffect(.degrees((i + j) % 2 == 0 ? 0 : 90))
                            .position(x: CGFloat(i) * step + (j % 2 == 0 ? 0 : step / 2), y: CGFloat(j) * step)
                    }
                }
            case .hatch:
                Canvas { ctx, size in
                    var p = Path()
                    var x: CGFloat = -size.height
                    while x < size.width { p.move(to: CGPoint(x: x, y: size.height)); p.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 14 }
                    ctx.stroke(p, with: .color(gold.opacity(0.10)), lineWidth: 0.5)
                    var r = ctx; r.opacity = 0.22
                    Engraving.rings(in: &r, center: CGPoint(x: size.width, y: size.height * 0.9), from: 30, to: size.width * 0.7, count: 12, color: gold)
                }
                mark(w * 0.9, 0.06).rotationEffect(.degrees(20)).position(x: w * 0.15, y: h * 0.62)
            }
        }
    }

    private func mark(_ size: CGFloat, _ opacity: Double, tint: Color = .white) -> some View {
        Image("Mark").renderingMode(.template).resizable().scaledToFit()
            .frame(width: size).foregroundStyle(tint.opacity(opacity))
    }
}
