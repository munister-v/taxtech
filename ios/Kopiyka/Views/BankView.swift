import SwiftUI

@MainActor @Observable
final class BankModel {
    var account: API.Account?
    var cards: [API.Card] = []
    var history: [API.Transaction] = []
    var error: String?
    var loaded = false

    func load(_ api: API) async {
        do {
            async let a = api.account()
            async let c = api.cards()
            async let h = api.history()
            (account, cards, history) = try await (a, c, h)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        loaded = true
    }

    var primaryCard: API.Card? { cards.first }

    /// Історія по днях, найновіші першими.
    var days: [(day: Date, items: [API.Transaction])] {
        Dictionary(grouping: history) { Calendar.current.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
}

/// Головна навчального банку в стилі необанку: баланс, картка, дії, операції по днях.
struct BankView: View {
    @Environment(AppModel.self) private var model
    @State private var bank = BankModel()
    @State private var sheet: Sheet?
    @State private var busyCard = false

    enum Sheet: String, Identifiable {
        case topUp, transfer, design
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                balance
                if let card = bank.primaryCard {
                    VirtualCardView(number: card.maskedNumber, expiry: card.expiryDisplay,
                                    holder: card.holderName, design: CardDesign(server: card.design),
                                    frozen: card.isBlocked)
                        .padding(.horizontal, 24)
                        .animation(.smooth, value: card.isBlocked)
                }
                actions
                if let error = bank.error {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                operations
                Text("Гроші навчальні: їх не можна вивести чи витратити поза застосунком.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
        }
        .auroraScreen()
        .navigationTitle("Банк")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Menu("Ще", systemImage: "ellipsis") {
                Button("Вийти", role: .destructive) { model.signOut() }
            }
        }
        .refreshable { await bank.load(model.api) }
        .task { await bank.load(model.api) }
        .sheet(item: $sheet) { s in
            switch s {
            case .topUp: TopUpView { await bank.load(model.api) }
            case .transfer: TransferView(balance: bank.account?.balance ?? 0) { await bank.load(model.api) }
            case .design:
                if let card = bank.primaryCard {
                    CardDesignPicker(card: card) { await bank.load(model.api) }
                }
            }
        }
    }

    private var balance: some View {
        VStack(spacing: 6) {
            Text("Віртуальний рахунок")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(bank.account.map { Format.money($0.balance) } ?? " ")
                .font(Theme.balance())
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .redacted(reason: bank.loaded ? [] : .placeholder)
            if let n = bank.account?.accountNumber {
                Text(n)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private var actions: some View {
        HStack(alignment: .top) {
            ActionButton(title: "Переказати", symbol: "arrow.up.right") { sheet = .transfer }
            ActionButton(title: "Поповнити", symbol: "plus") { sheet = .topUp }
            if bank.primaryCard != nil {
                ActionButton(title: "Дизайн", symbol: "paintpalette") { sheet = .design }
            }
            if let card = bank.primaryCard {
                ActionButton(title: card.isBlocked ? "Розморозити" : "Заморозити", symbol: "snowflake") {
                    guard !busyCard else { return }
                    busyCard = true
                    Task {
                        try? await model.api.toggleCardBlock(card.id)
                        await bank.load(model.api)
                        busyCard = false
                    }
                }
            }
        }
    }

    private var operations: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Операції")
            if bank.loaded && bank.history.isEmpty {
                Text("Операцій ще немає").foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            ForEach(bank.days.prefix(30), id: \.day) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.dayTitle(day.day))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    Surface {
                        ForEach(Array(day.items.enumerated()), id: \.element.id) { i, tx in
                            if i > 0 { Divider().padding(.leading, 16) }
                            TransactionRow(tx: tx)
                        }
                    }
                }
            }
        }
    }

    static func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Сьогодні" }
        if cal.isDateInYesterday(day) { return "Учора" }
        return day.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "uk_UA")))
    }
}

struct TransactionRow: View {
    let tx: API.Transaction

    var body: some View {
        AmountRow(title: title,
                  subtitle: "\(kind), \(tx.date.formatted(date: .omitted, time: .shortened))",
                  amount: (tx.isIncome ? "+" : "−") + Format.money(tx.amount),
                  income: tx.isIncome)
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

/// Вибір дизайну картки: живі мініатюри, вибрана - з рамкою акценту.
struct CardDesignPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: API.Card
    let changed: () async -> Void
    @State private var selected: CardDesign = .forest
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
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(Color.accentColor, lineWidth: selected == d ? 3 : 0)
                                                .padding(-4)
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
