import SwiftUI

/// Реквізити картки: кожне поле копіюється окремо, весь набір - одним дотиком або пересилається текстом.
/// CVV у спільний текст не потрапляє: його копіюють лише окремо.
struct CardRequisitesView: View {
    let card: API.Card
    let revealed: API.Revealed
    let accountNumber: String?
    @Environment(\.dismiss) private var dismiss
    @State private var copiedKey: String?
    @State private var copiedAll = false

    private struct Field: Identifiable {
        let key: String
        let title: String
        let shown: String
        let raw: String
        var id: String { key }
    }

    private var holder: String { DisplayName.of(card.holderName).uppercased() }

    private var fields: [Field] {
        var f: [Field] = []
        let digits = revealed.cardNumber.filter(\.isNumber)
        let grouped = stride(from: 0, to: digits.count, by: 4).map { i -> String in
            let a = digits.index(digits.startIndex, offsetBy: i)
            return String(digits[a..<digits.index(a, offsetBy: min(4, digits.count - i))])
        }.joined(separator: " ")
        f.append(Field(key: "number", title: Tx("Номер картки", "Card number", "Номер карты"), shown: grouped.isEmpty ? revealed.cardNumber : grouped, raw: digits.isEmpty ? revealed.cardNumber : digits))
        if let e = revealed.expiryDisplay ?? card.expiryDisplay { f.append(Field(key: "exp", title: Tx("Строк дії", "Expiry", "Срок действия"), shown: e, raw: e)) }
        f.append(Field(key: "cvv", title: "CVV", shown: revealed.cvv, raw: revealed.cvv))
        if !holder.isEmpty { f.append(Field(key: "holder", title: Tx("Власник", "Cardholder", "Владелец"), shown: holder, raw: holder)) }
        if let a = accountNumber, !a.isEmpty { f.append(Field(key: "acc", title: Tx("Номер рахунку", "Account number", "Номер счёта"), shown: a, raw: a)) }
        return f
    }

    /// Текст для копії й пересилання: без CVV.
    private var shareText: String {
        fields.filter { $0.key != "cvv" }.map { "\($0.title): \($0.shown)" }.joined(separator: "\n") + "\n\(Brand.name)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    GuillocheBadge(symbol: "creditcard", size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Tx("Реквізити картки", "Card details", "Реквизиты карты")).font(Theme.mono(20, .bold))
                        Text("•• \(revealed.cardNumber.suffix(4))").font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(Theme.ui(15, .semibold)).frame(width: 38, height: 38).glassCircle()
                    }
                    .buttonStyle(PressScale())
                    .foregroundStyle(Theme.ink)
                }
                Surface {
                    ForEach(Array(fields.enumerated()), id: \.element.id) { i, f in
                        if i > 0 { Rule() }
                        Button { copy(f) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(f.title).font(Theme.ui(style: .caption1)).foregroundStyle(.secondary)
                                    Text(f.shown).font(Theme.mono(f.key == "number" ? 19 : 16, .bold)).lineLimit(1).minimumScaleFactor(0.6)
                                }
                                Spacer()
                                Image(systemName: copiedKey == f.key ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(Theme.ui(17, .semibold))
                                    .foregroundStyle(copiedKey == f.key ? Theme.accent : .secondary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .padding(16)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.ink)
                    }
                }
                .sensoryFeedback(.success, trigger: copiedKey)
                Button {
                    UIPasteboard.general.string = shareText
                    withAnimation(.snappy) { copiedAll = true }
                    Task { try? await Task.sleep(for: .seconds(1.6)); withAnimation(.snappy) { copiedAll = false } }
                } label: {
                    Label(copiedAll ? Tx("Скопійовано", "Copied", "Скопировано") : Tx("Скопіювати все", "Copy all", "Скопировать всё"),
                          systemImage: copiedAll ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(InkButton())
                ShareLink(item: shareText) {
                    Label(Tx("Переслати", "Send", "Переслать"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(LineButton())
                Text(Tx("CVV не входить до спільного тексту: його копіюють окремо.", "CVV is not part of the shared text: copy it on its own.", "CVV не входит в общий текст: его копируют отдельно."))
                    .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.gutter).padding(.top, 20).padding(.bottom, 40)
        }
        .screenBackground(.hatch)
    }

    private func copy(_ f: Field) {
        UIPasteboard.general.string = f.raw
        withAnimation(.snappy) { copiedKey = f.key }
        Task { try? await Task.sleep(for: .seconds(1.4)); withAnimation(.snappy) { if copiedKey == f.key { copiedKey = nil } } }
    }
}
