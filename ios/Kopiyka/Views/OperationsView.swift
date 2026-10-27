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

    enum Sort: String, CaseIterable { case newest = "Нові", oldest = "Старі", amount = "Сума" }

    enum Period: String, CaseIterable {
        case week = "Т", month = "М", year = "Р"
        var title: String { switch self { case .week: "тиждень"; case .month: "місяць"; case .year: "рік" } }
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
                    SegmentBar(items: [(String?.none, "Усі"), (String?.some("in"), "Надходження"), (String?.some("out"), "Витрати")],
                               selection: $filter.direction)
                    HStack(spacing: 18) {
                        ForEach(Sort.allCases, id: \.self) { s in
                            Button(s.rawValue) { sort = s }
                                .font(.footnote.weight(sort == s ? .semibold : .regular))
                                .foregroundStyle(sort == s ? Theme.ink : .secondary)
                        }
                        Spacer()
                    }
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
        ScreenTitle(title: "Операції") {
            HStack(spacing: 8) {
                NavigationLink { StatementsView() } label: { RoundGlyph(symbol: "doc.text") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Виписки")
                NavigationLink { AnalyticsView() } label: { RoundGlyph(symbol: "chart.bar") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Аналітика")
            }
        }
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Пошук транзакцій…", text: $filter.search)
                .autocorrectionDisabled()
            if !filter.search.isEmpty {
                Button { filter.search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
    }

    // MARK: Витрати за період

    private var spending: some View {
        let byBucket = Dictionary(grouping: spent) { Calendar.current.dateInterval(of: period.unit, for: $0.date)?.start ?? $0.date }
            .map { (day: $0.key, sum: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.day < $1.day }
        return Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Витрати за \(period.title)").caption()
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(Period.allCases, id: \.self) { p in
                            Button(p.rawValue) { period = p }
                                .font(.caption.weight(.semibold))
                                .frame(width: 28, height: 24)
                                .background(period == p ? Theme.accent : .clear, in: .rect(cornerRadius: 7, style: .continuous))
                                .foregroundStyle(period == p ? Theme.onAccent : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                BigAmount(value: spent.reduce(0) { $0 + $1.amount }, size: 30)
                if byBucket.isEmpty {
                    Text("Витрат за цей час немає").font(.footnote).foregroundStyle(.secondary)
                } else {
                    Chart(byBucket, id: \.day) { b in
                        BarMark(x: .value("Коли", b.day, unit: period.unit), y: .value("Сума", b.sum))
                            .foregroundStyle(Theme.accent)
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel(format: period == .year
                                ? .dateTime.month(.abbreviated).locale(Locale(identifier: "uk_UA"))
                                : .dateTime.day().month(.twoDigits).locale(Locale(identifier: "uk_UA")))
                        }
                    }
                    .frame(height: 130)
                }
            }
            .padding(18)
        }
    }

    private func byType(_ s: API.Analytics) -> some View {
        let out = s.byType.filter { $0.direction == "out" }.sorted { $0.total > $1.total }
        let total = max(out.reduce(0) { $0 + $1.total }, 1)
        return VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Витрати за видами")
            Surface {
                ForEach(Array(out.enumerated()), id: \.element.id) { i, t in
                    if i > 0 { Rule() }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(BankText.type(t.txType))
                            Spacer()
                            Text(Format.money(t.total)).fontWeight(.semibold).monospacedDigit()
                            Text("\(Int(t.total / total * 100))%").font(.footnote).foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                        Meter(value: t.total / total)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }
        }
    }

    private var insightList: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Аналітика")
            Surface {
                ForEach(Array(insights.enumerated()), id: \.offset) { i, ins in
                    if i > 0 { Rule() }
                    Text(ins.text).font(.subheadline).padding(16)
                }
            }
        }
    }

    // MARK: Історія

    @ViewBuilder private var history: some View {
        if loaded && items.isEmpty {
            Text("Нічого не знайдено").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
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
                    Text(BankText.dayTitle(day.day)).font(.footnote.weight(.medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
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
        Button { selected = tx } label: { TransactionRow(tx: tx).contentShape(.rect) }
            .buttonStyle(.plain)
    }
}
