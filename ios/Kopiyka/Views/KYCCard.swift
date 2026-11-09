import SwiftUI

/// Цифрове посвідчення TaxTech: заповнюється, поки людина вводить дані, а після перевірки стає печаткою.
struct IDCredential: View {
    let state: KYCState
    var docNumber = ""
    var verified = false

    private var docTitle: String {
        switch state.docType {
        case "id": Tx("ID-картка", "ID card", "ID-карта")
        case "licence": Tx("Права", "Licence", "Права")
        default: Tx("Паспорт", "Passport", "Паспорт")
        }
    }

    private var masked: String {
        let n = verified ? state.docLast4 : String(docNumber.filter { !$0.isWhitespace }.suffix(4))
        return n.isEmpty ? "•••• ••••" : "•••• " + n.uppercased()
    }

    private var born: String {
        state.birth.formatted(.dateTime.day().month(.abbreviated).year().locale(Lang.current.locale))
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.12, blue: 0.10), Color(red: 0.05, green: 0.05, blue: 0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { ctx, size in
                var c = ctx
                Engraving.rosette(in: &c, center: CGPoint(x: size.width * 0.82, y: size.height * 0.34), radius: size.height * 0.62,
                                  curves: 12, lobes: 9, color: Theme.gold.opacity(verified ? 0.45 : 0.22))
                Engraving.rings(in: &c, center: CGPoint(x: size.width * 0.82, y: size.height * 0.34), from: size.height * 0.08, to: size.height * 0.3,
                                count: 8, color: Theme.gold.opacity(0.22))
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("TaxTech ID").font(Theme.mono(13, .bold)).foregroundStyle(Theme.accent)
                    Spacer()
                    Image(systemName: verified ? "checkmark.seal.fill" : "seal")
                        .font(Theme.ui(22, .semibold))
                        .foregroundStyle(verified ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.ink.opacity(0.35)))
                        .contentTransition(.symbolEffect(.replace))
                }
                Spacer(minLength: 8)
                Text(state.fullName.isEmpty ? Tx("Імʼя Прізвище", "Full Name", "Имя Фамилия") : state.fullName)
                    .font(Theme.mono(20, .bold)).lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(state.fullName.isEmpty ? Theme.ink.opacity(0.3) : Theme.ink)
                    .contentTransition(.interpolate)
                HStack(spacing: 16) {
                    field(Tx("Народж.", "Born", "Рожд."), born)
                    field(Tx("Країна", "Country", "Страна"), state.country == "OTHER" ? "—" : state.country)
                    field(docTitle, masked)
                }
                .padding(.top, 10)
            }
            .padding(18)
        }
        .aspectRatio(1.85, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.gold.opacity(verified ? 0.7 : 0.3), lineWidth: 1))
        .shadow(color: Theme.gold.opacity(verified ? 0.25 : 0), radius: 20, y: 8)
        .animation(.smooth, value: verified)
        .accessibilityElement(children: .combine)
    }

    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Theme.ui(style: .caption2)).foregroundStyle(Theme.ink.opacity(0.5))
            Text(value).font(Theme.mono(12, .bold)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

/// Рівень ризику AML трьома сегментами й ліміт до/після перевірки.
struct AMLGauge: View {
    let risk: String

    private var index: Int { risk == "high" ? 2 : risk == "medium" ? 1 : 0 }
    private var tint: Color { index == 2 ? Theme.alert : Theme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(Tx("Ризик AML", "AML risk", "Риск AML")).font(Theme.ui(style: .subheadline, .semibold))
                Spacer()
                Text(AML.title(risk)).font(Theme.mono(style: .subheadline, .bold)).foregroundStyle(tint)
            }
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i <= index ? tint : Theme.line).frame(height: 8)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(Format.money(KYCLimits.basic)).font(Theme.mono(14, .regular)).foregroundStyle(.secondary).strikethrough()
                Image(systemName: "arrow.right").font(Theme.ui(style: .caption1, .bold)).foregroundStyle(.secondary)
                Text(Format.money(KYCLimits.transfer)).font(Theme.mono(20, .bold)).foregroundStyle(Theme.accent)
                Spacer()
                Text(Tx("ліміт на переказ", "transfer limit", "лимит на перевод")).font(Theme.ui(style: .caption1)).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
    }
}
