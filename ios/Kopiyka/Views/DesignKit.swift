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
                Text(title).font(Theme.display(26)).tracking(-0.5)
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

/// Інвертована панель: на світлому - чорна, на темному - біла. Для головної цифри екрана.
struct HeroPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: .rect(cornerRadius: Theme.cornerLarge, style: .continuous))
    }
}

/// Підпис-мітка всередині інвертованої панелі.
struct HeroCaption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Theme.onAccent.opacity(0.6))
    }
}

/// Пара «цифра - підпис» для рядів показників.
struct Stat: View {
    let value: String
    let label: String
    var inverted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(Theme.display(15, .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(inverted ? Theme.onAccent.opacity(0.6) : .secondary)
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
            HStack(spacing: 4) {
                ForEach(items, id: \.0) { value, title in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { selection = value }
                    } label: {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .foregroundStyle(selection == value ? Theme.onAccent : .secondary)
                            .background {
                                if selection == value {
                                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                        .fill(Theme.accent)
                                        .matchedGeometryEffect(id: "seg", in: ns)
                                }
                            }
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Кругла дія: значок у колі кольору тексту і підпис під ним.
struct CircleAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 58, height: 58)
                    .background(Theme.accent, in: .rect(cornerRadius: Theme.corner))
                    .foregroundStyle(Theme.onAccent)
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
    let parts: [(label: String, value: Double)]
    var inverted = false

    var body: some View {
        let total = max(parts.reduce(0) { $0 + $1.value }, 0.0001)
        let ink = inverted ? Theme.onAccent : Theme.ink
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
            .clipShape(.rect(cornerRadius: Theme.corner))
            HStack(spacing: 14) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                    HStack(spacing: 5) {
                        Rectangle().fill(ink.opacity(1 - Double(i) * 0.28)).frame(width: 10, height: 10)
                        Text("\(p.label) \(Int((p.value / total * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(inverted ? Theme.onAccent.opacity(0.7) : .secondary)
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
                    .font(Theme.display(24))
                    .monospacedDigit()
                Text("TAX").font(.title3.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
        }
    }
}
