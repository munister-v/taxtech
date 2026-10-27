import Charts
import SwiftUI

/// Огляд: привітання, інвертована панель балансу, круглі дії, картки, податки, динаміка, отримувачі, операції.
struct OverviewView: View {
    @Environment(AppModel.self) private var model
    @State private var bank = BankModel()
    @State private var me: API.Me?
    @State private var summary: API.Analytics?
    @State private var points: [API.BalancePoint] = []
    @State private var recipients: [API.Recipient] = []
    @State private var unread = 0
    @State private var hidden = false
    @State private var sheet: Sheet?
    @State private var prefill = ""
    @State private var showProfile = false
    let open: (RootView.AppTab) -> Void

    enum Sheet: String, Identifiable {
        case topUp, byCard, byAccount, assistant
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    balance
                    actions
                    cards
                    taxes
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
            .sheet(isPresented: $showProfile) { ProfileView().presentationDragIndicator(.visible) }
        }
    }

    private func load() async {
        await bank.load(model.api)
        async let m = model.api.me()
        async let s = model.api.analytics()
        async let p = model.api.balanceHistory(days: 30)
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
            Button { showProfile = true } label: {
                HStack(spacing: 12) {
                    Initials(name: me?.fullName ?? "", size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.greeting).font(.footnote).foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(me.map { $0.fullName.split(separator: " ").first.map(String.init) ?? $0.fullName } ?? " ")
                                .font(Theme.display(17))
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Профіль")
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
        HeroPanel {
            HStack {
                HeroCaption("Загальний баланс")
                Spacer()
                Button { withAnimation(.snappy) { hidden.toggle() } } label: {
                    Image(systemName: hidden ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundStyle(Theme.onAccent.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Показати баланс" : "Сховати баланс")
            }
            BigAmount(value: bank.account?.balance ?? 0, hidden: hidden, size: 40)
                .foregroundStyle(Theme.onAccent)
                .padding(.top, 8)
                .redacted(reason: bank.loaded ? [] : .placeholder)
            if let n = bank.account?.accountNumber {
                Button { UIPasteboard.general.string = n } label: {
                    Label(n, systemImage: "doc.on.doc").labelStyle(TrailingIcon())
                }
                .buttonStyle(.plain)
                .font(.footnote.monospaced())
                .foregroundStyle(Theme.onAccent.opacity(0.6))
                .padding(.top, 4)
            }
            if let s = summary {
                Rectangle().fill(Theme.onAccent.opacity(0.2)).frame(height: 1).padding(.vertical, 16)
                HStack(alignment: .top, spacing: 16) {
                    Stat(value: "+" + Format.money(s.currentMonth.totalIn), label: "надійшло цього місяця", inverted: true)
                    Stat(value: "−" + Format.money(s.currentMonth.totalOut), label: "витрачено", inverted: true)
                }
            }
        }
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: 8) {
            CircleAction(title: "Поповнити", symbol: "plus") { sheet = .topUp }
            CircleAction(title: "На картку", symbol: "creditcard") { sheet = .byCard }
            CircleAction(title: "За рахунком", symbol: "arrow.left.arrow.right") { prefill = ""; sheet = .byAccount }
            CircleAction(title: "Податки", symbol: "percent") { open(.taxes) }
        }
    }

    // MARK: Картки

    private var cards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Мої картки").font(Theme.display(17))
                Text("\(bank.cards.count)").foregroundStyle(.secondary)
                Spacer()
                Button("Усі") { open(.cards) }.font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            if bank.cards.isEmpty {
                VirtualCardView(number: "•••• •••• •••• ••••", expiry: nil, holder: nil, design: .rose)
                    .redacted(reason: bank.loaded ? [] : .placeholder)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(bank.cards) { c in
                            VirtualCardView(number: c.maskedNumber, expiry: c.expiryDisplay, holder: c.holderName,
                                            design: CardDesign(server: c.design), frozen: c.isBlocked)
                                .containerRelativeFrame(.horizontal) { w, _ in bank.cards.count > 1 ? w * 0.86 : w }
                                .scrollTransition(axis: .horizontal) { v, phase in
                                    v.scaleEffect(phase.isIdentity ? 1 : 0.92).opacity(phase.isIdentity ? 1 : 0.6)
                                }
                                .onTapGesture { open(.cards) }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
    }

    // MARK: Податки

    private var taxes: some View {
        let next = TaxDeadline.upcoming(group: nil).first
        return Button { open(.taxes) } label: {
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "percent")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Theme.accent, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                            .foregroundStyle(Theme.onAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Податки").font(.headline)
                            Text("Зарплата, ФОП, знижка й строки").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    if let next {
                        Rule().padding(.leading, -16)
                        HStack(alignment: .firstTextBaseline) {
                            Text(next.title).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(next.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "uk_UA"))))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(PressScale())
    }

    // MARK: Динаміка

    private var dynamics: some View {
        let first = points.first?.balance ?? 0, last = points.last?.balance ?? 0
        let low = points.map(\.balance).min() ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Динаміка балансу").font(Theme.display(17))
                Spacer()
                Text("\(last >= first ? "+" : "−")\(Format.money(abs(last - first)))")
                    .font(.subheadline.weight(.semibold)).monospacedDigit()
            }
            Surface {
                Chart(points) { p in
                    let day = BankText.day(p.day) ?? .now
                    AreaMark(x: .value("День", day, unit: .day), yStart: .value("Мін", low), yEnd: .value("Баланс", p.balance))
                        .foregroundStyle(Theme.ink.opacity(0.08))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("День", day, unit: .day), y: .value("Баланс", p.balance))
                        .foregroundStyle(Theme.ink)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "uk_UA")))
                    }
                }
                .frame(height: 150)
                .padding(16)
            }
        }
    }

    // MARK: Часті отримувачі

    private var frequent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Часті отримувачі").font(Theme.display(17))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(recipients.prefix(8)) { r in
                        let name = BankText.recipient(r.relatedAccount)
                        Button { prefill = r.relatedAccount; sheet = .byAccount } label: {
                            VStack(spacing: 8) {
                                Initials(name: name == r.relatedAccount ? String(r.relatedAccount.suffix(2)) : name, size: 56)
                                Text(name).font(.caption.weight(.medium)).lineLimit(1)
                                Text("\(r.txCount) перек.").font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(PressScale())
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Останні операції

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Останні операції").font(Theme.display(17))
                Spacer()
                Button("Усі") { open(.operations) }.font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
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

/// Велика сума: цілі великим, дробова частина й позначка токена TAX дрібніше.
struct BigAmount: View {
    let value: Double
    var hidden = false
    var size: CGFloat = 46

    var body: some View {
        let s = Format.money(value).replacingOccurrences(of: " TAX", with: "")
        let parts = s.split(separator: ",", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if hidden {
                Text("••••••").font(.system(size: size, weight: .semibold))
            } else {
                Text(parts.first ?? s).font(Theme.display(size * 0.86)).tracking(-0.5)
                if parts.count > 1 {
                    Text(",\(parts[1])").font(Theme.display(size * 0.42, .regular)).foregroundStyle(.secondary)
                }
            }
            Text(" TAX").font(.system(size: size * 0.34, weight: .bold, design: .monospaced)).foregroundStyle(.secondary)
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
            .font(Theme.display(size * 0.32))
            .frame(width: size, height: size)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner).strokeBorder(Theme.line, lineWidth: 1))
    }
}

struct RoundGlyph: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 16, weight: .medium))
            .frame(width: 40, height: 40)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner))
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
