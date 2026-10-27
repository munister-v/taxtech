import SwiftUI

/// Візуальна мова: великі числа, одна акцентна барва, картки-поверхні без рамок.
/// Без кольорових крапок-статусів, без пігулок-значків і кольорових квадратиків під іконками -
/// стан і категорії передає текст.
enum Theme {
    static let corner: CGFloat = 24
    static let gutter: CGFloat = 16

    static func balance(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Віртуальна картка завжди темна - як пластик, незалежно від теми застосунку.
    static let cardTop = Color(red: 0.09, green: 0.27, blue: 0.22)
    static let cardBottom = Color(red: 0.02, green: 0.07, blue: 0.07)
}

/// Поверхня-картка на тлі екрана.
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Theme.corner))
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

/// Кругла скляна кнопка дії з підписом під нею - нейтральна, без кольорової підкладки.
struct ActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
                .foregroundStyle(income ? Color.accentColor : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

/// Віртуальна картка: темний «пластик» з м'яким відблиском акценту.
struct VirtualCardView: View {
    let number: String
    let expiry: String?
    let holder: String?
    var frozen = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [Theme.cardTop, Theme.cardBottom],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RadialGradient(colors: [Color.accentColor.opacity(0.45), .clear],
                                     center: .topTrailing, startRadius: 10, endRadius: 260))
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)

            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline) {
                    Text("копійка")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                    Spacer()
                    Text("ВІРТУАЛЬНА")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.6)
                        .opacity(0.7)
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
                .opacity(0.75)
            }
            .padding(22)
            .foregroundStyle(.white)

            if frozen {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                Label("Заморожена", systemImage: "snowflake")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
    }
}
