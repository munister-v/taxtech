import Charts
import SwiftUI

/// Операції: пошук, фільтр і сортування, витрати за період, на що йдуть гроші, спостереження, історія по днях.
struct OperationsView: View {
    @Environment(AppModel.self) private var model
    @State private var filter = API.HistoryFilter()
    @State private var items: [API.Transaction] = []
    @State private var summary: API.Analytics?
    @State private var insights: [API.Insight] = []
    @State private var sort = Sort.newest
    @State private var period = Period.month
    @State private var selected: API.Transaction?
    @State private var loaded = false
    @State private var topUp = false
    @State private var recent = RecentSearches.all
    @FocusState private var searchFocus: Bool

    enum Sort: String, CaseIterable { case newest = "Нові", oldest = "Старі", amount = "Сума"
        var label: String { Translator.text(rawValue, []) } }

    enum Period: String, CaseIterable {
        case week = "Тиж", month = "Міс", year = "Рік"
        var label: String { Translator.text(rawValue, []) }
        var title: String { switch self { case .week: L("тиждень").s; case .month: L("місяць").s; case .year: L("рік").s } }
        var start: Date {
            let cal = Calendar.current
            switch self {
            case .week: return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now)) ?? .now
            case .month: return cal.dateInterval(of: .month, for: .now)?.start ?? .now
            case .year: return cal.dateInterval(of: .year, for: .now)?.start ?? .now
            }
        }
        var unit: Calendar.Component { self == .year ? .month : .day }
    }

    private var sorted: [API.Transaction] {
        switch sort {
        case .newest: items.sorted { $0.date > $1.date }
        case .oldest: items.sorted { $0.date < $1.date }
        case .amount: items.sorted { $0.amount > $1.amount }
        }
    }

    private var days: [(day: Date, items: [API.Transaction])] {
        Dictionary(grouping: sorted) { Calendar.current.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value) }
            .sorted { sort == .oldest ? $0.day < $1.day : $0.day > $1.day }
    }

    private var spent: [API.Transaction] { items.filter { !$0.isIncome && $0.date >= period.start } }

    var body: some View {
        NavigationStack {
            ScrollView {
                // лінива колонка: з історії на сотні операцій малюється лише те, що на екрані
                LazyVStack(alignment: .leading, spacing: 24) {
                    header
                    search
                    TextTabs(items: [(String?.none, L("Усі").s), (String?.some("in"), L("Надходження").s), (String?.some("out"), L("Витрати").s)],
                             selection: $filter.direction)
                    if filter.search.isEmpty && !items.isEmpty { flow }
                    // без витрат за період велика порожня панель нічого не каже
                    if filter.search.isEmpty && filter.direction != "in" && !spent.isEmpty { spending }
                    if filter.search.isEmpty, let summary { byType(summary) }
                    if filter.search.isEmpty && !insights.isEmpty && model.expert { insightList }
                    history
                    if filter.search.isEmpty {
                        Surface {
                            VStack(spacing: 0) {
                                LearnLink(.ledger)
                                Rule().padding(.vertical, 6)
                                LearnLink(.merkle)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                        .expertOnly()
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .scrollsToTopOnRetap(.operations)
            .scrollDismissesKeyboard(.interactively)
            .sensoryFeedback(.selection, trigger: period)
            .auroraBackground(warm: Theme.amber, cool: Theme.auraBronze)
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(filter.search)|\(filter.direction ?? "")") {
                if !loaded, let hit = model.api.cached("transactions/history", as: [API.Transaction].self) {
                    items = hit
                    loaded = true
                }
                // пауза потрібна лише пошуку: перше завантаження й перемикання вкладок не чекають
                if !filter.search.isEmpty { try? await Task.sleep(for: .milliseconds(250)) }
                guard !Task.isCancelled else { return }
                if let fresh = try? await model.api.history(filter) { items = fresh } else if !loaded { items = [] }
                loaded = true
            }
            .task {
                async let s = model.api.analytics()
                async let i = model.api.insights()
                summary = try? await s
                insights = (try? await i) ?? []
            }
            .refreshable {
                if let fresh = try? await model.api.history(filter) { items = fresh }
                if let s = try? await model.api.analytics() { summary = s }
            }
            .onChange(of: model.syncTick) { _, _ in
                Task { if let fresh = try? await model.api.history(filter) { items = fresh } }
            }
            .sheet(item: $selected) { tx in TransactionDetailView(tx: tx) }
        }
    }

    private var header: some View {
        ScreenTitle(title: RootView.AppTab.operations.title) {
            HStack(spacing: 8) {
                NavigationLink { StatementsView() } label: { RoundGlyph(symbol: "doc.text") }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Виписки").s)
                NavigationLink { DocumentsView() } label: { RoundGlyph(symbol: "qrcode") }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Мої документи").s)
                NavigationLink { AnalyticsView() } label: { RoundGlyph(symbol: "chart.bar") }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L("Аналітика").s)
            }
        }
    }

    private var search: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            if searchFocus, filter.search.isEmpty, !recent.isEmpty { recentChips }
        }
        .animation(.snappy, value: searchFocus)
    }

    /// Недавні запити: торкнутися - підставити, хрестик - стерти всі.
    private var recentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recent, id: \.self) { q in
                    Button { filter.search = q } label: {
                        Label(q, systemImage: "clock.arrow.circlepath")
                            .font(Theme.ui(style: .footnote, .medium))
                            .padding(.horizontal, 12).frame(height: 32)
                            .glassCapsule().foregroundStyle(Theme.ink)
                    }
                    .buttonStyle(PressScale())
                }
                Button { RecentSearches.clear(); recent = [] } label: {
                    Image(systemName: "xmark").font(Theme.ui(style: .caption1, .bold))
                        .frame(width: 32, height: 32).glassCircle().foregroundStyle(.secondary)
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(L("Очистити").s)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(searchFocus ? Theme.accent : Theme.muted)
            TextField(L("Пошук транзакцій…").s, text: $filter.search)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocus)
                .onSubmit { recent = RecentSearches.add(filter.search) }
            if !filter.search.isEmpty {
                Button { filter.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(searchFocus ? Theme.accent.opacity(0.7) : Theme.line, lineWidth: searchFocus ? 1.2 : Theme.hairline))
        .shadow(color: Theme.accent.opacity(searchFocus ? 0.25 : 0), radius: 10)
        .animation(.easeOut(duration: 0.2), value: searchFocus)
    }

    /// Надійшло і витрачено за обраний період: дві рівні плитки над графіком.
    private var flow: some View {
        let inRange = items.filter { $0.date >= period.start }
        let income = inRange.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let outgo = inRange.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        return HStack(spacing: 12) {
            flowTile(L("Надійшло").s, symbol: "arrow.down.left", value: income, tint: Theme.income)
            flowTile(L("Витрачено").s, symbol: "arrow.up.right", value: outgo, tint: Theme.expense)
        }
    }

    private func flowTile(_ title: String, symbol: String, value: Double, tint: Color) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(Theme.ui(style: .caption1, .bold)).foregroundStyle(tint)
                    Text(title).font(Theme.ui(style: .footnote, .medium)).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(period.title).font(Theme.ui(style: .caption2, .semibold)).foregroundStyle(.tertiary)
                }
                Text(OverviewView.compactCents(value))
                    .font(Theme.ui(22, .semibold)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: value))
            }
            .padding(14)
        }
        .animation(.snappy, value: period)
    }

    // MARK: Витрати за період

    private var spending: some View {
        let byBucket = Dictionary(grouping: spent) { Calendar.current.dateInterval(of: period.unit, for: $0.date)?.start ?? $0.date }
            .map { (day: $0.key, sum: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.day < $1.day }
        return HeroPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    HeroCaption(L("Витрати за \(period.title)").s)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(Period.allCases, id: \.self) { p in
                            Button(p.label) { period = p }
                                .font(Theme.ui(style: .caption1, .semibold))
                                .frame(width: 42, height: 26)
                                .background(period == p ? Theme.accent : .clear, in: .rect(cornerRadius: 7, style: .continuous))
                                .foregroundStyle(period == p ? AnyShapeStyle(Theme.onAccent) : AnyShapeStyle(Theme.muted))
                        }
                    }
                    .buttonStyle(.plain)
                }
                BigAmount(value: spent.reduce(0) { $0 + $1.amount }, size: 38)
                if byBucket.isEmpty {
                    Text(L("Витрат за цей час немає").s).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                } else {
                    Chart(byBucket, id: \.day) { b in
                        BarMark(x: .value(L("Коли").s, b.day, unit: period.unit), y: .value(L("Сума").s, b.sum))
                            .foregroundStyle(b.day == byBucket.last?.day
                                ? AnyShapeStyle(LinearGradient(colors: [Theme.goldLight, Theme.gold], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(LinearGradient(colors: [Theme.gold.opacity(0.55), Theme.gold.opacity(0.22)], startPoint: .top, endPoint: .bottom)))
                            .cornerRadius(5)
                    }
                    .chartYAxis(.hidden)
                    // шкала від початку періоду до сьогодні: один день не розтягується на всю картку
                    .chartXScale(domain: min(period.start, byBucket.first?.day ?? period.start)...Date.now.addingTimeInterval(period == .year ? 86400 * 20 : 86400),
                                 range: .plotDimension(padding: 14))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel(format: period == .year
                                ? .dateTime.month(.abbreviated).locale(Lang.current.locale)
                                : .dateTime.day().month(.twoDigits).locale(Lang.current.locale))
                        }
                    }
                    .frame(height: 130)
                }
            }
        }
    }

    /// Палітра видів витрат: перший - фірмовий жовтий, далі спокійні, але розрізнені кольори.
    static let palette: [Color] = [Theme.accent, Theme.info, Theme.expense, Theme.income, Theme.violet,
                                   Color(red: 0.49, green: 0.78, blue: 0.75), Color(red: 0.85, green: 0.66, blue: 0.77), Color(white: 0.58)]

    @ViewBuilder private func byType(_ s: API.Analytics) -> some View {
        let out = s.byType.filter { $0.direction == "out" && $0.total > 0 }.sorted { $0.total > $1.total }
        let total = max(out.reduce(0) { $0 + $1.total }, 1)
        if !out.isEmpty { VStack(alignment: .leading, spacing: 12) {
            BlockTitle(L("Витрати за видами").s)
            Surface {
                HStack(alignment: .center, spacing: 18) {
                    Chart(Array(out.enumerated()), id: \.element.id) { i, t in
                        SectorMark(angle: .value(L("Сума").s, t.total), innerRadius: .ratio(0.64), angularInset: 2)
                            .cornerRadius(4)
                            .foregroundStyle(Self.palette[i % Self.palette.count])
                    }
                    .chartBackground { _ in
                        VStack(spacing: 0) {
                            Text("\(out.count)").font(Theme.mono(style: .title2, .bold)).monospacedDigit()
                            Text(L("видів").s).font(Theme.ui(style: .caption2)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(out.prefix(6).enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 8) {
                                Circle().fill(Self.palette[i % Self.palette.count]).frame(width: 9, height: 9)
                                Text(BankText.type(t.txType)).font(Theme.ui(style: .subheadline)).lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Int((t.total / total * 100).rounded()))%")
                                    .font(Theme.ui(style: .subheadline, .semibold)).monospacedDigit()
                            }
                        }
                    }
                }
                .padding(16)
            }
        } }
    }

    private var insightList: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle(L("Аналітика").s)
            Surface {
                ForEach(Array(insights.enumerated()), id: \.offset) { i, ins in
                    if i > 0 { Rule() }
                    HStack(alignment: .top, spacing: 12) {
                        let marks = ["flame", "calendar", "sum", "leaf", "sparkles"]
                        let tints: [Color] = [Theme.expense, Theme.info, Theme.violet, Theme.income, Theme.accent]
                        GuillocheBadge(symbol: marks[i % marks.count], tint: tints[i % tints.count], size: 36)
                        Text(Translator.server(ins.text)).font(Theme.ui(style: .subheadline)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: Історія

    @ViewBuilder private var history: some View {
        if !loaded {
            Surface { ForEach(0..<6, id: \.self) { _ in SkeletonRow() } }
        } else if items.isEmpty {
            if filter.search.isEmpty && filter.direction == nil {
                BrandEmpty(title: L("Операцій ще немає").s, detail: L("Поповніть рахунок, і тут з'являться покупки, перекази та графіки").s,
                           symbol: "list.bullet.rectangle", action: L("Поповнити рахунок").s) { topUp = true }
                    .sheet(isPresented: $topUp) { TopUpView { items = (try? await model.api.history(filter)) ?? []; summary = try? await model.api.analytics() } }
            } else {
                BrandEmpty(title: L("Нічого не знайдено").s, detail: L("Спробуйте інше слово або змініть фільтр").s, symbol: "magnifyingglass",
                           action: Tx("Скинути пошук", "Clear search", "Сбросить поиск")) {
                    withAnimation(.snappy) { filter.search = ""; filter.direction = nil }
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Історія").s).font(Theme.ui(style: .title3, .bold))
                let net = items.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
                Text("\(items.count)").foregroundStyle(.secondary).monospacedDigit()
                Text((net >= 0 ? "+" : "−") + OverviewView.compactCents(abs(net)))
                    .font(Theme.ui(style: .footnote, .semibold)).monospacedDigit()
                    .foregroundStyle(net >= 0 ? Theme.income : Theme.expense)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((net >= 0 ? Theme.income : Theme.expense).opacity(0.14), in: .capsule)
                Spacer()
                if let csv = StatementCSV.file(for: items) {
                    ShareLink(item: csv) {
                        Image(systemName: "square.and.arrow.up").font(Theme.ui(style: .subheadline, .medium)).foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel(Tx("Виписка CSV", "Statement CSV", "Выписка CSV"))
                }
                Menu {
                    Picker(L("Сортування").s, selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } label: {
                    Label(sort.label, systemImage: "arrow.up.arrow.down")
                        .font(Theme.ui(style: .subheadline, .medium)).foregroundStyle(Theme.ink)
                }
            }
            .padding(.top, 4)
        }
        if sort == .amount {
            Surface {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { i, tx in
                    if i > 0 { Rule() }
                    row(tx)
                }
            }
        } else {
            ForEach(days, id: \.day) { day in
                VStack(alignment: .leading, spacing: 8) {
                    let net = day.items.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
                    DayRibbon(title: BankText.dayTitle(day.day),
                              trailing: (net >= 0 ? "+" : "−") + OverviewView.compactCents(abs(net)),
                              positive: net >= 0)
                    Surface {
                        ForEach(Array(day.items.enumerated()), id: \.element.id) { i, tx in
                            if i > 0 { Rule() }
                            row(tx)
                        }
                    }
                }
            }
        }
    }

    private func row(_ tx: API.Transaction) -> some View {
        Button { selected = tx } label: { ActivityRow(tx: tx).contentShape(.rect) }
            .buttonStyle(RowPress())
            .contextMenu {
                Button(L("Скопіювати суму").s, systemImage: "doc.on.doc") { model.copy(Format.amount(tx.amount)) }
                if let r = tx.relatedAccount {
                    Button(L("Скопіювати отримувача").s, systemImage: "person.crop.circle") { model.copy(BankText.recipient(r)) }
                    Button(L("Усі операції з ним").s, systemImage: "magnifyingglass") {
                        withAnimation(.snappy) { filter.search = r }
                    }
                }
            }
    }
}
