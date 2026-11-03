import EdgeRouter
import FraudLite
import SwiftUI

/// Дослід 2: Layer 1 антифроду, той самий `FraudLite.assess`, що працює в переказах.
/// Показує бал, прапорці й те, чи телефон упевнений, чи звернувся б до сервера.
struct FraudLab: View {
    @State private var amount: Double? = 4_900
    @State private var balance: Double? = 100_000
    @State private var note = ""

    private struct Scenario: Identifiable {
        let title: String
        let amount: Double
        let balance: Double
        let note: String
        var id: String { title }
    }

    private var scenarios: [Scenario] {
        [
            Scenario(title: L("Кава").s, amount: 85, balance: 100_000, note: L("Кава").s),
            Scenario(title: L("Трохи нижче порогу").s, amount: 4_900, balance: 100_000, note: ""),
            Scenario(title: L("Кругла сума").s, amount: 50_000, balance: 200_000, note: L("Оренда").s),
            Scenario(title: L("Увесь залишок").s, amount: 99_000, balance: 100_000, note: L("Оренда").s),
            Scenario(title: L("Підозрілі слова").s, amount: 3_200, balance: 100_000, note: L("терміново крипто").s),
            Scenario(title: L("Усе разом").s, amount: 4_900, balance: 5_000, note: "test"),
        ]
    }

    private var input: FraudTask.Input {
        FraudTask.Input(amount: amount ?? 0, balance: balance ?? 0, description: note, recipient: nil)
    }

    var body: some View {
        let r = FraudLite.assess(amount: input.amount, balance: input.balance, description: input.description)
        VStack(alignment: .leading, spacing: 16) {
            presets
            fields
            score(r)
            flags(r)
            confidence(r)
        }
    }

    private var presets: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(scenarios) { s in
                    Button(s.title) {
                        withAnimation(.snappy) { amount = s.amount; balance = s.balance; note = s.note }
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .overlay(Capsule().stroke(Theme.ink.opacity(0.18), lineWidth: 1))
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    private var fields: some View {
        LabPanel(title: L("Переказ").s) {
            field(L("Сума, TAX").s) { TextField("0", value: $amount, format: .number).keyboardType(.decimalPad) }
            Rule()
            field(L("Залишок, TAX").s) { TextField("0", value: $balance, format: .number).keyboardType(.decimalPad) }
            Rule()
            field(L("Призначення").s) { TextField(L("Необов'язково").s, text: $note).textInputAutocapitalization(.never) }
        }
    }

    private func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            content().multilineTextAlignment(.trailing).monospacedDigit().frame(maxWidth: 180)
        }
    }

    private func score(_ r: RiskResult) -> some View {
        LabHero(ok: r.level == .low) {
            HeroCaption(level(r.level))
            Text("\(r.score)").font(Theme.balance(56)).monospacedDigit().padding(.top, 2)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.ink.opacity(0.14))
                    Capsule().fill(r.level == .low ? Theme.accent : Theme.alert)
                        .frame(width: max(6, g.size.width * Double(r.score) / 100))
                }
            }
            .frame(height: 6)
            .padding(.top, 8)
        }
        .animation(.snappy, value: r.score)
    }

    private func level(_ l: RiskLevel) -> String {
        switch l {
        case .low: L("Низький ризик").s
        case .medium: L("Середній ризик").s
        case .high: L("Високий ризик").s
        case .critical: L("Критичний ризик").s
        }
    }

    private func flags(_ r: RiskResult) -> some View {
        LabPanel(title: L("Що спрацювало").s) {
            if r.flags.isEmpty {
                Text(L("Жодне правило").s).foregroundStyle(.secondary)
            }
            ForEach(r.flags, id: \.self) { f in
                Label(FraudFlags.titles[f] ?? f, systemImage: "flag.fill")
                    .font(.subheadline)
                    .labelStyle(FlagLabel())
            }
        }
    }

    /// Те, чого не бачить телефон: невпевненість проти порогу каскаду.
    private func confidence(_ r: RiskResult) -> some View {
        let u = FraudTask.uncertainty(score: r.score, input: input)
        let lambda = PolicyState().lambda("fraud")
        let escalate = u > lambda
        return LabPanel(title: L("Каскад").s) {
            HStack {
                Text(L("Невпевненість телефона").s).font(.subheadline)
                Spacer()
                Text("\(Int((u * 100).rounded()))%").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            HStack {
                Text(L("Поріг каскаду").s).font(.subheadline)
                Spacer()
                Text("\(Int((lambda * 100).rounded()))%").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            Text(escalate ? L("Телефон засумнівався: переказ пішов би на сервер, де є історія й граф.").s
                          : L("Телефон упевнений: відповідь лишається на ньому.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
        .animation(.snappy, value: escalate)
    }
}

private struct FlagLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.font(.footnote).foregroundStyle(Theme.accent)
            configuration.title
        }
    }
}
