import SwiftUI

@MainActor @Observable
final class BankModel {
    var account: API.Account?
    var cards: [API.Card] = []
    var history: [API.Transaction] = []
    var deposits: [API.Deposit] = []
    var credits: [API.Credit] = []
    var goals: [API.Goal] = []
    var error: String?
    var loaded = false

    func load(_ api: API) async {
        do {
            async let a = api.account()
            async let c = api.cards()
            async let h = api.history()
            (account, cards, history) = try await (a, c, h)
            cards = cards.filter { !$0.isClosed }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        deposits = ((try? await api.deposits()) ?? []).filter(\.isActive)
        credits = ((try? await api.credits()) ?? []).filter(\.isActive)
        goals = (try? await api.goals()) ?? []
        loaded = true
    }

    var primaryCard: API.Card? { cards.first { $0.isPrimary } ?? cards.first }

    /// Історія по днях, найновіші першими.
    var days: [(day: Date, items: [API.Transaction])] {
        Dictionary(grouping: history) { Calendar.current.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
}

struct TransactionRow: View {
    let tx: API.Transaction

    var body: some View {
        AmountRow(title: title,
                  subtitle: "\(kind), \(tx.date.formatted(date: .omitted, time: .shortened))",
                  amount: (tx.isIncome ? "+" : "−") + Format.money(tx.amount), positive: tx.isIncome)
    }

    /// «(віртуальна покупка)» сервер дописує до кожної покупки - тут це зайве, екран і так про віртуальні гроші.
    var title: String {
        let d = tx.description ?? tx.relatedAccount ?? "Операція"
        return d.replacingOccurrences(of: " (віртуальна покупка)", with: "")
    }

    var kind: String {
        switch tx.txType {
        case "payment": "Покупка"
        case "topup": "Поповнення"
        case "transfer":
            tx.isIncome ? "Переказ від \(tx.relatedAccount ?? "")" : "Переказ на \(tx.relatedAccount ?? "")"
        default: tx.isIncome ? "Надходження" : "Списання"
        }
    }
}

/// Вибір дизайну картки: плоскі мініатюри, вибрана - з чорною рамкою.
struct CardDesignPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: API.Card
    let changed: () async -> Void
    @State private var selected: CardDesign = .dark
    @State private var saving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VirtualCardView(number: card.maskedNumber, expiry: card.expiryDisplay,
                                    holder: card.holderName, design: selected)
                        .padding(.horizontal, 24)
                        .animation(.smooth, value: selected)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 14)], spacing: 18) {
                        ForEach(CardDesign.allCases) { d in
                            Button {
                                selected = d
                            } label: {
                                VStack(spacing: 8) {
                                    VirtualCardView(number: "", expiry: nil, holder: nil, design: d, compact: true)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .strokeBorder(Theme.ink, lineWidth: selected == d ? 2 : 0)
                                                .padding(-5)
                                        }
                                    Text(d.title)
                                        .font(.footnote.weight(selected == d ? .semibold : .regular))
                                        .foregroundStyle(selected == d ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Дизайн картки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        saving = true
                        Task {
                            try? await model.api.setCardDesign(card.id, selected.rawValue)
                            await changed()
                            dismiss()
                        }
                    }
                    .disabled(saving)
                }
            }
            .onAppear { selected = CardDesign(server: card.design) }
            .sensoryFeedback(.selection, trigger: selected)
        }
    }
}
