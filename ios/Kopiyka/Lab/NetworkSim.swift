import FraudLite
import Foundation

/// Модель мережі переказів для досліду: три банки по чотири рахунки, потік переказів між людьми,
/// автоплатежі, міжбанківський кліринг і бани. Кожен переказ проходить Layer 1 (`FraudLite`)
/// і, якщо ввімкнено, шар історії. Про кожен переказ відомо, шахрайський він чи ні, тому видно
/// помилки обох видів: пропущене шахрайство й заблоковані чесні перекази.
struct NetSim {
    static let banks = ["Nord", "Centro", "Sud"]
    static let perBank = 4
    static var accountCount: Int { banks.count * perBank }
    static let opening = 20_000.0
    static let settleEvery = 8
    /// Бан діє двадцять кроків, потім рахунок розблоковується після перегляду.
    static let banTerm = 20

    /// Схеми шахрайства, з яких складається потік.
    enum Scheme: String, CaseIterable, Hashable {
        case structuring, fanout, mule, drain, pingpong, carousel, bot

        var title: String {
            switch self {
            case .structuring: L("Дроблення під поріг").s
            case .fanout: L("Розсилка багатьом").s
            case .mule: L("Транзитний рахунок").s
            case .drain: L("Весь залишок").s
            case .pingpong: L("Туди й назад").s
            case .carousel: L("Карусель").s
            case .bot: L("Автоматичні перекази").s
            }
        }
    }

    /// Подія для карти: що летить між рахунками й чим закінчилось.
    enum FlowKind { case ok, auto, clearing, blocked, ban, settle }

    struct Flow: Identifiable {
        let id: Int
        let from: Int
        let to: Int
        let kind: FlowKind
        let fraud: Bool
    }

    struct Outcome {
        var caught = 0
        var missed = 0
        var leaked = 0.0
        var total: Int { caught + missed }
    }

    struct Params: Equatable {
        var schemes = Set(Scheme.allCases)
        var intensity = 2.0
        var fraudShare = 0.2
        var threshold = 55.0
        var history = true
        var autopay = true
    }

    enum Kind { case ok, clearing, auto, blocked, banned, rejected, settle }

    struct Event: Identifiable {
        let id: Int
        let tick: Int
        let kind: Kind
        let text: String
        var detail: String?
    }

    struct Account: Identifiable {
        let id: String
        let bank: Int
        var balance = NetSim.opening
        /// Гроші в дорозі: переказ з іншого банку, який ще чекає на кліринг.
        var pending = 0.0
        var banned = false
        var bannedAt = 0
        var strikes = 0
        var fraudSent = 0
    }

    struct Settlement {
        let gross: Int
        let net: Int
        let grossVolume: Double
        let netVolume: Double
    }

    private struct Move { let tick: Int; let peer: Int; let amount: Double }
    private struct Order { let from: Int; let to: Int; let amount: Double; let every: Int; let offset: Int; let note: String }
    private struct Transfer {
        let from: Int
        let to: Int
        let amount: Double
        let note: String
        var scheme: Scheme?
        var auto = false
        var fraud: Bool { scheme != nil }
    }
    private struct Scheduled { let due: Int; let transfer: Transfer }
    private struct Edge { let tick: Int; let from: Int; let to: Int }
    private struct Clearing { let fromBank: Int; let toBank: Int; let to: Int; let amount: Double }

    private(set) var tick = 0
    private(set) var accounts: [Account]
    private(set) var events: [Event] = []
    private(set) var settlement: Settlement?
    /// Події останнього кроку: карта малює їх як вогники між рахунками.
    private(set) var flows: [Flow] = []
    private var flowSeq = 0

    private(set) var total = 0
    private(set) var autoDone = 0
    private(set) var autoFailed = 0
    /// Матриця помилок: заблоковане шахрайство, заблокований чесний, пропущене шахрайство, пропущений чесний.
    private(set) var caught = 0
    private(set) var falseBlocks = 0
    private(set) var missed = 0
    private(set) var clean = 0
    private(set) var leaked = 0.0
    private(set) var bansRight = 0
    private(set) var bansWrong = 0
    private(set) var results: [Scheme: Outcome] = [:]

    private var outs: [[Move]]
    private var ins: [[Move]]
    private var clearing: [Clearing] = []
    private var scheduled: [Scheduled] = []
    private var edges: [Edge] = []
    private var orders: [Order] = []
    private var eventSeq = 0

    init() {
        let n = Self.banks.count * Self.perBank
        accounts = (0..<n).map { Account(id: "\(Self.banks[$0 / Self.perBank].prefix(1))\($0 % Self.perBank + 1)", bank: $0 / Self.perBank) }
        outs = Array(repeating: [], count: n)
        ins = Array(repeating: [], count: n)
        orders = [
            Order(from: 0, to: 9, amount: 250, every: 6, offset: 2, note: L("Оренда").s),
            Order(from: 4, to: 2, amount: 120, every: 10, offset: 5, note: L("Підписка").s),
            Order(from: 10, to: 5, amount: 60, every: 8, offset: 3, note: L("Підписка").s),
            Order(from: 7, to: 1, amount: 400, every: 12, offset: 7, note: L("Оренда").s),
        ]
    }

    /// Усі гроші мережі: на рахунках і в кліринзі. Не змінюється, поки не вмішається помилка.
    var money: Double { accounts.reduce(0) { $0 + $1.balance } + clearing.reduce(0) { $0 + $1.amount } }
    var expectedMoney: Double { Self.opening * Double(accounts.count) }
    var inClearing: Double { clearing.reduce(0) { $0 + $1.amount } }
    var clearingCount: Int { clearing.count }
    var untilSettlement: Int { Self.settleEvery - tick % Self.settleEvery }
    var bannedCount: Int { accounts.filter(\.banned).count }
    var precision: Double? { caught + falseBlocks > 0 ? Double(caught) / Double(caught + falseBlocks) : nil }
    var recall: Double? { caught + missed > 0 ? Double(caught) / Double(caught + missed) : nil }

    func name(_ i: Int) -> String { accounts[i].id }

    mutating func unban(_ i: Int) {
        accounts[i].banned = false
        accounts[i].strikes = 0
    }

    // MARK: Крок

    mutating func step(_ p: Params) {
        tick += 1
        flows = []
        for i in accounts.indices where accounts[i].banned && tick - accounts[i].bannedAt >= Self.banTerm {
            unban(i)
            record(.ok, L("Бан знято: рахунок \(name(i))").s)
        }
        var batch: [Transfer] = []
        if p.autopay {
            for o in orders where tick % o.every == o.offset {
                batch.append(Transfer(from: o.from, to: o.to, amount: o.amount, note: o.note, scheme: nil, auto: true))
            }
        }
        batch += scheduled.filter { $0.due <= tick }.map(\.transfer)
        scheduled.removeAll { $0.due <= tick }
        for _ in 0..<Int(p.intensity) {
            batch += Double.random(in: 0..<1) < p.fraudShare && !p.schemes.isEmpty ? fraud(p.schemes) : [honest()]
        }
        for t in batch { process(t, p) }
        if tick % Self.settleEvery == 0 { settle() }
        for i in outs.indices {
            outs[i].removeAll { tick - $0.tick > 12 }
            ins[i].removeAll { tick - $0.tick > 12 }
        }
        edges.removeAll { tick - $0.tick > 8 }
    }

    /// Запустити схему негайно: наступні кроки схеми підуть у звичайному потоці.
    mutating func attack(_ s: Scheme, _ p: Params) {
        flows = []
        for t in fraud([s]) { process(t, p) }
    }

    // MARK: Потік

    private func active() -> [Int] { accounts.indices.filter { !accounts[$0].banned } }

    private func pair() -> (Int, Int) {
        let pool = active()
        let a = pool.randomElement() ?? 0
        var b = accounts.indices.randomElement() ?? 1
        while b == a { b = accounts.indices.randomElement() ?? 1 }
        return (a, b)
    }

    private func honest() -> Transfer {
        let (a, b) = pair()
        if Int.random(in: 0..<20) == 0 {
            return Transfer(from: a, to: b, amount: 3_000, note: L("Оренда").s)
        }
        let amount = exp(Double.random(in: log(20)...log(600))).rounded()
        let note = [L("Кава").s, L("Обід").s, L("Книжки").s, L("Подарунок").s, ""].randomElement() ?? ""
        return Transfer(from: a, to: b, amount: amount, note: note)
    }

    /// Одна схема з обраних: кожна лишає свій слід в історії рахунку.
    private mutating func fraud(_ schemes: Set<Scheme>) -> [Transfer] {
        let (a, b) = pair()
        func other(_ ex: [Int]) -> Int {
            var z = accounts.indices.randomElement() ?? 0
            while ex.contains(z) { z = accounts.indices.randomElement() ?? 0 }
            return z
        }
        func make(_ f: Int, _ t: Int, _ amount: Double, _ s: Scheme, note: String = "") -> Transfer {
            Transfer(from: f, to: t, amount: amount.rounded(), note: note, scheme: s)
        }
        let scheme = Scheme.allCases.filter { schemes.contains($0) }.randomElement() ?? .structuring
        switch scheme {
        case .structuring:
            return (0..<3).map { _ in make(a, b, Double(Int.random(in: 4_900...4_990)), scheme) }
        case .fanout:
            var peers: [Int] = []
            while peers.count < 4 {
                let c = other([a] + peers)
                peers.append(c)
            }
            return peers.map { make(a, $0, Double(Int.random(in: 300...900)), scheme) }
        case .mule:
            let amount = Double(Int.random(in: 1_500...3_000))
            scheduled.append(Scheduled(due: tick + 1, transfer: make(b, other([a, b]), amount * 0.95, scheme)))
            return [make(a, b, amount, scheme)]
        case .drain:
            return [make(a, b, accounts[a].balance * 0.9, scheme, note: L("терміново крипто").s)]
        case .pingpong:
            let amount = Double(Int.random(in: 400...900))
            for k in 1...4 {
                let from = k % 2 == 1 ? b : a
                scheduled.append(Scheduled(due: tick + k, transfer: make(from, from == a ? b : a, amount * (1 - 0.05 * Double(k)), scheme)))
            }
            return [make(a, b, amount, scheme)]
        case .carousel:
            let c = other([a, b])
            let amount = Double(Int.random(in: 1_000...2_500))
            scheduled.append(Scheduled(due: tick + 1, transfer: make(b, c, amount * 0.97, scheme)))
            scheduled.append(Scheduled(due: tick + 2, transfer: make(c, a, amount * 0.94, scheme)))
            return [make(a, b, amount, scheme)]
        case .bot:
            let amount = Double(Int.random(in: 150...450))
            for k in 1...5 { scheduled.append(Scheduled(due: tick + k, transfer: make(a, b, amount, scheme))) }
            return [make(a, b, amount, scheme)]
        }
    }

    // MARK: Перевірка

    /// Шар історії: те, чого не видно в одному переказі.
    private func historyScore(_ t: Transfer) -> (points: Int, flags: [String]) {
        var points = 0
        var flags: [String] = []
        let recent = outs[t.from].filter { tick - $0.tick <= 2 }
        if recent.count >= 2 { points += 30; flags.append("velocity_burst") }
        if Set(recent.map(\.peer)).union([t.to]).count >= 4 { points += 40; flags.append("transfer_fanout") }
        let big = outs[t.from].filter { tick - $0.tick <= 10 && $0.amount >= 4_500 }.count
        if t.amount >= 4_500 && big >= 2 { points += 50; flags.append("smurfing") }
        let received = ins[t.from].filter { tick - $0.tick <= 2 }.reduce(0) { $0 + $1.amount }
        if received >= 0.8 * t.amount && outs[t.from].isEmpty { points += 55; flags.append("pass_through") }
        let backAndForth = ins[t.from].contains { $0.peer == t.to && tick - $0.tick <= 8 } && outs[t.from].contains { $0.peer == t.to }
        if backAndForth { points += 45; flags.append("transfer_pingpong") }
        let cycle = edges.contains { e in
            e.from == t.to && edges.contains { $0.from == e.to && $0.to == t.from }
        }
        if cycle { points += 55; flags.append("carousel") }
        let same = outs[t.from].filter { tick - $0.tick <= 8 && $0.amount == t.amount }.count
        if same >= 3 { points += 45; flags.append("behavioral_entropy_amounts") }
        return (points, flags)
    }

    private mutating func flow(_ kind: FlowKind, _ from: Int, _ to: Int, fraud: Bool = false) {
        flowSeq += 1
        flows.append(Flow(id: flowSeq, from: from, to: to, kind: kind, fraud: fraud))
    }

    private mutating func record(_ kind: Kind, _ text: String, _ detail: String? = nil) {
        eventSeq += 1
        events.insert(Event(id: eventSeq, tick: tick, kind: kind, text: text, detail: detail), at: 0)
        if events.count > 40 { events.removeLast() }
    }

    private mutating func tally(_ t: Transfer, stopped: Bool) {
        guard let scheme = t.scheme else {
            if stopped { falseBlocks += 1 } else { clean += 1 }
            return
        }
        var r = results[scheme, default: Outcome()]
        if stopped { caught += 1; r.caught += 1 } else { missed += 1; leaked += t.amount; r.missed += 1; r.leaked += t.amount }
        results[scheme] = r
    }

    private func line(_ t: Transfer) -> String { "\(name(t.from)) → \(name(t.to))  \(Format.short(t.amount))" }

    private mutating func process(_ t: Transfer, _ p: Params) {
        total += 1
        if t.fraud { accounts[t.from].fraudSent += 1 }
        if accounts[t.from].banned || accounts[t.to].banned {
            let who = accounts[t.from].banned ? t.from : t.to
            record(.rejected, line(t), L("рахунок \(name(who)) заблоковано").s)
            flow(.blocked, t.from, t.to, fraud: t.fraud)
            tally(t, stopped: true)
            if t.auto { autoFailed += 1 }
            return
        }
        guard accounts[t.from].balance >= t.amount else {
            record(.rejected, line(t), L("не вистачає коштів").s)
            if t.auto { autoFailed += 1 }
            return
        }
        let base = FraudLite.assess(amount: t.amount, balance: accounts[t.from].balance, description: t.note)
        let extra: (points: Int, flags: [String]) = p.history ? historyScore(t) : (0, [])
        let score = min(100, base.score + extra.points)
        outs[t.from].append(Move(tick: tick, peer: t.to, amount: t.amount))

        if Double(score) >= p.threshold {
            accounts[t.from].strikes += 1
            tally(t, stopped: true)
            if t.auto { autoFailed += 1 }
            let reasons = (base.flags + extra.flags).compactMap { FraudFlags.titles[$0] }.prefix(2).joined(separator: ", ")
            record(.blocked, line(t), L("бал \(score)").s + (reasons.isEmpty ? "" : ": " + reasons))
            flow(.blocked, t.from, t.to, fraud: t.fraud)
            if accounts[t.from].strikes >= 3 {
                accounts[t.from].banned = true
                accounts[t.from].bannedAt = tick
                if accounts[t.from].fraudSent > 0 { bansRight += 1 } else { bansWrong += 1 }
                record(.banned, L("Бан: рахунок \(name(t.from))").s)
                flow(.ban, t.from, t.from)
            }
            return
        }

        tally(t, stopped: false)
        if t.auto { autoDone += 1 }
        accounts[t.from].balance -= t.amount
        ins[t.to].append(Move(tick: tick, peer: t.from, amount: t.amount))
        edges.append(Edge(tick: tick, from: t.from, to: t.to))
        if accounts[t.from].bank == accounts[t.to].bank {
            accounts[t.to].balance += t.amount
            record(t.auto ? .auto : .ok, line(t), t.note.isEmpty ? nil : t.note)
            flow(t.auto ? .auto : .ok, t.from, t.to, fraud: t.fraud)
        } else {
            accounts[t.to].pending += t.amount
            clearing.append(Clearing(fromBank: accounts[t.from].bank, toBank: accounts[t.to].bank, to: t.to, amount: t.amount))
            record(.clearing, line(t), t.auto ? t.note : nil)
            flow(.clearing, t.from, t.to, fraud: t.fraud)
        }
    }

    // MARK: Кліринг

    /// Банки не шлють кожен платіж окремо: за період вони взаємно зараховують зустрічні потоки
    /// й переказують лише різницю між кожною парою.
    private mutating func settle() {
        guard !clearing.isEmpty else { return }
        let n = Self.banks.count
        var matrix = Array(repeating: Array(repeating: 0.0, count: n), count: n)
        for c in clearing { matrix[c.fromBank][c.toBank] += c.amount }
        var net = 0
        var netVolume = 0.0
        for i in 0..<n {
            for j in (i + 1)..<n {
                let d = abs(matrix[i][j] - matrix[j][i])
                if d > 0.005 { net += 1; netVolume += d }
            }
        }
        for c in clearing {
            accounts[c.to].balance += c.amount
            accounts[c.to].pending -= c.amount
        }
        let result = Settlement(gross: clearing.count, net: net, grossVolume: clearing.reduce(0) { $0 + $1.amount }, netVolume: netVolume)
        settlement = result
        clearing = []
        record(.settle, L("Кліринг: \(result.gross) платежів → \(result.net)").s)
        flow(.settle, 0, 0)
    }
}
