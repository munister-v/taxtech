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
    @State private var selected: API.Transaction?
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
            .screenBackground()
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
            .sheet(item: $selected) { tx in TransactionDetailView(tx: tx) }
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

    /// Спокійна шапка на тлі екрана: аватар і сповіщення, баланс по центру, рахунок і круглі дії.
    private var hero: some View {
        VStack(spacing: 0) {
            HStack {
                Button { showProfile = true } label: {
                    // поки профіль не прийшов - значок, а не чужі «TT», що потім стрибають на справжні
                    AvatarView(initials: initials ?? "TT", size: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Профіль").s)
                Spacer()
                BrandLockup(height: 26, color: Theme.ink)
                Spacer()
                NavigationLink { NoticesView() } label: {
                    Image(systemName: unread > 0 ? "bell.badge" : "bell").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                        .symbolEffect(.wiggle, value: unread)
                        .frame(width: 40, height: 40)
                        .background(Theme.surface, in: .circle)
                        .overlay(Circle().strokeBorder(Theme.line, lineWidth: Theme.hairline))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(unread > 0 ? L("Сповіщення, нових: \(unread)").s : L("Сповіщення").s)
            }
            .padding(.top, 8)
            .rise(0)

            VStack(spacing: 6) {
                Text(L("Основний рахунок · TAX").s).caption()
                Button { withAnimation(.snappy) { hidden.toggle() } } label: {
                    HeroAmount(value: shown, hidden: hidden)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hidden ? L("Показати баланс").s : L("Сховати баланс").s)
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
            .padding(.top, 44)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
            .rise(1)

            HStack(alignment: .top, spacing: 0) {
                CircleAction(title: L("Поповнити").s, symbol: "plus", primary: true) { sheet = .topUp }
                CircleAction(title: L("Переказ").s, symbol: "arrow.right") { prefill = ""; sheet = .byAccount }
                CircleAction(title: L("На картку").s, symbol: "creditcard") { sheet = .byCard }
                CircleAction(title: L("Податки").s, symbol: "percent") { open(.taxes) }
            }
            .padding(.bottom, 24)
            .rise(2)
        }
        .padding(.horizontal, Theme.gutter)
        .background(alignment: .top) {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width * 0.5, y: size.height * 0.34)
                Engraving.rosette(in: &ctx, center: c, radius: size.width * 0.62, curves: 26, lobes: 8, depth: 0.2, second: 0.06,
                                  steps: 220, color: Theme.goldLight.opacity(0.11), width: 0.4)
                Engraving.rings(in: &ctx, center: c, from: size.width * 0.58, to: size.width * 0.61, count: 3, color: Theme.goldLight.opacity(0.14))
            }
            .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
            .allowsHitTesting(false)
        }
    }

    private var initials: String? {
        let l = (me?.fullName ?? "").split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return l.isEmpty ? nil : l
    }

    private func monthPill(_ symbol: String, _ text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2.weight(.bold)).foregroundStyle(tint)
            Text(text).font(.caption.weight(.semibold)).monospacedDigit()
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
    }

    // MARK: Картки під шапкою

    /// Швидкий переказ тим, кому вже надсилали: кружки з кольором за номером рахунку.
    private var quickTransfer: some View {
        Card {
            HStack {
                Text(L("Швидкий переказ").s).caption()
                Spacer()
                Text(L("за історією").s).font(.footnote).foregroundStyle(.secondary)
            }
            .padding([.horizontal, .top], 18)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    Button { prefill = ""; sheet = .byAccount } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.title3.weight(.semibold))
                                .frame(width: 54, height: 54)
                                .foregroundStyle(Theme.accent)
                                .background(Theme.bg, in: .circle)
                                .overlay(Circle().strokeBorder(Theme.edge, lineWidth: 0.9))
                            Text(L("Новий").s).font(.caption.weight(.medium))
                        }
                    }
                    .buttonStyle(PressScale())
                    ForEach(recipients.prefix(8)) { r in
                        Button { prefill = r.relatedAccount; sheet = .byAccount } label: {
                            VStack(spacing: 6) {
                                let shop = r.relatedAccount.hasPrefix("MRC-")
                                Group {
                                    if shop { Image(systemName: "storefront.fill").font(.title3) }
                                    else { Text(String(r.relatedAccount.suffix(2))).font(.custom("Futura-Medium", size: 19)).monospacedDigit() }
                                }
                                    .foregroundStyle(Theme.goldFill)
                                    .frame(width: 54, height: 54)
                                    .background(Theme.surface, in: .circle)
                                    .overlay(Circle().strokeBorder(Theme.edge, lineWidth: 0.9))
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
                        Text(L("Гаманець").s).caption()
                        Text(bank.cards.isEmpty ? L("Карток ще немає").s : "\(bank.cards.count) " + cardsWord(bank.cards.count))
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
                            .overlay(Label(L("Випустити").s, systemImage: "plus").font(.subheadline.weight(.semibold)))
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
        if d == 1 && h != 11 { return L("картка").s }
        if (2...4).contains(d) && !(12...14).contains(h) { return L("картки").s }
        return L("карток").s
    }

    /// Баланс за 30 днів: лінія з тінню-градієнтом і різниця від початку.
    private var balanceTrend: some View {
        let first = points.first?.balance ?? 0, last = points.last?.balance ?? 0
        let delta = last - first
        let low = points.map(\.balance).min() ?? 0, high = points.map(\.balance).max() ?? 1
        return Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Баланс за 30 днів").s).caption()
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text((delta >= 0 ? "+" : "−") + Self.compact(abs(delta)))
                        .font(.custom("Futura-Medium", size: 30)).monospacedDigit()
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                }
                Chart(Array(points.enumerated()), id: \.offset) { i, p in
                    AreaMark(x: .value(L("День").s, i), yStart: .value(L("Мін").s, low - (high - low) * 0.1), yEnd: .value(L("Баланс").s, p.balance))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value(L("День").s, i), y: .value(L("Баланс").s, p.balance))
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

    /// Останні операції: заголовок із переходом у всі, рядки відкривають саму операцію.
    private var activity: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Останні").s).caption()
                Spacer()
                Button { open(.operations) } label: {
                    HStack(spacing: 4) {
                        Text(L("Усі").s)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 4)
            if bank.loaded && bank.history.isEmpty {
                Text(L("Операцій ще немає").s).foregroundStyle(.secondary).padding(18)
            } else {
                ForEach(Array(bank.history.prefix(4).enumerated()), id: \.element.id) { i, tx in
                    Button { selected = tx } label: { ActivityRow(tx: tx).contentShape(.rect) }
                        .buttonStyle(PressScale())
                    if i < min(bank.history.count, 4) - 1 { Rule().padding(.leading, 68) }
                }
                Spacer().frame(height: 6)
            }
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
                    Text(L("Витрати цього місяця").s).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Self.compact(out)).font(.system(size: 28, weight: .bold)).monospacedDigit()
                        if prev > 0 {
                            let d = (out - prev) / prev * 100
                            Text(L("\(d >= 0 ? "+" : "−")\(Int(abs(d).rounded()))% до минулого").s)
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
                    Text(L("Податки").s).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(L("\(left) дн.").s).font(.system(size: 28, weight: .bold)).monospacedDigit()
                    Text(next?.title ?? L("Строків немає").s).font(.footnote).foregroundStyle(.secondary).lineLimit(2)
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
        v.formatted(.number.precision(.fractionLength(0)).locale(Lang.current.locale)) + " TAX"
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
            .goldEdge(24)
            .contentShape(.rect(cornerRadius: 24, style: .continuous))
    }
}

/// Значок виду операції: тонований круг. Надходження зелені, покупки жовті, перекази сині.
struct TxGlyph: View {
    let tx: API.Transaction
    var size: CGFloat = 46

    private var symbol: String {
        switch tx.txType {
        case "payment": "bag.fill"
        case "topup": "plus"
        case "transfer": tx.isIncome ? "arrow.down.left" : "arrow.up.right"
        default: tx.isIncome ? "arrow.down" : "arrow.up"
        }
    }

    private var tint: Color {
        if tx.isIncome { return Color(red: 0.20, green: 0.78, blue: 0.50) }
        switch tx.txType {
        case "payment": return Theme.accent
        case "transfer": return Color(red: 0.35, green: 0.56, blue: 0.95)
        default: return Color(red: 0.88, green: 0.62, blue: 0.25)
        }
    }

    var body: some View { GuillocheBadge(symbol: symbol, tint: tint, size: size) }
}

/// Рядок операції: значок, назва у два рядки, час, сума праворуч з підписом TAX.
struct ActivityRow: View {
    let tx: API.Transaction

    var body: some View {
        let row = TransactionRow(tx: tx)
        HStack(spacing: 14) {
            TxGlyph(tx: tx)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title).font(.body.weight(.medium)).lineLimit(2)
                Text(tx.date.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(Lang.current.locale)))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 1) {
                Text((tx.isIncome ? "+" : "−") + tx.amount.formatted(.number.precision(.fractionLength(0...2)).locale(Lang.current.locale)))
                    .font(.custom("Futura-Medium", size: 20)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(tx.isIncome ? Color.green : Theme.ink)
                Text("TAX").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

extension OverviewView {
    /// Сума з копійками лише коли вони є.
    static func compactCents(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2)).locale(Lang.current.locale)) + " TAX"
    }
}

/// Баланс у шапці: цілі великим, копійки й TAX дрібніше.
struct HeroAmount: View {
    let value: Double
    var hidden = false

    var body: some View {
        let s = value.formatted(.number.precision(.fractionLength(2)).locale(Lang.current.locale))
        let parts = s.split(separator: ",", maxSplits: 1).map(String.init)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if hidden {
                Text("••••••").font(.custom("Futura-Medium", size: 52))
            } else {
                Text(parts.first ?? s).font(.custom("Futura-Medium", size: 58)).tracking(-1)
                if parts.count > 1, parts[1] != "00" {
                    Text(",\(parts[1])").font(.custom("Futura-Medium", size: 28)).opacity(0.55)
                }
            }
            Text(" TAX").font(.custom("Futura-Medium", size: 20)).tracking(2).foregroundStyle(Theme.accent)
        }
        .monospacedDigit()
        .foregroundStyle(Theme.goldFill)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText(value: value))
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
