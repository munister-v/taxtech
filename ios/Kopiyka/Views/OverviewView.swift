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
                VStack(alignment: .leading, spacing: 28) {
                    header
                    balance
                    Group {
                        actions
                        cards
                        if let s = summary, s.currentMonth.totalOut > 0 { month(s) }
                        products
                        taxes
                        if !hits.isEmpty { shop }
                        if Set(points.map(\.balance)).count > 1 { dynamics }
                        if !recipients.isEmpty { frequent }
                        recent
                    }
                    .scrollTransition(.animated(.smooth(duration: 0.35))) { v, phase in
                        v.opacity(phase.isIdentity ? 1 : 0.35)
                            .scaleEffect(phase.isIdentity ? 1 : 0.96, anchor: phase.value > 0 ? .top : .bottom)
                            .offset(y: phase.value > 0 ? 18 : 0)
                    }
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
        if hits.isEmpty {
            hits = ((try? await model.api.catalog(search: "", page: 1, sort: "stock", perPage: 40))?.items ?? [])
                .filter { ["HOT", "TOP", "NEW"].contains($0.badge ?? "") }
        }
    }

    // MARK: Шапка

    private var header: some View {
        HStack(spacing: 8) {
            MarkView(height: 22, color: Theme.accent)
            Text("TaxTech").font(.system(size: 20, weight: .bold)).tracking(-0.3)
            Spacer()
            NavigationLink { NoticesView() } label: {
                RoundGlyph(symbol: unread > 0 ? "bell.badge" : "bell")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(unread > 0 ? "Сповіщення, нових: \(unread)" : "Сповіщення")
            Button { showProfile = true } label: { Initials(name: me?.fullName ?? "", size: 34) }
                .buttonStyle(.plain)
                .accessibilityLabel("Профіль")
        }
        .padding(.top, 8)
    }

    // MARK: Баланс

    private var balance: some View {
        HeroPanel(yellow: true) {
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
            BigAmount(value: shown, hidden: hidden, size: 54)
                .foregroundStyle(Theme.onAccent)
                .padding(.top, 8)
                .redacted(reason: bank.loaded ? [] : .placeholder)
                .onChange(of: bank.account?.balance) { _, v in
                    guard let v else { return }
                    withAnimation(.smooth(duration: 1.1)) { shown = v }
                }
                .sensoryFeedback(.success, trigger: shown > 0)
            if let n = bank.account?.accountNumber {
                Button { UIPasteboard.general.string = n } label: {
                    Label(n, systemImage: "doc.on.doc").labelStyle(TrailingIcon())
                }
                .buttonStyle(.plain)
                .font(.footnote.monospaced())
                .foregroundStyle(Theme.onAccent.opacity(0.6))
                .padding(.top, 4)
            }
            if Set(points.map(\.balance)).count > 1 { spark.padding(.top, 14) }
            if let s = summary, s.currentMonth.totalIn > 0 || s.currentMonth.totalOut > 0 {
                HStack(spacing: 10) {
                    flow("arrow.down.left", "+" + Format.money(s.currentMonth.totalIn), "Надійшло")
                    flow("arrow.up.right", "−" + Format.money(s.currentMonth.totalOut), "Витрачено")
                }
                .padding(.top, 18)
            }
        }
    }

    /// Баланс за 30 днів прямо на жовтій панелі: чорна лінія, що домальовується при появі.
    private var spark: some View {
        let values = points.map(\.balance)
        let lo = values.min() ?? 0, hi = max(values.max() ?? 1, lo + 1)
        return GeometryReader { g in
            let step = g.size.width / CGFloat(max(values.count - 1, 1))
            let pts = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i) * step, y: g.size.height * (1 - CGFloat((v - lo) / (hi - lo))))
            }
            ZStack(alignment: .topLeading) {
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: CGPoint(x: f.x, y: g.size.height))
                    pts.forEach { p.addLine(to: $0) }
                    p.addLine(to: CGPoint(x: pts.last?.x ?? 0, y: g.size.height))
                }
                .fill(Theme.onAccent.opacity(0.07))
                .opacity(drawn)
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: f)
                    pts.dropFirst().forEach { p.addLine(to: $0) }
                }
                .trim(from: 0, to: drawn)
                .stroke(Theme.onAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                if let last = pts.last, drawn >= 1 {
                    Circle().fill(Theme.onAccent).frame(width: 9, height: 9)
                        .position(last)
                        .transition(.scale)
                }
            }
        }
        .frame(height: 54)
        .onAppear { withAnimation(.easeInOut(duration: 1.2).delay(0.2)) { drawn = 1 } }
        .accessibilityLabel("Баланс за 30 днів")
    }

    /// Рух за місяць: чорне коло зі стрілкою, сума й підпис.
    private func flow(_ symbol: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Theme.onAccent, in: .circle)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                Text(label).font(.caption.weight(.medium)).foregroundStyle(Theme.onAccent.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.onAccent.opacity(0.08), in: .rect(cornerRadius: 14, style: .continuous))
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: 8) {
            CircleAction(title: "Поповнити", symbol: "plus", primary: true) { sheet = .topUp }
            CircleAction(title: "На картку", symbol: "creditcard") { sheet = .byCard }
            CircleAction(title: "За рахунком", symbol: "arrow.left.arrow.right") { prefill = ""; sheet = .byAccount }
            CircleAction(title: "Податки", symbol: "percent") { open(.taxes) }
        }
    }

    // MARK: Картки

    private var cards: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Мої картки").font(.title3.weight(.bold))
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
                                .shadow(color: .black.opacity(0.3), radius: 14, y: 8)
                                .scrollTransition(axis: .horizontal) { v, phase in
                                    v.scaleEffect(phase.isIdentity ? 1 : 0.9)
                                        .opacity(phase.isIdentity ? 1 : 0.55)
                                        .rotation3DEffect(.degrees(phase.value * -18), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
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

    // MARK: Цей місяць

    /// Куди пішли гроші цього місяця: кільце за видами, найбільший - жовтий.
    private func month(_ s: API.Analytics) -> some View {
        let out = s.byType.filter { $0.direction == "out" && $0.total > 0 }.sorted { $0.total > $1.total }
        let total = max(out.reduce(0) { $0 + $1.total }, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Цей місяць").font(.title3.weight(.bold))
            Surface {
                HStack(spacing: 18) {
                    ZStack {
                        Chart(Array(out.enumerated()), id: \.element.id) { i, t in
                            SectorMark(angle: .value("Сума", ringIn ? t.total : total / 1000), innerRadius: .ratio(0.68), angularInset: 1.5)
                                .foregroundStyle(i == 0 ? Theme.accent : Theme.ink.opacity(max(0.15, 0.7 - Double(i) * 0.15)))
                                .cornerRadius(3)
                        }
                        VStack(spacing: 0) {
                            Text("\(out.count)").font(.title3.weight(.bold))
                            Text("видів").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 112, height: 112)
                    .onAppear { withAnimation(.smooth(duration: 0.9).delay(0.1)) { ringIn = true } }
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(out.prefix(4).enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(i == 0 ? Theme.accent : Theme.ink.opacity(max(0.15, 0.7 - Double(i) * 0.15)))
                                    .frame(width: 10, height: 10)
                                Text(BankText.type(t.txType)).font(.subheadline).lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Int((t.total / total * 100).rounded()))%").font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: Мої продукти

    private var products: some View {
        let dep = bank.deposits.reduce(0) { $0 + $1.amount }
        let debt = bank.credits.reduce(0) { $0 + $1.balanceRemaining }
        let saved = bank.goals.reduce(0) { $0 + $1.currentAmount }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Мої продукти").font(.title3.weight(.bold))
            HStack(spacing: 10) {
                product("Депозити", "banknote", dep) { DepositsView() }
                product("Кредити", "percent", debt) { CreditsView() }
                product("Цілі", "target", saved) { GoalsView() }
            }
        }
    }

    private func product<D: View>(_ title: String, _ symbol: String, _ value: Double, @ViewBuilder _ to: @escaping () -> D) -> some View {
        NavigationLink { to() } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                Text(value > 0 ? Format.money(value).replacingOccurrences(of: ",00", with: "") : "Відкрити")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressScale())
    }

    // MARK: Магазин

    private var shop: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Магазин TaxTech").font(.title3.weight(.bold))
                Spacer()
                Button("Усі") { open(.shop) }.font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(hits.prefix(8)) { p in
                        Button { open(.shop) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ProductArt(product: p, size: 40, height: 96)
                                Text(p.title).font(.footnote.weight(.semibold)).lineLimit(2, reservesSpace: true)
                                    .multilineTextAlignment(.leading)
                                Text(Format.money(p.price)).font(.subheadline.weight(.bold)).monospacedDigit()
                            }
                            .frame(width: 136)
                            .padding(10)
                            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(PressScale())
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    // MARK: Податки

    private var taxes: some View {
        let next = TaxDeadline.upcoming(group: nil).first
        return Button { open(.taxes) } label: {
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Податки").font(.headline)
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
                Text("Динаміка балансу").font(.title3.weight(.bold))
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
                .chartXScale(range: .plotDimension(padding: 14))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
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
            Text("Часті отримувачі").font(.title3.weight(.bold))
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
                Text("Останні операції").font(.title3.weight(.bold))
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
                Text(parts.first ?? s).font(.system(size: size, weight: .semibold)).tracking(-1)
                if parts.count > 1 {
                    Text(",\(parts[1])").font(.system(size: size * 0.5, weight: .regular)).foregroundStyle(.secondary)
                }
            }
            Text(" TAX").font(.system(size: size * 0.42, weight: .bold)).tracking(0.5).foregroundStyle(.secondary)
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
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .regular))
            .frame(width: 36, height: 36)
            .foregroundStyle(Theme.ink)
            .contentShape(.rect)
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
