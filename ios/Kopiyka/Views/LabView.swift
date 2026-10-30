import EdgeRouter
import SwiftUI

/// Лабораторія: стратегія для порівняння, параметри методу, живий контекст,
/// підсумки за журналом і експорт журналу для статті.
struct LabView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    static var taskTitles: [String: String] { ["fraud": L("Перевірка переказу").s, "receipt": L("Чек").s, "assistant": L("Помічник").s] }

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
            .navigationTitle(L("Лабораторія").s)
            .refreshable { await model.refresh() }
            .task { await model.refresh() }
            .toolbar {
                ToolbarItem {
                    ShareLink(L("Експорт журналу").s, item: model.router.telemetry.url)
                        .disabled(model.decisions.isEmpty)
                }
                ToolbarItem {
                    Button(L("Скинути навчене").s, systemImage: "arrow.counterclockwise") { confirmReset = true }
                }
            }
            .confirmationDialog(L("Стерти журнал і все, чого метод навчився?").s, isPresented: $confirmReset,
                                titleVisibility: .visible) {
                Button(L("Стерти").s, role: .destructive) { Task { await model.resetLearning() } }
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
                StatTile(value: "\(d.count)", title: L("рішень").s)
                StatTile(value: d.isEmpty ? "-" : "\(Int(Double(device) / n * 100))%", title: L("на телефоні").s)
                StatTile(value: d.isEmpty ? "-" : Format.ms(d.map(\.latencyMs).reduce(0, +) / n), title: L("середня затримка").s)
                StatTile(value: judged.isEmpty ? "-" : "\(Int(Double(judged.filter { $0 }.count) / Double(judged.count) * 100))%", title: L("правильних відповідей").s)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var strategy: some View {
        Section {
            Picker(L("Стратегія").s, selection: Binding(
                get: { model.snapshot.config.strategy },
                set: { s in Task { await model.configure { $0.config.strategy = s } } }
            )) {
                ForEach(Strategy.allCases, id: \.self) { Text($0.title) }
            }
        } footer: {
            Text(L("Чотири базові стратегії потрібні для порівняння з методом у роботі.").s)
        }
    }

    private var privacy: some View {
        @Bindable var model = model
        return Section {
            Toggle(L("Мовна модель на сервері").s, isOn: $model.cloudAIAllowed)
                .tint(Theme.ink.opacity(0.6))
        } footer: {
            Text(model.signedIn
                 ? L("Текст чека й питання помічнику йдуть на сервер лише без номерів карток, телефонів, пошти й ІПН.").s
                 : L("Сервер доступний після входу в навчальний банк.").s)
        }
    }

    private var parameters: some View {
        Section(L("Параметри методу").s) {
            slider(L("Цільова частка помилок α").s, \.alpha, 0.01...0.3, "%.2f")
            slider(L("Компроміс V").s, \.lyapunovV, 0.1...10, "%.1f")
            slider(L("Бюджет енергії, Дж на задачу").s, \.energyBudgetJ, 0.1...5, "%.1f")
            slider(L("Вага якості").s, \.qualityWeight, 0...10, "%.1f")
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
        return Section(L("Зараз").s) {
            LabeledContent(L("Мережа").s, value: Self.network[c.network] ?? c.network.rawValue)
            LabeledContent(L("Заряд").s, value: c.batteryLevel.map { "\(Int($0 * 100))%\(c.isCharging ? L(", заряджається").s : "")" } ?? L("невідомо").s)
            LabeledContent(L("Енергозбереження").s, value: c.lowPowerMode ? L("увімкнено").s : L("вимкнено").s)
            LabeledContent(L("Нагрів").s, value: Self.thermal[c.thermal] ?? "")
            LabeledContent(L("Перевитрата енергії Z").s, value: Format.joules(s.state.energyQueue))
            ForEach(Self.taskTitles.sorted(by: <), id: \.key) { id, title in
                LabeledContent(L("Поріг каскаду, \(title.lowercased())").s,
                               value: String(format: "%.2f", s.state.lambda(id)))
            }
            LabeledContent(L("Модель на телефоні").s, value: AssistantTask.deviceStatus)
        }
        .monospacedDigit()
    }

    private var summary: some View {
        Section(L("Підсумки").s) {
            if model.decisions.isEmpty {
                Text(L("Ще немає рішень. Перевірте переказ, чек або спитайте помічника.").s)
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
            var parts = [L("запусків: \(rs.count)").s, L("у середньому \(Format.ms(rs.map(\.latencyMs).reduce(0, +) / n))").s,
                         Format.joules(rs.map(\.energyJ).reduce(0, +) / n)]
            if !judged.isEmpty {
                parts.append(L("правильно \(judged.filter { $0 }.count) з \(judged.count)").s)
            }
            return Row(title: "\(Self.taskTitles[first.task] ?? first.task), \(first.placement.title.lowercased())",
                       detail: parts.joined(separator: ", "))
        }
    }

    private var journal: some View {
        Section(L("Останні рішення").s) {
            ForEach(model.decisions.prefix(30)) { r in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Self.taskTitles[r.task] ?? r.task): \(r.plan.title.lowercased())")
                    RoutedNote(record: r)
                    Text("\(r.strategy.title), \(r.date.formatted(Date.FormatStyle(date: .omitted, time: .standard).locale(Lang.current.locale)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    static var network: [Network: String] { [.offline: L("немає").s, .wifi: L("вайфай").s, .cellular: L("мобільна").s,
                                             .wired: L("дротова").s, .other: L("інша").s] }
    static var thermal: [Thermal: String] { [.nominal: L("норма").s, .fair: L("теплий").s, .serious: L("гарячий").s,
                                             .critical: L("перегрітий").s] }
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
