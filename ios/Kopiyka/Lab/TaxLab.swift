import SwiftUI

/// Дослід: з нарахованої зарплати до суми на руки й вартості для роботодавця, ті самі ставки, що в розділі Fisco.
struct TaxLab: View {
    @State private var gross = 30_000.0

    private let rates = TaxRates.default

    private var salary: TaxMath.Salary { TaxMath.salary(gross: gross, rates) }

    private struct Part: Identifiable {
        let id: String
        let title: String
        let value: Double
        let color: Color
    }

    private var parts: [Part] {
        let s = salary
        return [
            Part(id: "net", title: L("На руки").s, value: s.net, color: Theme.accent),
            Part(id: "pdfo", title: L("ПДФО \(Int(rates.pdfo * 100))%").s, value: s.pdfo, color: Color.white.opacity(0.6)),
            Part(id: "mil", title: L("Військовий збір \(Int(rates.military * 100))%").s, value: s.military, color: Color.white.opacity(0.3)),
            Part(id: "esv", title: L("ЄСВ роботодавця \(Int(rates.esv * 100))%").s, value: s.employerEsv, color: Color(UIColor(red: 0.45, green: 0.38, blue: 0.27, alpha: 1))),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            result
            controls
            breakdown
        }
        .animation(.snappy, value: gross)
    }

    private var result: some View {
        LabHero {
            HeroCaption(L("На руки").s)
            Text(Format.short(salary.net)).font(Theme.balance(40)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).padding(.top, 2)
            HStack(spacing: 22) {
                Stat(value: Format.short(salary.gross), label: L("Нараховано").s)
                Stat(value: Format.short(salary.employerCost), label: L("Коштує роботодавцю").s)
            }
            .padding(.top, 14)
        }
    }

    private var controls: some View {
        LabPanel(title: L("Зарплата").s) {
            LabSlider(title: L("Нараховано на місяць").s, value: Format.short(gross),
                      x: Binding(get: { gross }, set: { gross = ($0 / 500).rounded() * 500 }), range: 8_000...200_000)
            Text(L("База ЄСВ не більша за 20 мінімальних зарплат: \(Format.short(rates.minWage * 20)).").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var breakdown: some View {
        let total = max(salary.employerCost, 1)
        return LabPanel(title: L("Куди йдуть гроші").s) {
            GeometryReader { g in
                HStack(spacing: 2) {
                    ForEach(parts) { p in
                        Rectangle().fill(p.color).frame(width: max(2, (g.size.width - 6) * p.value / total))
                    }
                }
                .clipShape(.rect(cornerRadius: 4))
            }
            .frame(height: 12)
            ForEach(parts) { p in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3).fill(p.color).frame(width: 12, height: 12)
                    Text(p.title).font(.subheadline)
                    Spacer()
                    Text(Format.short(p.value)).font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
            Text(L("Ставки навчальні, для 2026 року. Для реальних розрахунків звіряйтеся з Податковим кодексом.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
