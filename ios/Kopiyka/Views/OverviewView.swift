import Charts
import SwiftUI

/// Огляд: привітання, загальний баланс, картки, швидкі дії, динаміка балансу, часті отримувачі, останні операції.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @State private var bank = BankModel()
    @State private var me: API.Me?
    @State private var summary: API.Analytics?
    @State private var points: [API.BalancePoint] = []
    @State private var recipients: [API.Recipient] = []
    @State private var unread = 0
    @State private var hidden = false
    @State private var cardIndex = 0
    @State private var sheet: Sheet?
    @State private var prefill = ""
    let open: (RootView.AppTab) -> Void

    enum Sheet: String, Identifiable {
        case topUp, byCard, byAccount, assistant
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    header
                    balance
                    cards
                    quick
                    if points.count > 1 { dynamics }
                    if !recipients.isEmpty { frequent }
                    recent
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $sheet) { s in
                switch s {
                case .topUp: TopUpView { await load() }
                case .byCard: TransferView(balance: bank.account?.balance ?? 0, startByCard: true) { await load() }
                case .byAccount: TransferView(balance: bank.account?.balance ?? 0, startRecipient: prefill) { await load() }
                case .assistant: AssistantView()
                }
            }
        }
    }

    private func load() async {
        await bank.load(model.api)
        async let m = model.api.me()
        async let s = model.api.analytics()
        async let p = model.api.balanceHistory(days: 14)
        async let r = model.api.topRecipients()
        async let u = model.api.unreadCount()
        me = try? await m
        summary = try? await s
        points = (try? await p) ?? []
        recipients = (try? await r) ?? []
        unread = (try? await u) ?? 0
    }

    // MARK: Шапка

    private var header: some View {
        HStack(spacing: 12) {
            Initials(name: me?.fullName ?? "", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.greeting).font(.footnote).foregroundStyle(.secondary)
                Text(me.map { $0.fullName.split(separator: " ").first.map(String.init) ?? $0.fullName } ?? " ")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            RoundIcon(symbol: "text.bubble") { sheet = .assistant }
                .accessibilityLabel("Помічник")
            NavigationLink { NoticesView() } label: {
                RoundGlyph(symbol: unread > 0 ? "bell.badge" : "bell")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(unread > 0 ? "Сповіщення, нових: \(unread)" : "Сповіщення")
        }
        .padding(.top, 12)
    }

    static var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Доброго ранку"
        case 12..<18: "Добрий день"
        case 18..<23: "Добрий вечір"
        default: "Доброї ночі"
        }
    }

    // MARK: Баланс

    private var balance: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Загальний баланс").caption()
                Button { hidden.toggle() } label: {
                    Image(systemName: hidden ? "eye.slash" : "eye").font(.footnote).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Показати баланс" : "Сховати баланс")
            }
            BigAmount(value: bank.account?.balance ?? 0, hidden: hidden)
                .redacted(reason: bank.loaded ? [] : .placeholder)
            HStack(spacing: 10) {
                if let n = bank.account?.accountNumber {
                    Button { UIPasteboard.general.string = n } label: {
                        Label(n, systemImage: "doc.on.doc").labelStyle(TrailingIcon())
                    }
                    .buttonStyle(.plain)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let s = summary {
                    let net = s.currentMonth.totalIn - s.currentMonth.totalOut
                    Text("\(net >= 0 ? "+" : "−")\(Format.money(abs(net))) цього місяця")
                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    // MARK: Картки

    private var cards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Мої картки").font(.title3.weight(.semibold))
                Text("\(bank.cards.count)").foregroundStyle(.secondary)
                Spacer()
                Button("Усі") { open(.cards) }.font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            }
            if bank.cards.isEmpty {
                VirtualCardView(number: "•••• •••• •••• ••••", expiry: nil, holder: nil, design: .rose)
                    .redacted(reason: bank.loaded ? [] : .placeholder)
            } else {
                TabView(selection: $cardIndex) {
                    ForEach(Array(bank.cards.enumerated()), id: \.element.id) { i, c in
                        VirtualCardView(number: c.maskedNumber, expiry: c.expiryDisplay, holder: c.holderName,
                                        design: CardDesign(server: c.design), frozen: c.isBlocked)
                            .padding(.horizontal, 2)
                            .tag(i)
                            .onTapGesture { open(.cards) }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: (UIScreen.main.bounds.width - 2 * Theme.gutter) / 1.586 + 4)
                if bank.cards.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(bank.cards.indices, id: \.self) { i in
                            Rectangle().fill(i == cardIndex ? Theme.ink : Theme.line).frame(width: 18, height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: Швидкі дії

    private var quick: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Швидкі дії").font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                QuickTile(title: "Поповнити", symbol: "arrow.up") { sheet = .topUp }
                QuickTile(title: "На картку", symbol: "arrow.right") { sheet = .byCard }
                QuickTile(title: "За рахунком", symbol: "number") { prefill = ""; sheet = .byAccount }
                QuickTile(title: "Магазин", symbol: "bag") { open(.shop) }
            }
        }
    }

    // MARK: Динаміка

    private var dynamics: some View {
        let first = points.first?.balance ?? 0, last = points.last?.balance ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Динаміка балансу", trailing: "\(last >= first ? "+" : "−")\(Format.money(abs(last - first)))")
            Surface {
                Chart(points) { p in
                    LineMark(x: .value("День", BankText.day(p.day) ?? .now, unit: .day), y: .value("Баланс", p.balance))
                        .foregroundStyle(Theme.ink)
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "uk_UA")))
                    }
                }
                .frame(height: 120)
                .padding(16)
            }
        }
    }

    // MARK: Часті отримувачі

    private var frequent: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Часті отримувачі")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recipients.prefix(8)) { r in
                        let name = BankText.recipient(r.relatedAccount)
                        Button { prefill = r.relatedAccount; sheet = .byAccount } label: {
                            VStack(spacing: 8) {
                                Initials(name: name == r.relatedAccount ? String(r.relatedAccount.suffix(2)) : name, size: 48)
                                Text(name).font(.caption).lineLimit(1)
                                Text("\(r.txCount) перек.").font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 84)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: Останні операції

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Останні операції").font(.title3.weight(.semibold))
                Spacer()
                Button("Усі") { open(.operations) }.font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
            }
            if bank.loaded && bank.history.isEmpty {
                Text("Операцій ще немає").foregroundStyle(.secondary)
            } else {
                Surface {
                    ForEach(Array(bank.history.prefix(5).enumerated()), id: \.element.id) { i, tx in
                        if i > 0 { Rule() }
                        TransactionRow(tx: tx)
                    }
                }
            }
        }
    }
}

// MARK: Дрібні елементи в стилі TaxTech

/// Велика сума: гривні великим, копійки дрібніше.
struct BigAmount: View {
    let value: Double
    var hidden = false
    var size: CGFloat = 46

    var body: some View {
        let s = Format.money(value).replacingOccurrences(of: " ₴", with: "")
        let parts = s.split(separator: ",", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("₴ ").font(.system(size: size * 0.6, weight: .regular)).foregroundStyle(.secondary)
            if hidden {
                Text("••••••").font(.system(size: size, weight: .semibold))
            } else {
                Text(parts.first ?? s).font(.system(size: size, weight: .semibold)).tracking(-1)
                if parts.count > 1 {
                    Text(",\(parts[1])").font(.system(size: size * 0.5, weight: .regular)).foregroundStyle(.secondary)
                }
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText())
    }
}

/// Кругла плашка з ініціалами - замість фото.
struct Initials: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        Text(letters.isEmpty ? "TT" : letters)
            .font(.system(size: size * 0.36, weight: .semibold))
            .frame(width: size, height: size)
            .background(Theme.surface, in: .circle)
            .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct RoundGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 40, height: 40)
            .background(Theme.surface, in: .circle)
            .foregroundStyle(Theme.ink)
    }
}

struct RoundIcon: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { RoundGlyph(symbol: symbol) }.buttonStyle(.plain)
    }
}

/// Плитка швидкої дії: значок угорі, підпис унизу.
struct QuickTile: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { TileLabel(title: title, symbol: symbol) }
        .buttonStyle(.plain)
    }
}

/// Підпис і значок праворуч від нього.
struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.title
            configuration.icon.font(.caption2)
        }
    }
}
