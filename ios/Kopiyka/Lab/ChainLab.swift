import CryptoKit
import SwiftUI

/// Дослід 3: хеш-ланцюг переказів, як `integrity_service.py` на сервері. Запис можна змінити
/// й побачити, де розривається ланцюг, а потім перерахувати хеші й побачити, що видає підміну.
struct ChainLab: View {
    struct Block: Identifiable, Equatable {
        let id: Int
        var note: String
        var amount: Double
        var hash: String
    }

    private static let zero = String(repeating: "0", count: 64)

    @Environment(AppModel.self) private var model
    @State private var mine = false
    @State private var rows = ChainLab.sample()
    @State private var blocks: [Block] = ChainLab.seed()
    /// Останній відбиток, який «записано окремо» - наприклад, у квитанції чи в іншому сховищі.
    @State private var anchor = ChainLab.seed().last?.hash ?? ChainLab.zero
    @State private var selected = 1
    @State private var wave: ChainWave?

    // MARK: Хеш

    static func digest(_ index: Int, _ note: String, _ amount: Double, prev: String) -> String {
        SHA256.hash(data: Data("\(index)|\(note)|\(amount.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))))|\(prev)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    static func sample() -> [(String, Double)] {
        [(L("Поповнення").s, 1_000), (L("Кава").s, 85), (L("Переказ Ірині").s, 250), (L("Метро").s, 40), (L("Книжки").s, 420)]
    }

    static func seed() -> [Block] { build(sample()) }

    static func build(_ rows: [(String, Double)]) -> [Block] {
        var prev = zero
        return rows.enumerated().map { i, r in
            let h = digest(i + 1, r.0, r.1, prev: prev)
            prev = h
            return Block(id: i + 1, note: r.0, amount: r.1, hash: h)
        }
    }

    /// Перевірка рахує ланцюг наново: де кожна ланка не збігається із записаним відбитком
    /// і який відбиток виходить на кінці.
    private var verified: (broken: [Bool], head: String) {
        var prev = Self.zero
        let broken = blocks.map { b in
            let h = Self.digest(b.id, b.note, b.amount, prev: prev)
            prev = h
            return h != b.hash
        }
        return (broken, prev)
    }

    private var firstBroken: Int? { verified.broken.firstIndex(of: true) }
    /// Відбиток, порахований із поточних даних, проти записаного окремо.
    private var anchorMatches: Bool { verified.head == anchor }

    var body: some View {
        let bad = verified.broken
        VStack(alignment: .leading, spacing: 16) {
            status(bad)
            LabPanel(title: L("Записи").s) {
                if model.signedIn {
                    SegmentBar(items: [(false, L("Приклад").s), (true, L("Мої операції").s)], selection: $mine)
                }
                ForEach(blocks.indices, id: \.self) { i in
                    row(i, bad: bad[i])
                    if i < blocks.count - 1 { Rule() }
                }
            }
            LabPanel(title: L("Записаний окремо").s) {
                HStack {
                    Text(L("Останній відбиток при записі").s).font(Theme.ui(style: .subheadline))
                    Spacer()
                    Text(short(anchor)).font(Theme.mono(style: .subheadline))
                }
                HStack {
                    Image(systemName: anchorMatches ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(anchorMatches ? Theme.accent : Theme.alert)
                    Text(anchorMatches ? L("Дані дають той самий відбиток").s : L("Інший відбиток: дані змінено").s)
                        .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                }
            }
        }
        .animation(.snappy, value: bad)
        .onChange(of: blocks) { old, new in
            guard old.count == new.count, let i = new.indices.first(where: { old[$0].note != new[$0].note || old[$0].amount != new[$0].amount }),
                  verified.broken[i] else { return }
            selected = i
            wave = ChainWave(kind: .tamper(i), start: Date.timeIntervalSinceReferenceDate, prevBad: [])
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        }
        .animation(.snappy, value: anchorMatches)
        .onChange(of: mine) { _, on in
            Task {
                if on {
                    let ops = await LiveData.operations(model, limit: 5)
                    if !ops.isEmpty { rows = ops.map { ($0.title, $0.amount) } } else { mine = false; return }
                } else {
                    rows = Self.sample()
                }
                blocks = Self.build(rows)
                anchor = blocks.last?.hash ?? Self.zero
            }
        }
        #if DEBUG
        // simctl launch з SIMCTL_CHILD_KOPIYKA_CHAIN_TAMPER=1: другий запис уже змінено
        .onAppear { if ProcessInfo.processInfo.environment["KOPIYKA_CHAIN_TAMPER"] == "1" { blocks[1].amount = 8_500 } }
        #endif
    }

    private func status(_ bad: [Bool]) -> some View {
        LabHero(ok: firstBroken == nil) {
            HeroCaption(L("Перевірка ланцюга").s)
            Text(firstBroken.map { L("Розрив із запису №\($0 + 1)").s } ?? L("Ланцюг цілий").s)
                .font(.display(30, .medium)).tracking(-0.6).padding(.top, 4)
            actions.padding(.top, 14)
            ChainCanvas(blocks: blocks, bad: bad, anchor: anchor, anchorOK: anchorMatches, selected: selected, wave: wave) { i in
                selected = i
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .padding(.top, 18)
        }
    }

    private func row(_ i: Int, bad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("№\(blocks[i].id)").caption()
                TextField(L("Запис").s, text: $blocks[i].note).font(Theme.ui(style: .subheadline, .medium))
                TextField("0", value: $blocks[i].amount, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(Theme.ui(style: .subheadline, .semibold)).monospacedDigit().frame(width: 84)
            }
            HStack(spacing: 6) {
                Image(systemName: bad ? "link.badge.plus" : "link")
                    .foregroundStyle(bad ? Theme.alert : Theme.accent).font(Theme.ui(style: .caption1))
                Text(short(blocks[i].hash)).font(Theme.mono(style: .caption1))
                    .foregroundStyle(bad ? Theme.alert : Color.secondary)
                Text("←").foregroundStyle(.tertiary).font(Theme.ui(style: .caption1))
                Text(short(i == 0 ? Self.zero : blocks[i - 1].hash)).font(Theme.mono(style: .caption1))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(L("Підмінити запис").s) { blocks[selected].amount += 1_000 }.buttonStyle(LineButton())
                // чесний запис можливий, лише поки дані дають записаний відбиток
                Button(L("Додати запис").s) { append() }.buttonStyle(LineButton())
                    .disabled(!anchorMatches)
            }
            HStack(spacing: 10) {
                Button(L("Перерахувати відбитки").s) {
                    wave = ChainWave(kind: .reseal, start: Date.timeIntervalSinceReferenceDate, prevBad: verified.broken)
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    var prev = Self.zero
                    for i in blocks.indices {
                        blocks[i].hash = Self.digest(blocks[i].id, blocks[i].note, blocks[i].amount, prev: prev)
                        prev = blocks[i].hash
                    }
                }
                .buttonStyle(InkButton())
                .disabled(firstBroken == nil)
                Button {
                    blocks = Self.build(rows)
                    anchor = blocks.last?.hash ?? Self.zero
                } label: {
                    Image(systemName: "arrow.counterclockwise").font(Theme.ui(style: .body, .semibold))
                }
                .buttonStyle(LineButton())
                .frame(width: 64)
                .accessibilityLabel(L("Скинути").s)
            }
        }
    }

    /// Чесне додавання: нова ланка спирається на останній відбиток, і його записують окремо.
    private func append() {
        let prev = blocks.last?.hash ?? Self.zero
        let id = (blocks.last?.id ?? 0) + 1
        let amount = Double(Int.random(in: 20...900))
        let note = L("Покупка").s
        let h = Self.digest(id, note, amount, prev: prev)
        blocks.append(Block(id: id, note: note, amount: amount, hash: h))
        anchor = h
        wave = ChainWave(kind: .append(blocks.count - 1), start: Date.timeIntervalSinceReferenceDate, prevBad: [])
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func short(_ h: String) -> String { String(h.prefix(8)) }
}

struct ChainWave {
    enum Kind: Equatable { case tamper(Int), reseal, append(Int) }
    let kind: Kind
    let start: TimeInterval
    let prevBad: [Bool]
}

/// Ланцюг блоків згори вниз: розрив іде від зміненого запису вниз по рейці, перерахунок проходить золотою хвилею,
/// а відбиток, записаний окремо, лишається вердиктом.
private struct ChainCanvas: View {
    let blocks: [ChainLab.Block]
    let bad: [Bool]
    let anchor: String
    let anchorOK: Bool
    let selected: Int
    let wave: ChainWave?
    let onSelect: (Int) -> Void

    private let bh: CGFloat = 66, gap: CGFloat = 28, ah: CGFloat = 48, rail: CGFloat = 26
    private var height: CGFloat { CGFloat(blocks.count) * (bh + gap) + ah + 4 }

    private func rect(_ i: Int, _ w: CGFloat) -> CGRect { CGRect(x: 0, y: 2 + CGFloat(i) * (bh + gap), width: w, height: bh) }
    private func anchorRect(_ w: CGFloat) -> CGRect { CGRect(x: 0, y: 2 + CGFloat(blocks.count) * (bh + gap), width: w, height: ah) }
    private func short(_ h: String) -> String { String(h.prefix(8)) }
    private var zero: String { String(repeating: "0", count: 64) }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in draw(&ctx, size.width, now: tl.date.timeIntervalSinceReferenceDate) }
        }
        .frame(height: height)
        .overlay {
            GeometryReader { g in
                Color.clear.contentShape(.rect).onTapGesture { p in
                    if let i = blocks.indices.first(where: { rect($0, g.size.width).insetBy(dx: 0, dy: -gap / 2).contains(p) }) { onSelect(i) }
                }
            }
        }
        .animation(.snappy, value: blocks.count)
        .accessibilityElement()
        .accessibilityLabel(L("Ланцюг").s)
    }

    private func duration(_ w: ChainWave) -> Double {
        switch w.kind {
        case .tamper(let i): 0.9 + Double(blocks.count - i) * 0.35 + 0.8
        case .reseal: 0.9 + Double(blocks.count) * 0.3 + 0.8
        case .append: 1.6
        }
    }

    private func pulse(_ ctx: inout GraphicsContext, _ r: CGRect, tint: Color, u: Double) {
        guard u >= 0, u <= 1 else { return }
        let grow = 10 * u
        ctx.stroke(Path(roundedRect: r.insetBy(dx: -grow, dy: -grow), cornerRadius: 14 + grow, style: .continuous),
                   with: .color(tint.opacity(0.9 * (1 - u))), lineWidth: 1.6)
    }

    private func draw(_ ctx: inout GraphicsContext, _ w: CGFloat, now t: TimeInterval) {
        let e = wave.map { t - $0.start } ?? .infinity
        let active = wave.map { e < duration($0) } ?? false
        let n = blocks.count
        func shown(_ k: Int) -> Bool {
            let b = k < bad.count ? bad[k] : false
            guard active, let wv = wave else { return b }
            switch wv.kind {
            case .tamper(let i): return b && k >= i ? e >= 0.1 + Double(k - i) * 0.35 : b
            case .reseal: return k < wv.prevBad.count && wv.prevBad[k] && e < 0.2 + Double(k) * 0.3 ? true : b
            case .append: return b
            }
        }
        var anchorBad = !anchorOK
        if active, let wv = wave {
            switch wv.kind {
            case .tamper(let i): anchorBad = !anchorOK && e >= 0.1 + Double(n - i) * 0.35
            case .reseal: anchorBad = !anchorOK && e >= 0.2 + Double(n) * 0.3
            case .append: break
            }
        }
        let appended: Int? = { if case .append(let i)? = wave?.kind, active { return i }; return nil }()

        // рейка між блоками
        for k in 0..<n {
            if let ap = appended, k + 1 > ap { continue }
            let a = CGPoint(x: rail, y: rect(k, w).maxY)
            let b = CGPoint(x: rail, y: k + 1 < n ? rect(k + 1, w).minY : anchorRect(w).minY)
            connector(&ctx, a, b, broken: k + 1 < n ? shown(k + 1) : anchorBad, dashed: k + 1 == n, time: t)
        }

        // блоки
        for k in 0..<n {
            var r = rect(k, w)
            if let ap = appended, k == ap {
                let u = min(max((e - 0.5) / 0.5, 0), 1)
                r = r.offsetBy(dx: 0, dy: 14 * (1 - u))
                ctx.opacity = u
            }
            block(&ctx, k, r, bad: shown(k))
            ctx.opacity = 1
        }

        // запис окремо
        let ar = anchorRect(w)
        let shape = Path(roundedRect: ar, cornerRadius: 14, style: .continuous)
        let tint = anchorBad ? Theme.alert : Theme.accent
        ctx.fill(shape, with: .color(anchorBad ? Theme.alert.opacity(0.12) : Theme.ink.opacity(0.04)))
        ctx.stroke(shape, with: .color(tint.opacity(anchorBad ? 0.9 : 0.5)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        ctx.draw(Text(L("Записано окремо").s).font(Theme.ui(12, .medium)).foregroundStyle(Theme.ink.opacity(0.6)),
                 at: CGPoint(x: ar.minX + 14, y: ar.midY), anchor: .leading)
        ctx.draw(Text(anchorBad ? "✕" : "✓").font(Theme.ui(15, .bold)).foregroundStyle(tint), at: CGPoint(x: ar.maxX - 16, y: ar.midY))
        ctx.draw(Text("# " + short(anchor)).font(Theme.mono(11, .semibold)).foregroundStyle(tint),
                 at: CGPoint(x: ar.maxX - 34, y: ar.midY), anchor: .trailing)

        // хвилі
        guard active, let wv = wave else { return }
        func linkEnds(_ k: Int) -> (CGPoint, CGPoint) {
            (CGPoint(x: rail, y: rect(k, w).maxY), CGPoint(x: rail, y: k + 1 < n ? rect(k + 1, w).minY : ar.minY))
        }
        switch wv.kind {
        case .tamper(let i):
            pulse(&ctx, rect(i, w), tint: Theme.alert, u: e / 0.7)
            for k in i..<n {
                let start = 0.1 + Double(k - i) * 0.35
                let (a, b) = linkEnds(k)
                LabFX.comet(&ctx, from: a, to: b, t: (e - start) / 0.35, tint: Theme.alert)
                if k + 1 < n { pulse(&ctx, rect(k + 1, w), tint: Theme.alert, u: (e - start - 0.35) / 0.6) }
            }
        case .reseal:
            for k in 0..<n {
                let at = 0.2 + Double(k) * 0.3
                if k > 0 { let (a, b) = linkEnds(k - 1); LabFX.comet(&ctx, from: a, to: b, t: (e - (at - 0.3)) / 0.3, tint: Theme.accent) }
                pulse(&ctx, rect(k, w), tint: Theme.accent, u: (e - at) / 0.6)
            }
            let last = 0.2 + Double(n - 1) * 0.3
            let (a, b) = linkEnds(n - 1)
            LabFX.comet(&ctx, from: a, to: b, t: (e - last) / 0.3, tint: Theme.accent)
            let end = last + 0.3
            pulse(&ctx, ar, tint: anchorOK ? Theme.accent : Theme.alert, u: (e - end) / 0.7)
        case .append(let i):
            let (a, b) = linkEnds(i - 1)
            LabFX.comet(&ctx, from: a, to: b, t: (e - 0.1) / 0.5, tint: Theme.accent)
            pulse(&ctx, rect(i, w), tint: Theme.accent, u: (e - 0.9) / 0.6)
        }
    }

    /// Тонка рейка між блоками: цілою - рівна лінія з точкою, розірваною - дві зламані половини з іскрами.
    private func connector(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, broken: Bool, dashed: Bool, time t: TimeInterval) {
        let mid = CGPoint(x: a.x, y: (a.y + b.y) / 2)
        if broken {
            let j = sin(t * 38) * 1.3
            var top = Path(); top.move(to: a); top.addLine(to: CGPoint(x: a.x + j, y: mid.y - 5))
            var bot = Path(); bot.move(to: CGPoint(x: a.x - j, y: mid.y + 5)); bot.addLine(to: b)
            ctx.stroke(top, with: .color(Theme.alert), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            ctx.stroke(bot, with: .color(Theme.alert), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            LabFX.sparks(&ctx, mid, k: t.truncatingRemainder(dividingBy: 1.1) / 1.1, tint: Theme.alert, count: 6)
        } else {
            var l = Path(); l.move(to: a); l.addLine(to: b)
            ctx.stroke(l, with: .color(Theme.accent.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: dashed ? [3, 4] : []))
            ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 3, y: mid.y - 3, width: 6, height: 6)), with: .color(Theme.accent.opacity(0.8)))
        }
    }

    private func block(_ ctx: inout GraphicsContext, _ k: Int, _ r: CGRect, bad: Bool) {
        let b = blocks[k]
        let sel = k == selected
        let shape = Path(roundedRect: r, cornerRadius: 14, style: .continuous)
        ctx.fill(shape, with: .color(bad ? Theme.alert.opacity(0.12) : Theme.ink.opacity(sel ? 0.09 : 0.05)))
        ctx.stroke(shape, with: .color(bad ? Theme.alert.opacity(0.9) : sel ? Theme.accent : Theme.ink.opacity(0.12)), lineWidth: sel || bad ? 1.4 : 1)
        let x = r.minX + 14
        ctx.draw(Text("№\(b.id)").font(Theme.ui(11, .semibold)).foregroundStyle(Theme.ink.opacity(0.4)), at: CGPoint(x: x, y: r.minY + 22), anchor: .leading)
        ctx.draw(Text(String(b.note.prefix(20))).font(Theme.ui(14, .medium)).foregroundStyle(Theme.ink), at: CGPoint(x: x + 30, y: r.minY + 22), anchor: .leading)
        ctx.draw(Text(Format.short(b.amount)).font(Theme.ui(15, .semibold).monospacedDigit()).foregroundStyle(bad ? Theme.alert : Theme.ink),
                 at: CGPoint(x: r.maxX - 14, y: r.minY + 22), anchor: .trailing)
        ctx.draw(Text("← " + short(k == 0 ? zero : blocks[k - 1].hash)).font(Theme.mono(10.5)).foregroundStyle(Theme.ink.opacity(0.32)),
                 at: CGPoint(x: x, y: r.minY + 47), anchor: .leading)
        ctx.draw(Text("# " + short(b.hash)).font(Theme.mono(11.5, .semibold)).foregroundStyle(bad ? Theme.alert : Theme.accent),
                 at: CGPoint(x: r.maxX - 14, y: r.minY + 47), anchor: .trailing)
    }
}
