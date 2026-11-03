import SwiftUI

/// Дослід: подвійний запис, як `ledger_service.py`. Кожен переказ - дві проводки, звірка порівнює суми.
/// Можна записати лише списання й побачити, як звірка ловить розбіжність.
struct LedgerLab: View {
    private enum Side { case debit, credit }
    private struct Entry: Identifiable {
        let id: Int
        let account: Int
        let side: Side
        let amount: Double
    }

    private let names = ["A", "B"]
    private static let opening: [Double] = [1_000, 250]

    @State private var entries: [Entry] = []
    @State private var amount = 100.0
    @State private var from = 0

    private func balance(_ a: Int) -> Double {
        entries.filter { $0.account == a }.reduce(Self.opening[a]) { $0 + ($1.side == .credit ? $1.amount : -$1.amount) }
    }

    private var debits: Double { entries.filter { $0.side == .debit }.reduce(0) { $0 + $1.amount } }
    private var credits: Double { entries.filter { $0.side == .credit }.reduce(0) { $0 + $1.amount } }
    private var total: Double { balance(0) + balance(1) }
    private var balanced: Bool { debits == credits }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            status
            accounts
            controls
            journal
        }
        .animation(.snappy, value: entries.count)
    }

    private var status: some View {
        LabHero(ok: balanced) {
            HeroCaption(L("Звірка").s)
            Text(balanced ? L("Суми збігаються").s : L("Розбіжність \(Format.short(abs(debits - credits)))").s)
                .font(.display(30, .medium)).tracking(-0.6).padding(.top, 4)
            HStack(spacing: 22) {
                Stat(value: Format.short(debits), label: L("Σ списань").s)
                Stat(value: Format.short(credits), label: L("Σ зарахувань").s)
            }
            .padding(.top, 14)
        }
    }

    private var accounts: some View {
        LabPanel(title: L("Рахунки").s) {
            ForEach(0..<2, id: \.self) { a in
                HStack {
                    Text(L("Рахунок \(names[a])").s).font(.subheadline)
                    Spacer()
                    Text(Format.short(balance(a))).font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
            Rule()
            HStack {
                Text(L("Усього на рахунках").s).font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text(Format.short(total)).font(.subheadline.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(total == Self.opening.reduce(0, +) ? Color.primary : Theme.alert)
            }
        }
    }

    private var controls: some View {
        LabPanel(title: L("Переказ").s) {
            Picker(L("Напрям").s, selection: $from) {
                Text("A → B").tag(0)
                Text("B → A").tag(1)
            }
            .pickerStyle(.segmented)
            LabSlider(title: L("Сума").s, value: Format.short(amount), x: Binding(get: { amount }, set: { amount = ($0 / 10).rounded() * 10 }),
                      range: 10...500)
            Button(L("Записати переказ").s) { post(both: true) }.buttonStyle(InkButton())
            HStack(spacing: 10) {
                Button(L("Лише списання").s) { post(both: false) }.buttonStyle(LineButton())
                Button(L("Скинути").s) { entries = [] }.buttonStyle(LineButton()).disabled(entries.isEmpty)
            }
        }
    }

    private var journal: some View {
        LabPanel(title: L("Проводки").s) {
            if entries.isEmpty { Text(L("Ще немає").s).foregroundStyle(.secondary) }
            ForEach(entries.reversed()) { e in
                HStack {
                    Text(e.side == .debit ? "DEBIT" : "CREDIT").font(.system(.caption, design: .monospaced))
                        .foregroundStyle(e.side == .debit ? Color.secondary : Theme.accent)
                        .frame(width: 60, alignment: .leading)
                    Text(L("Рахунок \(names[e.account])").s).font(.subheadline)
                    Spacer()
                    Text((e.side == .debit ? "−" : "+") + Format.short(e.amount)).font(.subheadline.weight(.semibold)).monospacedDigit()
                }
            }
        }
    }

    /// Чесний переказ пише обидві проводки; «лише списання» - це збій посередині операції.
    private func post(both: Bool) {
        let to = 1 - from
        guard balance(from) >= amount else { return }
        var id = entries.count
        entries.append(Entry(id: id, account: from, side: .debit, amount: amount))
        id += 1
        if both { entries.append(Entry(id: id, account: to, side: .credit, amount: amount)) }
    }
}
