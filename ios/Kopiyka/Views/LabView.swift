import EdgeRouter
import SwiftUI

/// Лабораторія: стратегія для порівняння, параметри методу, живий контекст, графік відключень,
/// підсумки за журналом і експорт журналу для статті.
struct LabView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    static let taskTitles = ["fraud": "Перевірка переказу", "receipt": "Чек", "assistant": "Помічник"]

    var body: some View {
        NavigationStack {
            Form {
                strategy
                parameters
                now
                outages
                summary
                journal
            }
            .navigationTitle("Лабораторія")
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
            .toolbar {
                ToolbarItem {
                    ShareLink("Експорт журналу", item: model.router.telemetry.url)
                        .disabled(model.decisions.isEmpty)
                }
                ToolbarItem {
                    Button("Скинути навчене", systemImage: "arrow.counterclockwise") { confirmReset = true }
                }
            }
            .confirmationDialog("Стерти журнал і все, чого метод навчився?", isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button("Стерти", role: .destructive) { Task { await model.resetLearning() } }
            }
        }
    }

    private var strategy: some View {
        Section {
            Picker("Стратегія", selection: Binding(
                get: { model.snapshot.config.strategy },
                set: { s in Task { await model.configure { $0.config.strategy = s } } }
            )) {
                ForEach(Strategy.allCases, id: \.self) { Text($0.title) }
            }
        } footer: {
            Text("Чотири базові стратегії потрібні для порівняння з методом у роботі.")
        }
    }

    private var parameters: some View {
        Section("Параметри методу") {
            slider("Цільова частка помилок α", \.alpha, 0.01...0.3, "%.2f")
            slider("Компроміс V", \.lyapunovV, 0.1...10, "%.1f")
            slider("Бюджет енергії, Дж на задачу", \.energyBudgetJ, 0.1...5, "%.1f")
            slider("Вага якості", \.qualityWeight, 0...10, "%.1f")
        }
    }

    private func slider(_ title: String, _ key: WritableKeyPath<PolicyConfig, Double> & Sendable,
                        _ range: ClosedRange<Double>, _ format: String) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(title, value: String(format: format, model.snapshot.config[keyPath: key]))
                .monospacedDigit()
            Slider(value: Binding(
                get: { model.snapshot.config[keyPath: key] },
                set: { v in Task { await model.configure { $0.config[keyPath: key] = v } } }
            ), in: range)
        }
    }

    private var now: some View {
        let c = model.context
        let s = model.snapshot
        return Section("Зараз") {
            LabeledContent("Мережа", value: Self.network[c.network] ?? c.network.rawValue)
            LabeledContent("Заряд", value: c.batteryLevel.map { "\(Int($0 * 100))%\(c.isCharging ? ", заряджається" : "")" } ?? "невідомо")
            LabeledContent("Енергозбереження", value: c.lowPowerMode ? "увімкнено" : "вимкнено")
            LabeledContent("Нагрів", value: Self.thermal[c.thermal] ?? "")
            LabeledContent("Імовірність відключення", value: "\(Int(c.outageProbability * 100))%")
            LabeledContent("Перевитрата енергії Z", value: Format.joules(s.state.energyQueue))
            ForEach(Self.taskTitles.sorted(by: <), id: \.key) { id, title in
                LabeledContent("Поріг каскаду, \(title.lowercased())",
                               value: String(format: "%.2f", s.state.lambda(id)))
            }
            LabeledContent("Модель на телефоні", value: AssistantTask.deviceStatus)
        }
        .monospacedDigit()
    }

    private var outages: some View {
        Section {
            ForEach(model.snapshot.outages.intervals, id: \.start) { i in
                Text("\(i.start.formatted(date: .omitted, time: .shortened)) - \(i.end.formatted(date: .omitted, time: .shortened))")
                    .monospacedDigit()
            }
            Button("Відключення через 10 хвилин на 2 години") { addOutage(in: 600, hours: 2) }
            Button("Відключення зараз на годину") { addOutage(in: 0, hours: 1) }
            if !model.snapshot.outages.intervals.isEmpty {
                Button("Прибрати графік", role: .destructive) {
                    Task { await model.configure { $0.outages.intervals = [] } }
                }
            }
        } header: {
            Text("Графік відключень світла")
        } footer: {
            Text("Під час відключень мобільна мережа слабшає. Метод знає графік заздалегідь і переходить на телефон ще до того, як сервер почне не відповідати.")
        }
    }

    private func addOutage(in seconds: TimeInterval, hours: Double) {
        let i = DateInterval(start: .now.addingTimeInterval(seconds), duration: hours * 3600)
        Task { await model.configure { $0.outages.intervals.append(i) } }
    }

    private var summary: some View {
        Section("Підсумки") {
            if model.decisions.isEmpty {
                Text("Ще немає рішень. Перевірте переказ, чек або спитайте помічника.")
                    .foregroundStyle(.secondary)
            }
            ForEach(stats, id: \.title) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                    Text(row.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    private struct Row { let title: String; let detail: String }

    private var stats: [Row] {
        let groups = Dictionary(grouping: model.decisions) { "\($0.task)|\($0.placement.rawValue)" }
        return groups.keys.sorted().map { key in
            let rs = groups[key]!
            let first = rs[0]
            let n = Double(rs.count)
            let judged = rs.compactMap { model.feedback[$0.id] }
            var parts = ["запусків: \(rs.count)", "у середньому \(Format.ms(rs.map(\.latencyMs).reduce(0, +) / n))",
                         Format.joules(rs.map(\.energyJ).reduce(0, +) / n)]
            if !judged.isEmpty {
                parts.append("правильно \(judged.filter { $0 }.count) з \(judged.count)")
            }
            return Row(title: "\(Self.taskTitles[first.task] ?? first.task), \(first.placement.title.lowercased())",
                       detail: parts.joined(separator: ", "))
        }
    }

    private var journal: some View {
        Section("Останні рішення") {
            ForEach(model.decisions.prefix(30)) { r in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Self.taskTitles[r.task] ?? r.task): \(r.plan.title.lowercased())")
                    RoutedNote(record: r)
                    Text("\(r.strategy.title), \(r.date.formatted(date: .omitted, time: .standard))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    static let network: [Network: String] = [.offline: "немає", .wifi: "вайфай", .cellular: "мобільна",
                                             .wired: "дротова", .other: "інша"]
    static let thermal: [Thermal: String] = [.nominal: "норма", .fair: "теплий", .serious: "гарячий",
                                             .critical: "перегрітий"]
}
