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
                VStack(alignment: .leading, spacing: 24) {
                    header
                    search
                    TextTabs(items: [(String?.none, L("Усі").s), (String?.some("in"), L("Надходження").s), (String?.some("out"), L("Витрати").s)],
                             selection: $filter.direction)
                    if filter.search.isEmpty && filter.direction != "in" { spending }
                    if filter.search.isEmpty, let summary { byType(summary) }
                    if filter.search.isEmpty && !insights.isEmpty { insightList }
                    history
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(filter.search)|\(filter.direction ?? "")") {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                items = (try? await model.api.history(filter)) ?? []
                loaded = true
            }
            .task {
                async let s = model.api.analytics()
                async let i = model.api.insights()
                summary = try? await s
                insights = (try? await i) ?? []
            }
            .refreshable {
                items = (try? await model.api.history(filter)) ?? []
                summary = try? await model.api.analytics()
            }
            .sheet(item: $selected) { tx in TransactionDetailView(tx: tx) }
        }
    }

    private var header: some View {
        ScreenTitle(title: L("Операції").s) {
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L("Пошук транзакцій…").s, text: $filter.search)
                .autocorrectionDisabled()
            if !filter.search.isEmpty {
                Button { filter.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.surface, in: .capsule)
        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
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
                                .font(.caption.weight(.semibold))
                                .frame(width: 42, height: 26)
                                .background(period == p ? Theme.ink : .clear, in: .rect(cornerRadius: 7, style: .continuous))
                                .foregroundStyle(period == p ? AnyShapeStyle(Theme.onInk) : AnyShapeStyle(.secondary))
                        }
                    }
                    .buttonStyle(.plain)
                }
                BigAmount(value: spent.reduce(0) { $0 + $1.amount }, size: 38)
                if byBucket.isEmpty {
                    Text(L("Витрат за цей час немає").s).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Chart(byBucket, id: \.day) { b in
                        BarMark(x: .value(L("Коли").s, b.day, unit: period.unit), y: .value(L("Сума").s, b.sum))
                            .foregroundStyle(b.day == byBucket.last?.day ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.ink.opacity(0.78)))
                            .cornerRadius(3)
                    }
                    .chartYAxis(.hidden)
                    .chartXScale(range: .plotDimension(padding: 14))
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
    static let palette: [Color] = [Theme.accent, .orange, .blue, .purple, .teal, .pink, .green, .gray]

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
                            Text("\(out.count)").font(.title2.weight(.bold)).monospacedDigit()
                            Text(L("видів").s).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(out.prefix(6).enumerated()), id: \.element.id) { i, t in
                            HStack(spacing: 8) {
                                Circle().fill(Self.palette[i % Self.palette.count]).frame(width: 9, height: 9)
                                Text(BankText.type(t.txType)).font(.subheadline).lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(Int((t.total / total * 100).rounded()))%")
                                    .font(.subheadline.weight(.semibold)).monospacedDigit()
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
                        let tints: [Color] = [.orange, .blue, .purple, .green, Theme.accent]
                        GuillocheBadge(symbol: marks[i % marks.count], tint: tints[i % tints.count], size: 36)
                        Text(ins.text).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                }
            }
        }
    }

    // MARK: Історія

    @ViewBuilder private var history: some View {
        if loaded && items.isEmpty {
            BrandEmpty(title: filter.search.isEmpty ? L("Операцій ще немає").s : L("Нічого не знайдено").s)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(L("Історія").s).font(.title3.weight(.bold))
                Text("\(items.count)").foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                Menu {
                    Picker(L("Сортування").s, selection: $sort) {
                        ForEach(Sort.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                } label: {
                    Label(sort.label, systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
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
            .buttonStyle(.plain)
    }
}
