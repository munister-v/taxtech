import EdgeRouter
import SwiftUI

/// Лабораторія: стратегія для порівняння, параметри методу, живий контекст,
/// підсумки за журналом і експорт журналу для статті.
struct LabView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    static let taskTitles = ["fraud": "Перевірка переказу", "receipt": "Чек", "assistant": "Помічник"]

    var body: some View {
        NavigationStack {
            LabForm {
                header
                tiles
                strategy
                privacy
                parameters
                now
                summary
                journal
            }
            .labForm()
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

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                MarkView(height: 34)
                Text(Brand.name).font(.system(size: 30, weight: .semibold)).tracking(-0.5)
                Text(Brand.lab).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    /// Головні цифри журналу - плоскими плитками.
    private var tiles: some View {
        let d = model.decisions
        let n = Double(max(d.count, 1))
        let device = d.filter { $0.placement == .device }.count
        let judged = d.compactMap { model.feedback[$0.id] }
        return Section {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                StatTile(value: "\(d.count)", title: "рішень")
                StatTile(value: d.isEmpty ? "-" : "\(Int(Double(device) / n * 100))%", title: "на телефоні")
                StatTile(value: d.isEmpty ? "-" : Format.ms(d.map(\.latencyMs).reduce(0, +) / n), title: "середня затримка")
                StatTile(value: judged.isEmpty ? "-" : "\(Int(Double(judged.filter { $0 }.count) / Double(judged.count) * 100))%", title: "правильних відповідей")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
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

    private var privacy: some View {
        @Bindable var model = model
        return Section {
            Toggle("Мовна модель на сервері", isOn: $model.cloudAIAllowed)
                .tint(Theme.ink.opacity(0.6))
        } footer: {
            Text(model.signedIn
                 ? "Текст чека й питання помічнику йдуть на сервер лише без номерів карток, телефонів, пошти й ІПН."
                 : "Сервер доступний після входу в навчальний банк.")
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
            LabeledContent("Перевитрата енергії Z", value: Format.joules(s.state.energyQueue))
            ForEach(Self.taskTitles.sorted(by: <), id: \.key) { id, title in
                LabeledContent("Поріг каскаду, \(title.lowercased())",
                               value: String(format: "%.2f", s.state.lambda(id)))
            }
            LabeledContent("Модель на телефоні", value: AssistantTask.deviceStatus)
        }
        .monospacedDigit()
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

struct StatTile: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
    }
}
