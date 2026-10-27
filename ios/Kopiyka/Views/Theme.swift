import SwiftUI

/// Назва й позиціонування. Одне місце, щоб не розходилось між екранами.
enum Brand {
    static let name = "TaxTech"
    static let lab = "Віртуальна лабораторія цифрових фінансів і технологій розподіленого реєстру"
}

/// Візуальна мова TaxTech: чорне тло й теплий папір, один сигнальний жовтий - колір токена TAX.
/// Без градієнтів: різницю дають площини кольору, вага шрифту й тонкі лінії.
enum Theme {
    static let corner: CGFloat = 16
    static let gutter: CGFloat = 16
    static let hairline: CGFloat = 0.5

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    static let bg = dynamic(light: 0xF4F1EA, dark: 0x0E0E0C)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1A1A17)
    static let line = dynamic(light: 0xDDD8CC, dark: 0x2F2E29)
    static let ink = dynamic(light: 0x0E0E0C, dark: 0xF4F1EA)
    /// Текст на заливці кольору тексту.
    static let onInk = dynamic(light: 0xF4F1EA, dark: 0x0E0E0C)
    /// Сигнальний жовтий - колір токена TAX: головні панелі, кнопки, вибране.
    static let accent = Color(UIColor(hex: 0xFFD400))
    /// Текст на жовтому - завжди чорний.
    static let onAccent = Color(UIColor(hex: 0x0E0E0C))
    /// Колір вибраного там, де жовтий на папері не читається (вкладки, перемикачі).
    static let tint = dynamic(light: 0x0E0E0C, dark: 0xFFD400)

    static func balance(_ size: CGFloat = 46) -> Font {
        .system(size: size, weight: .semibold)
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
        font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: Поверхні

/// Плоска поверхня з тонкою лінією.
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
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
            Text(text).caption()
            Spacer()
            if let trailing {
                Text(trailing).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Тонка роздільна лінія між рядками поверхні.
struct Rule: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: Theme.hairline).padding(.leading, 16)
    }
}

/// Головна дія: чорна плитка з контрастним текстом.
struct InkButton: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accent, in: .rect(cornerRadius: Theme.corner, style: .continuous))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.35)
    }
}

/// Другорядна дія: лише контур.
struct LineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.9), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.6 : 1)
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
        .sensoryFeedback(.selection, trigger: items.count)
    }
}

/// Рядок у поверхні: назва, підпис, сума праворуч.
struct AmountRow: View {
    let title: String
    let subtitle: String
    let amount: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).lineLimit(1)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(.body.weight(.semibold))
                .monospacedDigit()
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
        case .dark: "Чорний"
        case .slate: "Графіт"
        case .navy: "Сталь"
        case .forest: "Попіл"
        case .gold: "Сигнал"
        case .rose: "Контур"
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

/// Віртуальна картка: плоска заливка, знак лабораторії великим водяним знаком у куті.
struct VirtualCardView: View {
    let number: String
    let expiry: String?
    let holder: String?
    var design = CardDesign.dark
    var frozen = false
    var compact = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(design.fill)
            watermark
            if !compact { face }
            if let border = design.border {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(border, lineWidth: design == .rose ? 1.5 : 1)
            }
            if frozen {
                RoundedRectangle(cornerRadius: corner, style: .continuous).fill(.black.opacity(0.62))
                Label("Заморожена", systemImage: "snowflake")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(.rect(cornerRadius: corner, style: .continuous))
    }

    private var corner: CGFloat { compact ? 8 : 18 }

    private var watermark: some View {
        GeometryReader { g in
            Image("Mark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: g.size.height * 1.05)
                .foregroundStyle(design.text.opacity(0.1))
                .position(x: g.size.width * 0.86, y: g.size.height * 0.72)
        }
    }

    private var face: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Text(Brand.name)
                    .font(.system(.title3, weight: .semibold))
                Spacer()
                Text("ВІРТУАЛЬНА")
                    .font(.caption2.weight(.medium))
                    .tracking(1.6)
                    .opacity(0.7)
            }
            Spacer()
            Text(number)
                .font(.system(.title3, design: .monospaced, weight: .regular))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack {
                Text(holder ?? "")
                Spacer()
                if let expiry { Text(expiry).monospacedDigit() }
            }
            .font(.caption.weight(.medium))
            .opacity(0.75)
        }
        .padding(20)
        .foregroundStyle(design.text)
    }
}
