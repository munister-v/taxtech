import EdgeRouter
import SwiftUI

/// Живий режим мережі: той самий потік переказів, але з реального рахунку навчального банку.
/// Кожен переказ проходить маршрутизатор (телефон або сервер), потім повний антифрод банку.
/// Баланс, історія й відмови - справжні, автоплатежі виконує застосунок.
@MainActor @Observable
final class LiveTraffic {
    enum Kind { case passed, phoneBlock, serverBlock, failed, auto, topup }

    struct Entry: Identifiable {
        let id: Int
        let kind: Kind
        let text: String
        var detail: String?
        let tick: Int
    }

    struct Order: Codable, Identifiable, Equatable {
        var id = UUID()
        var to: String
        var amount: Double
        var every: Int
        var note: String
    }

    private struct Plan {
        let to: String
        let amount: Double
        let note: String
        let scheme: NetSim.Scheme?
        let auto: Bool
    }

    /// Схеми, які можна виконати з одного рахунку: решті потрібні зустрічні перекази від інших людей.
    static let schemes: [NetSim.Scheme] = [.structuring, .fanout, .drain, .bot]

    var running = false
    var account: String?
    var balance: Double?
    var tick = 0
    var feed: [Entry] = []
    var orders: [Order] = []

    var intensity = 1.0
    var fraudShare = 0.3
    var active = Set(LiveTraffic.schemes)

    private(set) var sent = 0
    private(set) var phoneBlocks = 0
    private(set) var serverBlocks = 0
    private(set) var passed = 0
    private(set) var falseBlocks = 0
    private(set) var leaked = 0.0
    private(set) var results: [NetSim.Scheme: NetSim.Outcome] = [:]
    private(set) var latencies: [String: [Double]] = [:]

    /// Карта: дванадцять місць навколо вашого рахунку, одержувачі займають їх по черзі.
    static let slotCount = 12
    private(set) var slots = [String?](repeating: nil, count: LiveTraffic.slotCount)
    private(set) var flows: [MapFlow] = []
    private var nextSlot = 0
    private var flowSeq = 0

    private var pool = (2...40).map { "KP-\(100_000 + $0)" }
    private var queued: [Plan] = []
    private var failures = 0
    private var blockStreak = 0
    private var seq = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: "liveOrders"), let o = try? JSONDecoder().decode([Order].self, from: data) { orders = o }
    }

    var recipients: [String] { pool }

    private func slot(_ to: String) -> Int {
        if let i = slots.firstIndex(of: to) { return i }
        let i = nextSlot % Self.slotCount
        nextSlot += 1
        slots[i] = to
        return i
    }

    private func emit(_ kind: MapFlow.Kind, to: String? = nil, fraud: Bool = false, stop: Double = 0.55) {
        flowSeq += 1
        let target = to.map { slot($0) + 1 } ?? 0
        flows.append(MapFlow(id: flowSeq, kind: kind, from: 0, to: target, fraud: fraud, stop: stop))
        if flows.count > 30 { flows.removeFirst(flows.count - 30) }
    }

    /// Запустити схему негайно: її продовження підуть у наступних кроках.
    func attack(_ s: NetSim.Scheme, _ model: AppModel) async {
        for p in fraud(s) { await execute(p, model) }
    }

    func saveOrders() {
        UserDefaults.standard.set(try? JSONEncoder().encode(orders), forKey: "liveOrders")
    }

    func addOrder(_ o: Order) { orders.append(o); saveOrders() }
    func removeOrder(_ id: UUID) { orders.removeAll { $0.id == id }; saveOrders() }

    func refresh(_ model: AppModel) async {
        guard let a = try? await model.api.account() else { return }
        account = a.accountNumber
        balance = a.balance
        pool.removeAll { $0 == a.accountNumber }
    }

    func topUp(_ model: AppModel, _ amount: Double = 10_000) async {
        do {
            let a = try await model.api.topUp(amount)
            balance = a.balance
            add(.topup, "+\(Format.short(amount))", nil)
            emit(.pulse)
        } catch {
            add(.failed, error.localizedDescription, nil)
        }
    }

    // MARK: Крок

    func step(_ model: AppModel) async {
        tick += 1
        var batch: [Plan] = queued
        queued = []
        for o in orders where tick % max(o.every, 1) == 0 {
            batch.append(Plan(to: o.to, amount: o.amount, note: o.note, scheme: nil, auto: true))
        }
        for _ in 0..<Int(intensity) {
            batch += Double.random(in: 0..<1) < fraudShare && !active.isEmpty ? fraud() : [honest()]
        }
        for p in batch {
            await execute(p, model)
        }
    }

    private func randomPeer(excluding: [String] = []) -> String {
        pool.filter { !excluding.contains($0) }.randomElement() ?? "KP-100002"
    }

    private func honest() -> Plan {
        let amount = exp(Double.random(in: log(20)...log(600))).rounded()
        let note = [L("Кава").s, L("Обід").s, L("Книжки").s, L("Подарунок").s, ""].randomElement() ?? ""
        return Plan(to: randomPeer(), amount: amount, note: note, scheme: nil, auto: false)
    }

    private func fraud() -> [Plan] {
        fraud(Self.schemes.filter { active.contains($0) }.randomElement() ?? .structuring)
    }

    private func fraud(_ scheme: NetSim.Scheme) -> [Plan] {
        let to = randomPeer()
        switch scheme {
        case .structuring:
            return (0..<3).map { _ in Plan(to: to, amount: Double(Int.random(in: 4_900...4_990)), note: "", scheme: scheme, auto: false) }
        case .fanout:
            var peers: [String] = []
            while peers.count < 4 { peers.append(randomPeer(excluding: peers)) }
            return peers.map { Plan(to: $0, amount: Double(Int.random(in: 300...900)), note: "", scheme: scheme, auto: false) }
        case .drain:
            return [Plan(to: to, amount: ((balance ?? 0) * 0.9).rounded(), note: L("терміново крипто").s, scheme: scheme, auto: false)]
        default:
            let amount = Double(Int.random(in: 150...450))
            for _ in 1...4 { queued.append(Plan(to: to, amount: amount, note: "", scheme: scheme, auto: false)) }
            return [Plan(to: to, amount: amount, note: "", scheme: scheme, auto: false)]
        }
    }

    // MARK: Виконання

    private func tally(_ p: Plan, stopped: Bool, phone: Bool) {
        if phone { phoneBlocks += 1 } else if stopped { serverBlocks += 1 }
        guard let scheme = p.scheme else {
            if stopped { falseBlocks += 1 } else { passed += 1 }
            return
        }
        var r = results[scheme, default: NetSim.Outcome()]
        if stopped { r.caught += 1 } else { r.missed += 1; r.leaked += p.amount; leaked += p.amount; passed += 1 }
        results[scheme] = r
    }

    private func line(_ p: Plan) -> String { "\(account ?? "·") → \(p.to.replacingOccurrences(of: "KP-", with: ""))  \(Format.short(p.amount))" }

    private func execute(_ p: Plan, _ model: AppModel) async {
        guard let have = balance else { await refresh(model); return }
        sent += 1
        guard have >= p.amount else {
            add(.failed, line(p), L("не вистачає коштів").s)
            return
        }
        let input = FraudTask.Input(amount: p.amount, balance: have, description: p.note, recipient: p.to)
        let routed: Routed<FraudTask.Verdict>
        do {
            routed = try await model.run(FraudTask.profile, input: input, executors: FraudTask.executors(api: model.api))
        } catch {
            fail(error.localizedDescription, p)
            return
        }
        let record = routed.record
        latencies[record.placement.title, default: []].append(record.latencyMs)
        let verdict = routed.output
        let where_ = "\(record.placement.title), \(Format.ms(record.latencyMs))"

        if verdict.level == "critical" {
            tally(p, stopped: true, phone: true)
            add(.phoneBlock, line(p), L("бал \(verdict.score)").s + " · " + where_)
            emit(.blocked, to: p.to, fraud: p.scheme != nil, stop: 0.3)
            await model.feedback(record.id, correct: true)
            return
        }
        do {
            let a = try await model.api.transfer(p.amount, to: p.to, description: p.note)
            balance = a.balance
            failures = 0
            blockStreak = 0
            tally(p, stopped: false, phone: false)
            add(p.auto ? .auto : .passed, line(p), (p.auto ? p.note + " · " : "") + L("бал \(verdict.score)").s + " · " + where_)
            emit(p.auto ? .auto : .ok, to: p.to, fraud: p.scheme != nil)
            await model.feedback(record.id, correct: true)
        } catch {
            let text = error.localizedDescription
            if text.contains("заблоковано") {
                tally(p, stopped: true, phone: false)
                add(.serverBlock, line(p), text)
                emit(.blocked, to: p.to, fraud: p.scheme != nil, stop: 0.8)
                await model.feedback(record.id, correct: false)
                blockStreak += 1
                if blockStreak >= 6 {
                    // банк уже не пропускає нічого: історія блокувань діє на рахунок, далі потік лише засмічує стрічку
                    running = false
                    blockStreak = 0
                    add(.failed, L("Банк блокує всі перекази: потік зупинено").s, L("Історія блокувань діє на рахунок кілька днів.").s)
                }
            } else {
                if text.contains("отримувача не знайдено") { pool.removeAll { $0 == p.to } }
                fail(text, p)
            }
        }
    }

    private func fail(_ text: String, _ p: Plan) {
        failures += 1
        add(.failed, line(p), text)
        if failures >= 5 { running = false; failures = 0 }
    }

    private func add(_ kind: Kind, _ text: String, _ detail: String?) {
        seq += 1
        feed.insert(Entry(id: seq, kind: kind, text: text, detail: detail, tick: tick), at: 0)
        if feed.count > 40 { feed.removeLast() }
    }
}

struct LiveNetworkLab: View {
    @Environment(AppModel.self) private var model
    @State private var live = LiveTraffic()
    @State private var newTo = ""
    @State private var newAmount = 200.0
    @State private var newEvery = 4
    @State private var topping = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.signedIn {
                hero
                controls
                schemes
                orders
                quality
                feed
            } else {
                gate
            }
        }
        .animation(.snappy, value: live.tick)
        .onChange(of: live.flows.last?.id ?? 0) { _, _ in
            if let f = live.flows.last, f.kind == .blocked {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
            }
        }
        .task { await live.refresh(model) }
        .task(id: live.running) {
            while live.running && !Task.isCancelled {
                await live.step(model)
                try? await Task.sleep(for: .milliseconds(2000))
            }
        }
        .onDisappear { live.running = false }
    }

    private var gate: some View {
        LabPanel(title: L("Живий режим").s) {
            Text(L("Потік іде з вашого рахунку в навчальному банку: справжні перекази, баланс, антифрод сервера. Для цього потрібен вхід.").s)
                .font(.subheadline).foregroundStyle(.secondary)
            Button(L("Увійти").s) { model.jumpTab = .overview }.buttonStyle(InkButton())
        }
    }

    // MARK: Рахунок

    private var hero: some View {
        LabHero(ok: live.serverBlocksShare < 0.5) {
            HeroCaption(live.account.map { L("Рахунок \($0)").s } ?? L("Рахунок").s)
            Text(live.balance.map(Format.short) ?? "-").font(Theme.balance(36)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1).padding(.top, 2)
            NetworkMap(nodes: mapNodes, flows: live.flows, aspect: 0.9).padding(.top, 8)
            HStack(spacing: 10) {
                Button(live.running ? L("Пауза").s : L("Запустити").s) { live.running.toggle() }.buttonStyle(InkButton())
                Button(topping ? L("Поповнюємо…").s : L("Поповнити").s) {
                    topping = true
                    Task { await live.topUp(model); topping = false }
                }
                .buttonStyle(LineButton()).disabled(topping)
            }
            .padding(.top, 12)
            attackChips(LiveTraffic.schemes) { s in
                Task { await live.attack(s, model) }
                live.running = true
            }
            .padding(.top, 10)
            HStack(spacing: 22) {
                Stat(value: "\(live.sent)", label: L("Переказів").s)
                Stat(value: "\(live.phoneBlocks)", label: L("Зупинив телефон").s)
                Stat(value: "\(live.serverBlocks)", label: L("Зупинив банк").s)
            }
            .padding(.top, 14)
        }
    }

    private var mapNodes: [MapNode] {
        var out = [MapNode(id: 0, pos: CGPoint(x: 0.5, y: 0.5), label: "", role: .you)]
        for i in 0..<LiveTraffic.slotCount {
            let ang = (-90 + Double(i) * 360 / Double(LiveTraffic.slotCount)) * .pi / 180
            out.append(MapNode(id: i + 1, pos: CGPoint(x: 0.5 + 0.38 * cos(ang), y: 0.5 + 0.36 * sin(ang)),
                               label: live.slots[i].map { String($0.suffix(3)) } ?? "", weight: live.slots[i] == nil ? 0 : 0.5, parent: 0))
        }
        return out
    }

    private var controls: some View {
        LabPanel(title: L("Живий потік").s) {
            LabSlider(title: L("Переказів за крок").s, value: "\(Int(live.intensity))",
                      x: Binding(get: { live.intensity }, set: { live.intensity = $0.rounded() }), range: 1...4)
            LabSlider(title: L("Частка шахрайства").s, value: "\(Int(live.fraudShare * 100))%",
                      x: Binding(get: { live.fraudShare }, set: { live.fraudShare = ($0 * 20).rounded() / 20 }), range: 0...0.6)
            Text(L("Це справжні перекази на рахунки пісочниці. Блокування банку лишаються в історії рахунку, і сервер суворіше дивиться на нього кілька днів.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var schemes: some View {
        LabPanel(title: L("Схеми шахрайства").s) {
            ForEach(LiveTraffic.schemes, id: \.self) { s in
                let on = live.active.contains(s)
                let r = live.results[s] ?? NetSim.Outcome()
                Button {
                    if on { live.active.remove(s) } else { live.active.insert(s) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.accent : Color.secondary)
                        Text(s.title).font(.subheadline.weight(.medium)).foregroundStyle(on ? Color.primary : Color.secondary)
                        Spacer(minLength: 8)
                        Text(r.total == 0 ? "-" : L("зупинено \(r.caught) з \(r.total)").s)
                            .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Text(L("З одного рахунку можна зробити лише схеми, де всі кроки ваші.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Автоплатежі

    private var orders: some View {
        LabPanel(title: L("Автоплатежі").s) {
            if live.orders.isEmpty { Text(L("Ще немає").s).foregroundStyle(.secondary) }
            ForEach(live.orders) { o in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(o.to) · \(Format.short(o.amount))").font(.subheadline.weight(.medium)).monospacedDigit()
                        Text(L("кожні \(o.every) кроків").s + (o.note.isEmpty ? "" : " · " + o.note)).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { live.removeOrder(o.id) } label: { Image(systemName: "trash").foregroundStyle(.secondary) }.buttonStyle(.plain)
                }
            }
            Rule()
            Menu {
                ForEach(live.recipients.prefix(12), id: \.self) { r in Button(r) { newTo = r } }
            } label: {
                HStack {
                    Text(L("Одержувач").s).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(newTo.isEmpty ? L("Обрати").s : newTo).font(.subheadline.weight(.medium))
                }
            }
            LabSlider(title: L("Сума").s, value: Format.short(newAmount),
                      x: Binding(get: { newAmount }, set: { newAmount = ($0 / 50).rounded() * 50 }), range: 50...1000)
            SegmentBar(items: [(2, "2"), (4, "4"), (8, "8"), (12, "12")], selection: $newEvery)
            Button(L("Додати автоплатіж").s) {
                live.addOrder(.init(to: newTo, amount: newAmount, every: newEvery, note: L("Підписка").s))
            }
            .buttonStyle(LineButton()).disabled(newTo.isEmpty)
            Text(L("Автоплатежі виконує застосунок кожні кілька кроків: сервер банку регулярні платежі сам не запускає.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Якість

    private var quality: some View {
        LabPanel(title: L("Хто зупинив").s) {
            row(L("Пройшло").s, "\(live.passed)")
            row(L("Шахрайство пройшло").s, Format.short(live.leaked))
            row(L("Чесні зупинені").s, "\(live.falseBlocks)")
            ForEach(live.latencies.keys.sorted(), id: \.self) { k in
                let v = live.latencies[k] ?? []
                row(L("Перевірка: \(k)").s, "\(v.count) · " + Format.ms(v.reduce(0, +) / Double(max(v.count, 1))))
            }
            Text(L("Телефон зупиняє лише критичні перекази за Layer 1, повний антифрод банку бачить історію й граф.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
        }
    }

    // MARK: Стрічка

    private var feed: some View {
        LabPanel(title: L("Стрічка").s) {
            if live.feed.isEmpty { Text(L("Ще немає").s).foregroundStyle(.secondary) }
            ForEach(live.feed.prefix(14)) { e in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol(e.kind)).font(.caption).foregroundStyle(tint(e.kind)).frame(width: 16).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.text).font(.system(.footnote, design: .monospaced)).foregroundStyle(e.kind == .passed ? Color.primary : tint(e.kind))
                        if let d = e.detail { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 4)
                    Text("\(e.tick)").font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                }
            }
        }
    }

    private func symbol(_ k: LiveTraffic.Kind) -> String {
        switch k {
        case .passed: "checkmark"
        case .auto: "repeat"
        case .phoneBlock: "iphone"
        case .serverBlock: "hand.raised.fill"
        case .failed: "xmark"
        case .topup: "plus"
        }
    }

    private func tint(_ k: LiveTraffic.Kind) -> Color {
        switch k {
        case .phoneBlock, .serverBlock, .failed: Theme.alert
        case .auto, .topup: Theme.accent
        case .passed: Color.secondary
        }
    }
}

extension LiveTraffic {
    /// Частка переказів, зупинених банком: коли телефон пропускає забагато, банку доводиться брати на себе більше.
    var serverBlocksShare: Double { sent == 0 ? 0 : Double(serverBlocks) / Double(sent) }
}
