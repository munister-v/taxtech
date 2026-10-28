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
    @State private var hits: [API.Product] = []
    @State private var shown: Double = 0
    @State private var drawn: CGFloat = 0
    @State private var ringIn = false
    let open: (RootView.AppTab) -> Void

    enum Sheet: String, Identifiable {
        case topUp, byCard, byAccount
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(spacing: 12) {
                        activity.rise(2)
                        if !recipients.isEmpty { quickTransfer.rise(3) }
                        wallet.rise(3)
                        spending.rise(4)
                        if points.count > 1 { balanceTrend.rise(4) }
                        HStack(spacing: 12) {
                            taxesCard
                            if let hit = hits.first { shopCard(hit) }
                        }
                        .frame(height: 176)
                        .rise(5)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .background {
                ZStack(alignment: .top) {
                    Theme.bg
                    HeroGradient().frame(height: 560)
                }
                .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await load() }
            .refreshable { await load() }
            .sheet(item: $sheet) { s in
                switch s {
                case .topUp: TopUpView { await load() }
                case .byCard: TransferView(balance: bank.account?.balance ?? 0, startByCard: true) { await load() }
                case .byAccount: TransferView(balance: bank.account?.balance ?? 0, startRecipient: prefill) { await load() }
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
        // дні до першого поповнення - майже нулі, вони тільки стискають графік
        let raw = (try? await p) ?? []
        let peak = raw.map(\.balance).max() ?? 0
        points = Array(raw.drop { $0.balance < peak * 0.05 })
        recipients = (try? await r) ?? []
        unread = (try? await u) ?? 0
        if hits.isEmpty {
            hits = ((try? await model.api.catalog(search: "", page: 1, sort: "stock", perPage: 40))?.items ?? [])
                .filter { ["HOT", "TOP", "NEW"].contains($0.badge ?? "") }
        }
    }

    // MARK: Шапка з балансом

    /// Темна сцена: аватар і сповіщення, баланс по центру, рахунок і скляні дії.
    private var hero: some View {
        VStack(spacing: 0) {
            HStack {
                Button { showProfile = true } label: {
                    // поки профіль не прийшов - значок, а не чужі «TT», що потім стрибають на справжні
                    Group {
                        if let initials { Text(initials).font(.system(size: 14, weight: .semibold)) }
                        else { Image(systemName: "person.fill").font(.system(size: 15)) }
                    }
                    .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Профіль")
                Spacer()
                BrandLockup(height: 26, color: .white)
                Spacer()
                NavigationLink { NoticesView() } label: {
                    Image(systemName: unread > 0 ? "bell.badge" : "bell").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .symbolEffect(.wiggle, value: unread)
                        .frame(width: 40, height: 40)
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unread > 0 ? "Сповіщення, нових: \(unread)" : "Сповіщення")
            }
            .padding(.top, 8)
            .rise(0)

            VStack(spacing: 6) {
                Text("Основний рахунок · TAX").font(.footnote.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                Button { withAnimation(.snappy) { hidden.toggle() } } label: {
                    HeroAmount(value: shown, hidden: hidden)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? "Показати баланс" : "Сховати баланс")
                .redacted(reason: bank.loaded ? [] : .placeholder)
                .onChange(of: bank.account?.balance) { _, v in
                    guard let v else { return }
                    withAnimation(.smooth(duration: 1.1)) { shown = v }
                }
                .sensoryFeedback(.success, trigger: shown > 0)
                if let m = summary?.currentMonth, !hidden {
                    HStack(spacing: 8) {
                        monthPill("arrow.down.left", "+" + Self.compact(m.totalIn), tint: .green)
                        monthPill("arrow.up.right", "−" + Self.compact(m.totalOut), tint: .orange)
                    }
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, 56)
            .frame(maxWidth: .infinity)
            .background {
                // захисний друк за сумою: гільйош і мікродрук, як на банкноті
                ZStack {
                    Guilloche().frame(width: 410, height: 410)
                    MicroprintRing(diameter: 236, color: .white.opacity(0.3))
                }
            }
            .padding(.top, 10)
            .rise(1)

            HStack(alignment: .top, spacing: 0) {
                heroAction("Поповнити", "plus") { sheet = .topUp }
                heroAction("Переказ", "arrow.right") { prefill = ""; sheet = .byAccount }
                heroAction("На картку", "creditcard") { sheet = .byCard }
                heroAction("Податки", "percent") { open(.taxes) }
            }
            .padding(.top, 14)
            .padding(.bottom, 28)
            .rise(2)
        }
        .padding(.horizontal, Theme.gutter)
    }

    private var initials: String? {
        let l = (me?.fullName ?? "").split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return l.isEmpty ? nil : l
    }

    private func heroAction(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                GuillocheBadge(symbol: symbol, tint: Color(red: 0.85, green: 0.72, blue: 0.40), size: 56, onDark: true)
                    .glassEffect(.regular.interactive(), in: .circle)
                Text(title).font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func monthPill(_ symbol: String, _ text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2.weight(.bold)).foregroundStyle(tint)
            Text(text).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: Картки під шапкою

    /// Швидкий переказ тим, кому вже надсилали: кружки з кольором за номером рахунку.
    private var quickTransfer: some View {
        Card {
            HStack {
                Text("Швидкий переказ").font(.headline)
                Spacer()
                Text("за історією").font(.footnote).foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button { prefill = ""; sheet = .byAccount } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title3.weight(.semibold))
                                .frame(width: 54, height: 54)
                                .background(Theme.ink.opacity(0.08), in: .circle)
                            Text("Новий").font(.caption.weight(.medium))
                        }
                    }
                    .buttonStyle(PressScale())
                    ForEach(recipients.prefix(8)) { r in
                        Button { prefill = r.relatedAccount; sheet = .byAccount } label: {
                            VStack(spacing: 6) {
                                // стабільний колір за номером (hashValue між запусками різний)
                                let hue = Double(r.relatedAccount.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 997 }) / 997
                                let shop = r.relatedAccount.hasPrefix("MRC-")
                                Group {
                                    if shop { Image(systemName: "storefront.fill").font(.title3) }
                                    else { Text(String(r.relatedAccount.suffix(2))).font(.headline.monospacedDigit()) }
                                }
                                    .foregroundStyle(.white)
                                    .frame(width: 54, height: 54)
                                    .background(LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.85),
                                                                        Color(hue: hue + 0.08, saturation: 0.7, brightness: 0.55)],
                                                               startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
                                Text(shop ? String(r.relatedAccount.dropFirst(4)).replacingOccurrences(of: "-", with: " ").capitalized
                                          : r.relatedAccount)
                                    .font(.caption2.weight(.medium).monospacedDigit())
                                    .foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(width: 70)
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
    }

    /// Гаманець: справжні картки віялом, верхня - головна; торкання веде у «Картки».
    private var wallet: some View {
        let shownCards = Array(bank.cards.filter { !$0.isClosed }.sorted { $0.isPrimary && !$1.isPrimary }.prefix(3))
        return Button { open(.cards) } label: {
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Гаманець").font(.headline)
                        Text(bank.cards.isEmpty ? "Карток ще немає" : "\(bank.cards.count) " + cardsWord(bank.cards.count))
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding([.horizontal, .top], 18)
                ZStack {
                    if shownCards.isEmpty {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
                            .aspectRatio(1.586, contentMode: .fit)
                            .frame(width: 200)
                            .overlay(Label("Випустити", systemImage: "plus").font(.subheadline.weight(.semibold)))
                    }
                    ForEach(Array(shownCards.enumerated().reversed()), id: \.element.id) { i, c in
                        let spread = Double(i) - Double(shownCards.count - 1) / 2
                        VirtualCardView(number: c.maskedNumber, expiry: c.expiryDisplay, holder: nil, look: c.look,
                                        frozen: c.isBlocked)
                            .frame(width: 230)
                            .scaleEffect(1 - Double(i) * 0.06)
                            .rotationEffect(.degrees(ringIn ? spread * 7 : 0), anchor: .bottom)
                            .offset(x: ringIn ? spread * 34 : 0, y: Double(i) * -10)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.25), value: ringIn)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(PressScale())
    }

    private func cardsWord(_ n: Int) -> String {
        let d = n % 10, h = n % 100
        if d == 1 && h != 11 { return "картка" }
        if (2...4).contains(d) && !(12...14).contains(h) { return "картки" }
        return "карток"
    }

    /// Баланс за 30 днів: лінія з тінню-градієнтом і різниця від початку.
    private var balanceTrend: some View {
        let first = points.first?.balance ?? 0, last = points.last?.balance ?? 0
        let delta = last - first
        let low = points.map(\.balance).min() ?? 0, high = points.map(\.balance).max() ?? 1
        return Card {
            VStack(alignment: .leading, spacing: 4) {
                Text("Баланс за 30 днів").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text((delta >= 0 ? "+" : "−") + Self.compact(abs(delta)))
                        .font(.system(size: 28, weight: .bold)).monospacedDigit()
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                }
                Chart(Array(points.enumerated()), id: \.offset) { i, p in
                    AreaMark(x: .value("День", i), yStart: .value("Мін", low - (high - low) * 0.1), yEnd: .value("Баланс", p.balance))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("День", i), y: .value("Баланс", p.balance))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: (low - (high - low) * 0.1)...(high + (high - low) * 0.1 + 1))
                .frame(height: 90)
                .padding(.top, 10)
                .mask(alignment: .leading) {
                    GeometryReader { g in Rectangle().frame(width: ringIn ? g.size.width : 0) }
                }
                .animation(.easeOut(duration: 1.2).delay(0.3), value: ringIn)
            }
            .padding(18)
        }
    }

    /// Останні операції: значок виду в колі, назва, час і сума.
    private var activity: some View {
        Card {
            if bank.loaded && bank.history.isEmpty {
                Text("Операцій ще немає").foregroundStyle(.secondary).padding(18)
            } else {
                ForEach(Array(bank.history.prefix(4).enumerated()), id: \.element.id) { i, tx in
                    ActivityRow(tx: tx)
                    if i < min(bank.history.count, 4) - 1 { Rule().padding(.leading, 68) }
                }
            }
            Button { open(.operations) } label: {
                Text("Усі операції").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) { Rule() }
        }
    }

    /// Витрати місяця: сума, порівняння з минулим і стовпчики днів.
    private var spending: some View {
        let out = summary?.currentMonth.totalOut ?? 0, prev = summary?.prevMonth.totalOut ?? 0
        let days = dailySpend
        let top = max(days.max() ?? 1, 1)
        return Button { open(.operations) } label: {
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Витрати цього місяця").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Self.compact(out)).font(.system(size: 28, weight: .bold)).monospacedDigit()
                        if prev > 0 {
                            let d = (out - prev) / prev * 100
                            Text("\(d >= 0 ? "+" : "−")\(Int(abs(d).rounded()))% до минулого")
                                .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(days.enumerated()), id: \.offset) { i, v in
                            Capsule()
                                .fill(i == days.count - 1 ? Theme.accent : Theme.ink.opacity(v > 0 ? 0.85 : 0.1))
                                .frame(height: max(4, 70 * CGFloat(ringIn ? v / top : 0.05)))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 72, alignment: .bottom)
                    .padding(.top, 14)
                    .onAppear { withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) { ringIn = true } }
                }
                .padding(18)
            }
        }
        .buttonStyle(PressScale())
    }

    /// Витрати по днях поточного місяця з історії операцій.
    private var dailySpend: [Double] {
        let cal = Calendar.current
        let today = cal.component(.day, from: .now)
        var days = Array(repeating: 0.0, count: max(today, 1))
        let start = cal.date(from: cal.dateComponents([.year, .month], from: .now)) ?? .now
        for tx in bank.history where !tx.isIncome && tx.date >= start {
            let d = cal.component(.day, from: tx.date) - 1
            if days.indices.contains(d) { days[d] += tx.amount }
        }
        return days
    }

    private var taxesCard: some View {
        let next = TaxDeadline.upcoming(group: nil).first
        let left = next.map { max(0, Calendar.current.dateComponents([.day], from: .now, to: $0.date).day ?? 0) } ?? 0
        return Button { open(.taxes) } label: {
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Податки").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("\(left) дн.").font(.system(size: 28, weight: .bold)).monospacedDigit()
                    Text(next?.title ?? "Строків немає").font(.footnote).foregroundStyle(.secondary).lineLimit(2)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PressScale())
    }

    private func shopCard(_ p: API.Product) -> some View {
        Button { open(.shop) } label: {
            Card {
                ZStack(alignment: .bottomLeading) {
                    ProductArt(product: p, size: 50, height: 176, showsLabel: false)
                    Text(Self.compact(p.price)).font(.footnote.weight(.bold)).monospacedDigit()
                        .padding(.horizontal, 10).frame(height: 28)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(10)
                }
            }
        }
        .buttonStyle(PressScale())
    }

    /// Сума без копійок для вузьких місць.
    static func compact(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "uk_UA"))) + " TAX"
    }
}

/// Біла картка на сірому тлі, як у Revolut: великий радіус, без рамок і тіней.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: 24, style: .continuous))
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .contentShape(.rect(cornerRadius: 24, style: .continuous))
    }
}

/// Рядок операції: вид у сірому колі, назва, час, сума праворуч.
struct ActivityRow: View {
    let tx: API.Transaction

    private var symbol: String {
        switch tx.txType {
        case "payment": "bag"
        case "topup": "plus"
        case "transfer": tx.isIncome ? "arrow.down.left" : "arrow.up.right"
        default: tx.isIncome ? "arrow.down" : "arrow.up"
        }
    }

    /// Колір виду: надходження зелені, покупки теплі, перекази сині.
    private var tint: Color {
        if tx.isIncome { return .green }
        switch tx.txType {
        case "payment": return .orange
        case "transfer": return .blue
        default: return .orange
        }
    }

    var body: some View {
        let row = TransactionRow(tx: tx)
        HStack(spacing: 12) {
            GuillocheBadge(symbol: symbol, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).font(.body.weight(.medium)).lineLimit(2)
                Text(tx.date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "uk_UA"))))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text((tx.isIncome ? "+" : "−") + OverviewView.compactCents(tx.amount))
                .font(.body.weight(tx.isIncome ? .bold : .semibold)).monospacedDigit()
                .foregroundStyle(tx.isIncome ? Color.green : Theme.ink.opacity(0.85))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

extension OverviewView {
    /// Сума з копійками лише коли вони є.
    static func compactCents(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "uk_UA"))) + " TAX"
    }
}

/// Баланс у шапці: цілі великим білим, копійки й TAX дрібніше.
struct HeroAmount: View {
    let value: Double
    var hidden = false

    var body: some View {
        let s = value.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "uk_UA")))
        let parts = s.split(separator: ",", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if hidden {
                Text("••••••").font(.system(size: 52, weight: .bold))
            } else {
                Text(parts.first ?? s).font(.system(size: 56, weight: .bold)).tracking(-1.5)
                if parts.count > 1, parts[1] != "00" {
                    Text(",\(parts[1])").font(.system(size: 28, weight: .semibold)).opacity(0.75)
                }
            }
            Text(" TAX").font(.system(size: 20, weight: .semibold)).opacity(0.75)
        }
        .monospacedDigit()
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText(value: value))
    }
}

/// Фон шапки: темна синя сцена, що повільно переливається й тане донизу; тепло дає золотий гільйош.
struct HeroGradient: View {
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { tl in
            let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
            let navy = Color(red: 0.07, green: 0.11, blue: 0.24)
            let deep = Color(red: 0.03, green: 0.04, blue: 0.09)
            let blue = Color(red: 0.13, green: 0.22, blue: 0.48)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [Float(0.5 + 0.15 * sin(t * 0.25)), 0], [1, 0],
                    [0, Float(0.45 + 0.1 * cos(t * 0.2))], [Float(0.5 + 0.18 * cos(t * 0.3)), Float(0.5 + 0.12 * sin(t * 0.22))], [1, Float(0.5 + 0.1 * sin(t * 0.27))],
                    [0, 1], [Float(0.5 + 0.12 * sin(t * 0.18)), 1], [1, 1],
                ],
                colors: [
                    deep, navy, blue,
                    navy, blue, navy,
                    deep, navy, deep,
                ]
            )
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.78),
                                         .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
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
                Text(parts.first ?? s).font(.display(size)).tracking(-size * 0.025)
                if parts.count > 1, parts[1] != "00" {
                    Text(",\(parts[1])").font(.system(size: size * 0.5, weight: .regular)).foregroundStyle(.secondary)
                }
            }
            Text(" TAX").font(.system(size: size * 0.36, weight: .semibold)).foregroundStyle(.secondary)
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
        Group {
            if letters.contains(where: \.isLetter) || letters.isEmpty {
                Text(letters.isEmpty ? "TT" : letters).font(.system(size: size * 0.36, weight: .semibold))
            } else {
                Image(systemName: "person.fill").font(.system(size: size * 0.4, weight: .medium)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
            .background(Theme.surface, in: .circle)
            .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
    }
}

/// Значок дії в шапці: без підкладки, лише гліф і зона дотику.
struct RoundGlyph: View {
    let symbol: String

    var body: some View {
        GuillocheBadge(symbol: symbol, tint: Theme.accent, size: 40)
            .contentShape(.circle)
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
