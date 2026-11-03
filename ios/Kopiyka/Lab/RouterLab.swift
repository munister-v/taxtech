import EdgeRouter
import SwiftUI

/// Дослід 1: політика EdgeRouter на повзунках. Те саме `Policy.decide`, що вирішує в застосунку,
/// але з вигаданим станом пристрою. Карта показує, як рішення змінюється з чергою енергії й відключеннями.
struct RouterLab: View {
    @State private var task = Job.assistant
    @State private var network = Network.wifi
    @State private var battery = 0.6
    @State private var lowPower = false
    @State private var thermal = Thermal.nominal
    @State private var outage = 0.0
    @State private var queue = 0.0
    @State private var strategy = Strategy.adaptive

    enum Job: String, CaseIterable, Identifiable {
        case fraud, receipt, assistant
        var id: String { rawValue }
        var title: String {
            switch self {
            case .fraud: L("Переказ").s
            case .receipt: L("Чек").s
            case .assistant: L("Помічник").s
            }
        }
        var profile: TaskProfile {
            switch self {
            case .fraud: FraudTask.profile
            case .receipt: ReceiptTask.profile
            case .assistant: AssistantTask.profile
            }
        }
    }

    private var context: DeviceContext {
        DeviceContext(network: network, isConstrained: lowPower, batteryLevel: battery, lowPowerMode: lowPower,
                      thermal: thermal, outageProbability: outage)
    }

    private func decide(queue z: Double, outage p: Double) -> Decision? {
        var cfg = PolicyConfig()
        cfg.strategy = strategy
        var state = PolicyState()
        state.energyQueue = z
        var ctx = context
        ctx.outageProbability = p
        return try? Policy.decide(task.profile, context: ctx, estimators: Estimators(), energy: EnergyModel(),
                                  config: cfg, state: state)
    }

    var body: some View {
        let d = decide(queue: queue, outage: outage)
        VStack(alignment: .leading, spacing: 16) {
            if let d {
                result(d)
                map
                controls
                candidates(d)
            } else {
                controls
                LabPanel { Text(L("Для цих умов немає дозволеного виконавця").s).foregroundStyle(.secondary) }
            }
        }
    }

    // MARK: Керування

    private var controls: some View {
        LabPanel(title: L("Умови").s) {
            Picker(L("Задача").s, selection: $task) { ForEach(Job.allCases) { Text($0.title).tag($0) } }
                .pickerStyle(.segmented)
            Picker(L("Мережа").s, selection: $network) {
                Text(L("Вайфай").s).tag(Network.wifi)
                Text(L("Мобільна").s).tag(Network.cellular)
                Text(L("Немає").s).tag(Network.offline)
            }
            .pickerStyle(.segmented)
            LabSlider(title: L("Заряд").s, value: "\(Int(battery * 100))%", x: $battery, range: 0...1)
            Toggle(L("Енергозбереження").s, isOn: $lowPower).tint(Theme.accent)
            Picker(L("Нагрів").s, selection: $thermal) {
                Text(L("Норма").s).tag(Thermal.nominal)
                Text(L("Теплий").s).tag(Thermal.fair)
                Text(L("Гарячий").s).tag(Thermal.serious)
            }
            .pickerStyle(.segmented)
            LabSlider(title: L("Імовірність відключення світла").s, value: "\(Int(outage * 100))%", x: $outage, range: 0...0.4)
            LabSlider(title: L("Перевитрата енергії Z").s, value: Format.joules(queue), x: $queue, range: 0...1.2)
            Picker(L("Стратегія").s, selection: $strategy) {
                ForEach(Strategy.allCases, id: \.self) { Text(Translator.text($0.title, [])).tag($0) }
            }
            .tint(Theme.accent)
        }
    }

    // MARK: Результат

    private func result(_ d: Decision) -> some View {
        HeroPanel(yellow: true) {
            HeroCaption(L("Рішення").s)
            Text(Translator.text(d.plan.title, []))
                .font(.system(size: 26, weight: .semibold)).tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            Text(Translator.text(d.reason, [])).font(.subheadline).foregroundStyle(Theme.onAccent.opacity(0.75)).padding(.top, 6)
        }
        .animation(.snappy, value: d.plan)
    }

    private func candidates(_ d: Decision) -> some View {
        LabPanel(title: L("Варіанти").s) {
            let best = d.candidates.map(\.objective).min() ?? 0
            ForEach(d.candidates.sorted { $0.objective < $1.objective }, id: \.plan) { c in
                let chosen = c.plan == d.plan
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(Translator.text(c.plan.title, [])).font(.subheadline.weight(chosen ? .semibold : .regular))
                        Spacer()
                        if chosen { Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Theme.accent) }
                    }
                    Text("\(Format.ms(c.latencyMs)) · \(Format.joules(c.energyJ)) · \(Int((c.quality * 100).rounded()))%")
                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                    Text(L("ціль \(String(format: "%.2f", c.objective)), +\(String(format: "%.2f", c.objective - best)) до найкращого").s)
                        .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                }
            }
        }
    }

    // MARK: Карта рішень

    private static let steps = 14
    private static let maxQueue = 1.2
    private static let maxOutage = 0.4

    private enum Kind { case device, cloud, cascade }

    private func kind(_ z: Double, _ p: Double) -> Kind? {
        guard let plan = decide(queue: z, outage: p)?.plan else { return nil }
        switch plan {
        case .run(.device): return .device
        case .run: return .cloud
        case .cascade: return .cascade
        }
    }

    private func color(_ k: Kind?) -> Color {
        switch k {
        case .device: Theme.accent
        case .cloud: Color.white.opacity(0.85)
        case .cascade: Color.white.opacity(0.28)
        case nil: Color.clear
        }
    }

    private var map: some View {
        LabPanel(title: L("Карта рішень").s) {
            let n = Self.steps
            // 14×14 викликів політики; перераховується під рухом повзунків
            let grid = (0..<n).map { j in
                (0..<n).map { i in kind(Self.maxQueue * Double(i) / Double(n - 1), Self.maxOutage * Double(j) / Double(n - 1)) }
            }
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, size in
                        let cw = size.width / CGFloat(n), ch = size.height / CGFloat(n)
                        for j in 0..<n {
                            for i in 0..<n {
                                // p_out росте вгору
                                let rect = CGRect(x: CGFloat(i) * cw, y: size.height - CGFloat(j + 1) * ch, width: cw + 0.5, height: ch + 0.5)
                                ctx.fill(Path(rect), with: .color(color(grid[j][i])))
                            }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 10, style: .continuous))
                    Circle().strokeBorder(Theme.onAccent, lineWidth: 2)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .frame(width: 16, height: 16)
                        .offset(x: w * queue / Self.maxQueue - 8, y: h * (1 - outage / Self.maxOutage) - 8)
                }
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    queue = min(Self.maxQueue, max(0, Self.maxQueue * v.location.x / w))
                    outage = min(Self.maxOutage, max(0, Self.maxOutage * (1 - v.location.y / h)))
                })
            }
            .aspectRatio(1.35, contentMode: .fit)
            HStack {
                Text(L("Z → \(Format.joules(Self.maxQueue))").s)
                Spacer()
                Text(L("↑ відключення \(Int(Self.maxOutage * 100))%").s)
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            HStack(spacing: 14) {
                legend(.device, L("Телефон").s)
                legend(.cloud, L("Сервер").s)
                legend(.cascade, L("Каскад").s)
            }
            .font(.footnote)
        }
    }

    private func legend(_ k: Kind, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color(k)).frame(width: 12, height: 12)
            Text(title).foregroundStyle(.secondary)
        }
    }
}
