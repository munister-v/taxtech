import SwiftUI

/// Дослід: авторизаційний холд, як `hold_service.py`. Сума заморожується, доступний залишок падає,
/// а холд закінчується списанням, зняттям або сам, коли спливе строк.
struct HoldLab: View {
    private enum Reason: String, CaseIterable, Identifiable {
        case card, authorization, large, fraud
        var id: String { rawValue }
        var title: String {
            switch self {
            case .card: L("Платіж карткою").s
            case .authorization: L("Авторизація").s
            case .large: L("Великий переказ").s
            case .fraud: L("Перевірка антифроду").s
            }
        }
        /// Строки з `HOLD_TTL` сервера, у годинах.
        var hours: Int {
            switch self {
            case .card: 12
            case .authorization: 24
            case .large: 48
            case .fraud: 72
            }
        }
    }

    private struct Hold: Identifiable {
        let id: Int
        let amount: Double
        let reason: Reason
        let expires: Int
    }

    @State private var balance = 1_000.0
    @State private var holds: [Hold] = []
    @State private var clock = 0
    @State private var amount = 300.0
    @State private var reason = Reason.card
    @State private var nextId = 1
    @State private var message: String?

    private var held: Double { holds.reduce(0) { $0 + $1.amount } }
    private var available: Double { balance - held }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summary
            place
            list
        }
        .animation(.snappy, value: holds.count)
    }

    private var summary: some View {
        LabHero {
            HeroCaption(L("Доступно").s)
            Text(Format.short(available)).font(Theme.balance(44)).monospacedDigit().padding(.top, 2)
            HStack(spacing: 22) {
                Stat(value: Format.short(balance), label: L("Баланс").s)
                Stat(value: Format.short(held), label: L("Заморожено").s)
                Stat(value: L("\(clock) год").s, label: L("Годинник").s)
            }
            .padding(.top, 14)
        }
    }

    private var place: some View {
        LabPanel(title: L("Новий холд").s) {
            Picker(L("Причина").s, selection: $reason) {
                ForEach(Reason.allCases) { Text($0.title).tag($0) }
            }
            .tint(Theme.accent)
            LabSlider(title: L("Сума").s, value: Format.short(amount),
                      x: Binding(get: { amount }, set: { amount = ($0 / 50).rounded() * 50 }), range: 50...800)
            Text(L("Спливе за \(reason.hours) год").s).font(.footnote).foregroundStyle(.secondary)
            if let message { Text(message).font(.footnote).foregroundStyle(Theme.alert) }
            Button(L("Заморозити").s) { placeHold() }.buttonStyle(InkButton())
            HStack(spacing: 10) {
                Button(L("Минуло +12 год").s) { advance() }.buttonStyle(LineButton())
                Button(L("Скинути").s) { reset() }.buttonStyle(LineButton())
            }
        }
    }

    private var list: some View {
        LabPanel(title: L("Активні холди").s) {
            if holds.isEmpty { Text(L("Немає").s).foregroundStyle(.secondary) }
            ForEach(holds) { h in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.short(h.amount)).font(.headline).monospacedDigit()
                            Text(L("\(h.reason.title), ще \(h.expires - clock) год").s).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Button(L("Списати").s) { capture(h) }.buttonStyle(LineButton())
                        Button(L("Зняти").s) { holds.removeAll { $0.id == h.id } }.buttonStyle(LineButton())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func placeHold() {
        guard available >= amount else {
            message = L("Недостатньо доступних коштів").s
            return
        }
        message = nil
        holds.append(Hold(id: nextId, amount: amount, reason: reason, expires: clock + reason.hours))
        nextId += 1
    }

    /// CAPTURE: холд зникає, сума проводиться як транзакція.
    private func capture(_ h: Hold) {
        balance -= h.amount
        holds.removeAll { $0.id == h.id }
    }

    /// EXPIRE: холд, строк якого вийшов, знімається сам, без списання.
    private func advance() {
        clock += 12
        holds.removeAll { $0.expires <= clock }
    }

    private func reset() {
        balance = 1_000
        holds = []
        clock = 0
        message = nil
    }
}
