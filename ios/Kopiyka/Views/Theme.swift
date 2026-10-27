import SwiftUI

/// Візуальна мова: живе «сяйво» за головними числами, градієнтні картки, великі суми.
/// Колір несе сенс - категорія, дизайн картки, надходження. Без кольорових крапок-статусів,
/// пігулок-значків і кольорових квадратиків під іконками.
enum Theme {
    static let corner: CGFloat = 24
    static let gutter: CGFloat = 16

    static func balance(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func hex(_ v: UInt32) -> Color {
        Color(red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    static let emerald = hex(0x10B981)
    static let teal = hex(0x14B8A6)
    static let sky = hex(0x38BDF8)
    static let violet = hex(0x8B5CF6)
    static let amber = hex(0xF59E0B)
    static let rose = hex(0xF43F5E)

    /// Фірмовий перелив для гліфів дій і стовпців графіка.
    static let brand = LinearGradient(colors: [emerald, teal, sky], startPoint: .topLeading, endPoint: .bottomTrailing)

    /// Колір категорії витрат - той самий у кільці й у смузі рядка, тож легенда не потрібна.
    static func category(_ name: String) -> [Color] {
        switch name {
        case "Продукти": [emerald, teal]
        case "Кафе": [amber, hex(0xF97316)]
        case "Пальне": [rose, hex(0xE11D48)]
        case "Аптека": [sky, hex(0x3B82F6)]
        case "Транспорт": [violet, hex(0x6366F1)]
        case "Комуналка": [hex(0xFACC15), amber]
        default: [hex(0x94A3B8), hex(0x64748B)]
        }
    }
}

// MARK: Сяйво

/// Повільне «північне сяйво» за верхом екрана: сітковий градієнт, що дихає, і плавний перехід у тло.
struct AuroraBackground: View {
    var height: CGFloat = 460
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 15 кадрів на секунду досить для повільного руху; анімація - не за рахунок батареї,
        // яку застосунок сам же міряє
        TimelineView(.animation(minimumInterval: 1 / 15, paused: Motion.paused(reduceMotion))) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            MeshGradient(width: 3, height: 3, points: points(t), colors: colors)
                .opacity(scheme == .dark ? 0.55 : 0.35)
        }
        .frame(height: height)
        .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var colors: [Color] {
        [Theme.emerald, Theme.teal, Theme.violet,
         Theme.sky, Theme.emerald, Theme.violet,
         Theme.teal, Theme.sky, Theme.emerald]
    }

    private func points(_ t: Double) -> [SIMD2<Float>] {
        let a = Float(sin(t * 0.35)) * 0.18
        let b = Float(cos(t * 0.27)) * 0.16
        return [
            [0, 0], [0.5 + a * 0.5, 0], [1, 0],
            [0, 0.5 + b], [0.5 + a, 0.5 - b], [1, 0.5 - a],
            [0, 1], [0.5 - b * 0.5, 1], [1, 1],
        ]
    }
}

/// Коли рух вимкнено: «Зменшення руху» або режим енергозбереження.
enum Motion {
    static func paused(_ reduceMotion: Bool) -> Bool {
        reduceMotion || ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

extension View {
    /// Тло екрана зі сяйвом угорі.
    func auroraScreen(height: CGFloat = 460) -> some View {
        background {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                AuroraBackground(height: height)
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: Поверхні

/// Поверхня-картка на тлі екрана.
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(Color(.secondarySystemGroupedBackground).opacity(0.92), in: .rect(cornerRadius: Theme.corner))
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
            Text(text).font(.title3.weight(.semibold))
            Spacer()
            if let trailing {
                Text(trailing).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Кругла скляна кнопка дії з підписом; гліф - фірмовим переливом.
struct ActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Theme.brand)
                    .frame(width: 58, height: 58)
                    .glassEffect(.regular.interactive(), in: .circle)
                Text(title)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: title)
    }
}

/// Рядок у поверхні: назва, підпис, сума праворуч.
struct AmountRow: View {
    let title: String
    let subtitle: String
    let amount: String
    var income = false

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
                .foregroundStyle(income ? AnyShapeStyle(Theme.brand) : AnyShapeStyle(.primary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

// MARK: Картка

/// Дизайни віртуальної картки - ті самі ідентифікатори, що приймає сервер (`PATCH /cards/{id}/design`).
enum CardDesign: String, CaseIterable, Identifiable {
    case forest, gold, navy, rose, slate, dark

    var id: String { rawValue }

    init(server: String?) { self = CardDesign(rawValue: server ?? "") ?? .forest }

    var title: String {
        switch self {
        case .forest: "Смарагд"
        case .gold: "Бурштин"
        case .navy: "Північ"
        case .rose: "Захід"
        case .slate: "Графіт"
        case .dark: "Обсидіан"
        }
    }

    /// 3×3 кольори сіткового градієнта.
    var mesh: [Color] {
        let h = Theme.hex
        return switch self {
        case .forest: [h(0x064E3B), h(0x047857), h(0x10B981),
                       h(0x022C22), h(0x0F766E), h(0x34D399),
                       h(0x011A14), h(0x064E3B), h(0x14B8A6)]
        case .gold: [h(0x3B2205), h(0x8A5A12), h(0xE8B85A),
                     h(0x5C3A0B), h(0xC88E2E), h(0xFBE3A1),
                     h(0x241503), h(0x7A4D0E), h(0xD9A441)]
        case .navy: [h(0x0B1437), h(0x1E3A8A), h(0x38BDF8),
                     h(0x0A0F2C), h(0x4338CA), h(0x818CF8),
                     h(0x050816), h(0x1E1B4B), h(0x6366F1)]
        case .rose: [h(0x4C0519), h(0xBE123C), h(0xFB923C),
                     h(0x3B0764), h(0xDB2777), h(0xFDBA74),
                     h(0x1E0A2E), h(0x9D174D), h(0xF97316)]
        case .slate: [h(0x1F2937), h(0x4B5563), h(0xD1D5DB),
                      h(0x111827), h(0x6B7280), h(0xF3F4F6),
                      h(0x0B0F17), h(0x374151), h(0x9CA3AF)]
        case .dark: [h(0x050505), h(0x111827), h(0x312E81),
                     h(0x0A0A0A), h(0x0F172A), h(0x134E4A),
                     h(0x000000), h(0x1E1B4B), h(0x064E3B)]
        }
    }
}

/// Віртуальна картка: живий сітковий градієнт, відблиск, що повільно пробігає, тонка рамка.
struct VirtualCardView: View {
    let number: String
    let expiry: String?
    let holder: String?
    var design = CardDesign.forest
    var frozen = false
    var compact = false
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20,
                                paused: !animated || compact || frozen || Motion.paused(reduceMotion))) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                MeshGradient(width: 3, height: 3, points: points(t), colors: design.mesh)
                sheen(t)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                if !compact { face }
                if frozen {
                    Rectangle().fill(.ultraThinMaterial)
                    Label("Заморожена", systemImage: "snowflake")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .clipShape(.rect(cornerRadius: corner, style: .continuous))
        }
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: design.mesh[4].opacity(compact ? 0.2 : 0.45), radius: compact ? 6 : 24, y: compact ? 4 : 14)
    }

    private var corner: CGFloat { compact ? 10 : 22 }

    private var face: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Text("копійка")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                Spacer()
                Text("ВІРТУАЛЬНА")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .opacity(0.75)
            }
            Spacer()
            Text(number)
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack {
                Text(holder ?? "")
                Spacer()
                if let expiry { Text(expiry).monospacedDigit() }
            }
            .font(.caption.weight(.medium))
            .opacity(0.8)
        }
        .padding(22)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    private func points(_ t: Double) -> [SIMD2<Float>] {
        let a = Float(sin(t * 0.5)) * 0.12
        let b = Float(cos(t * 0.4)) * 0.1
        return [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.5 + a, 0.5 + b], [1, 0.5],
            [0, 1], [0.5, 1], [1, 1],
        ]
    }

    /// Діагональний відблиск раз на кілька секунд - як світло на пластику.
    private func sheen(_ t: Double) -> some View {
        let phase = (t.truncatingRemainder(dividingBy: 6)) / 6
        return GeometryReader { g in
            LinearGradient(colors: [.clear, .white.opacity(0.22), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: g.size.width * 0.35)
                .rotationEffect(.degrees(20))
                .offset(x: -g.size.width * 0.5 + g.size.width * 2 * phase)
                .blendMode(.plusLighter)
        }
        .opacity(compact ? 0 : 1)
    }
}
