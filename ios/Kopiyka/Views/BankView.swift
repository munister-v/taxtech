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

/// Головна навчального банку: баланс, картка, дії, операції по днях.
struct BankView: View {
    @Environment(AppModel.self) private var model
    @State private var bank = BankModel()
    @State private var sheet: Sheet?
    @State private var busyCard = false
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var unread = 0
    #if DEBUG
    @State private var debugOpen = false
    #endif

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
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
                hub
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
        .screenBackground()
        .navigationTitle("Банк")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink { NoticesView() } label: {
                Image(systemName: unread > 0 ? "bell.badge" : "bell")
                    .accessibilityLabel(unread > 0 ? "Сповіщення, нових: \(unread)" : "Сповіщення")
            }
            Menu("Ще", systemImage: "ellipsis") {
                Button("Вийти") { model.signOut() }
                Button("Видалити акаунт") { confirmDelete = true }
            }
        }
        .confirmationDialog("Видалити акаунт назавжди?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Видалити акаунт і всі дані", role: .destructive) {
                Task {
                    do { try await model.deleteAccount() } catch { deleteError = error.localizedDescription }
                }
            }
        } message: {
            Text("Рахунок, картки, депозити, кредити й історія віртуальних операцій зникнуть. Витрати в обліку на телефоні залишаться.")
        }
        .alert("Не вдалося видалити", isPresented: .init(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("Гаразд") {}
        } message: { Text(deleteError ?? "") }
        .refreshable {
            await bank.load(model.api)
            unread = (try? await model.api.unreadCount()) ?? 0
        }
        .task {
            await bank.load(model.api)
            unread = (try? await model.api.unreadCount()) ?? 0
        }
        #if DEBUG
        // simctl launch з SIMCTL_CHILD_KOPIYKA_OPEN=cards|deposits|credits|goals|contacts|limits|analytics|history
        .navigationDestination(isPresented: $debugOpen) { debugScreen }
        .onAppear { debugOpen = ProcessInfo.processInfo.environment["KOPIYKA_OPEN"] != nil }
        #endif
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

    #if DEBUG
    @ViewBuilder private var debugScreen: some View {
        switch ProcessInfo.processInfo.environment["KOPIYKA_OPEN"] {
        case "cards": CardsView()
        case "deposits": DepositsView()
        case "credits": CreditsView()
        case "goals": GoalsView()
        case "contacts": ContactsView()
        case "limits": LimitsView()
        case "analytics": AnalyticsView()
        case "donations": DonationsView()
        case "payouts": PayoutsView()
        case "debts": DebtsView()
        case "notices": NoticesView()
        case "statements": StatementsView()
        case "security": SecurityView()
        default: HistoryView()
        }
    }
    #endif

    private var balance: some View {
        VStack(spacing: 6) {
            Text("Віртуальний рахунок").caption()
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
        var items = [
            ActionBar.Item(title: "Переказати", symbol: "arrow.up.right") { sheet = .transfer },
            ActionBar.Item(title: "Поповнити", symbol: "plus") { sheet = .topUp },
        ]
        if let card = bank.primaryCard {
            items.append(.init(title: "Дизайн", symbol: "rectangle.on.rectangle") { sheet = .design })
            items.append(.init(title: card.isBlocked ? "Розморозити" : "Заморозити", symbol: "snowflake") {
                guard !busyCard else { return }
                busyCard = true
                Task {
                    try? await model.api.toggleCardBlock(card.id)
                    await bank.load(model.api)
                    busyCard = false
                }
            })
        }
        return ActionBar(items: items)
    }

    /// Усе, що вміє банк, - рядками з коротким підсумком праворуч.
    private var hub: some View {
        let dep = bank.deposits.reduce(0) { $0 + $1.amount }
        let debt = bank.credits.reduce(0) { $0 + $1.balanceRemaining }
        return VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Банк")
            Surface {
                HubRow("Картки", bank.cards.isEmpty ? "" : "\(bank.cards.count)") { CardsView() }
                Rule()
                HubRow("Депозити", dep > 0 ? Format.money(dep) : "") { DepositsView() }
                Rule()
                HubRow("Кредити", debt > 0 ? Format.money(debt) : "") { CreditsView() }
                Rule()
                HubRow("Цілі", bank.goals.isEmpty ? "" : "\(bank.goals.count)") { GoalsView() }
                Rule()
                HubRow("Контакти й шаблони", "") { ContactsView() }
                Rule()
                HubRow("Ліміти й платежі", "") { LimitsView() }
                Rule()
                HubRow("Донати", "") { DonationsView() }
                Rule()
                HubRow("Виплати", "") { PayoutsView() }
                Rule()
                HubRow("Борги", "") { DebtsView() }
                Rule()
                HubRow("Аналітика", "") { AnalyticsView() }
                Rule()
                HubRow("Виписки", "") { StatementsView() }
                Rule()
                HubRow("Профіль і безпека", "") { SecurityView() }
            }
        }
    }

    private var operations: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                BlockTitle("Операції")
                NavigationLink("Уся історія") { HistoryView() }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.ink)
            }
            if bank.loaded && bank.history.isEmpty {
                Text("Операцій ще немає").foregroundStyle(.secondary).padding(.horizontal, 4)
            }
            ForEach(bank.days.prefix(4), id: \.day) { day in
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.dayTitle(day.day))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    Surface {
                        ForEach(Array(day.items.enumerated()), id: \.element.id) { i, tx in
                            if i > 0 { Rule() }
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

/// Рядок переходу до розділу банку.
struct HubRow<Destination: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let destination: Destination

    init(_ title: String, _ detail: String, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.detail = detail
        self.destination = destination()
    }

    var body: some View {
        NavigationLink { destination } label: {
            HStack {
                Text(title)
                Spacer()
                Text(detail).foregroundStyle(.secondary).monospacedDigit()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct TransactionRow: View {
    let tx: API.Transaction

    var body: some View {
        AmountRow(title: title,
                  subtitle: "\(kind), \(tx.date.formatted(date: .omitted, time: .shortened))",
                  amount: (tx.isIncome ? "+" : "−") + Format.money(tx.amount))
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
