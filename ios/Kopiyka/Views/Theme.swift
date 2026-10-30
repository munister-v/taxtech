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
    /// Сигнальний жовтий - колір токена TAX: головні панелі, кнопки, вибране.
    static let accent = Color(UIColor(hex: 0xFFD400))
    /// Текст на жовтому - завжди чорний.
    static let onAccent = Color(UIColor(hex: 0x0E0E0C))
    /// Колір вибраного: жовтий.
    static let tint = dynamic(light: 0x0E0E0C, dark: 0xFFD400)
    /// Тепле золото лендингу: рамки, капітелі, гільйош.
    static let gold = Color(UIColor(hex: 0xC7A46F))
    static let goldLight = Color(UIColor(hex: 0xDCC195))
    /// Золотий градієнт для великих цифр і заголовків.
    static let goldFill = LinearGradient(colors: [Color(UIColor(hex: 0xFFF3D2)), Color(UIColor(hex: 0xDCC195)), Color(UIColor(hex: 0xCFA862))],
                                         startPoint: .top, endPoint: .bottom)
    /// Золота волоскова рамка поверхні: світліша зверху-ліворуч, тихіша в середині.
    static let edge = LinearGradient(stops: [
        .init(color: Color(UIColor(hex: 0xDCC195)).opacity(0.5), location: 0),
        .init(color: .white.opacity(0.07), location: 0.3),
        .init(color: .white.opacity(0.04), location: 0.7),
        .init(color: Color(UIColor(hex: 0xC7A46F)).opacity(0.32), location: 1),
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func balance(_ size: CGFloat = 46) -> Font {
        .custom("Futura-Medium", size: size)
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
    func screenBackground() -> some View {
        background { Theme.bg.ignoresSafeArea() }
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
        font(.custom("Futura-Medium", size: 12))
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(Theme.gold)
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
            .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
            .goldEdge(22)
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
            Text(text).font(.custom("Futura-Medium", size: 21))
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

/// Тонка роздільна лінія між рядками поверхні.
struct Rule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: Theme.hairline).padding(.horizontal, 16)
    }
}

/// Головна дія: плоска жовта капсула з чорним текстом. Жовтий - єдиний акцент, тож лише тут і на головних значках.
struct InkButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [Color(UIColor(hex: 0xFFE45A)), Theme.accent, Color(UIColor(hex: 0xE6B800))],
                                       startPoint: .top, endPoint: .bottom).opacity(configuration.isPressed ? 0.82 : 1), in: .capsule)
            .overlay(Capsule().strokeBorder(.white.opacity(0.45), lineWidth: 0.8))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(enabled ? 1 : 0.35)
    }
}

/// Другорядна дія: плоска капсула з тонким контуром.
struct LineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
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
                            .font(.system(size: 19, weight: .regular))
                            .frame(height: 24)
                        Text(item.title).font(.footnote.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
        .goldEdge(Theme.corner)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(.body.weight(positive ? .bold : .regular))
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
            CardSurface(look: resolved, corner: corner)
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
                        .font(.system(.title3, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !l.name.isEmpty {
                        Text(Brand.name.uppercased()).font(.caption2.weight(.semibold)).tracking(1.4).opacity(0.6)
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
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .shadow(color: .white.opacity(l.color.isLight ? 0.55 : 0.28), radius: 0, x: -0.6, y: -0.6)
                .shadow(color: .black.opacity(l.color.isLight ? 0.28 : 0.5), radius: 0.6, x: 0.7, y: 0.9)
            HStack(alignment: .lastTextBaseline) {
                Text(holder ?? "").lineLimit(1)
                Spacer()
                if let expiry { Text(expiry).monospacedDigit() }
                Text(L("ВІРТУАЛЬНА").s).font(.system(size: 9, weight: .bold)).tracking(1.4).opacity(0.7)
            }
            .font(.caption.weight(.medium))
            .opacity(0.85)
            .padding(.top, 4)
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
