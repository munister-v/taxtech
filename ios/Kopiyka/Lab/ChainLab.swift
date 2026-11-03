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
                    Text(L("Останній відбиток при записі").s).font(.subheadline)
                    Spacer()
                    Text(short(anchor)).font(.system(.subheadline, design: .monospaced))
                }
                HStack {
                    Image(systemName: anchorMatches ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(anchorMatches ? Theme.accent : Theme.alert)
                    Text(anchorMatches ? L("Дані дають той самий відбиток").s : L("Інший відбиток: дані змінено").s)
                        .font(.footnote).foregroundStyle(.secondary)
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
            ChainCanvas(blocks: blocks, bad: bad, anchor: anchor, anchorOK: anchorMatches, selected: selected, wave: wave) { i in
                selected = i
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .padding(.top, 10)
            actions.padding(.top, 12)
        }
    }

    private func row(_ i: Int, bad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("№\(blocks[i].id)").caption()
                TextField(L("Запис").s, text: $blocks[i].note).font(.subheadline.weight(.medium))
                TextField("0", value: $blocks[i].amount, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 84)
            }
            HStack(spacing: 6) {
                Image(systemName: bad ? "link.badge.plus" : "link")
                    .foregroundStyle(bad ? Theme.alert : Theme.accent).font(.caption)
                Text(short(blocks[i].hash)).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(bad ? Theme.alert : Color.secondary)
                Text("←").foregroundStyle(.tertiary).font(.caption)
                Text(short(i == 0 ? Self.zero : blocks[i - 1].hash)).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(L("Підмінити запис").s) { blocks[selected].amount += 1_000 }.buttonStyle(LineButton())
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
            }
            HStack(spacing: 10) {
                // чесний запис можливий, лише поки дані дають записаний відбиток
                Button(L("Додати запис").s) { append() }.buttonStyle(LineButton())
                    .disabled(!anchorMatches)
                Button(L("Скинути").s) {
                    blocks = Self.build(rows)
                    anchor = blocks.last?.hash ?? Self.zero
                }
                .buttonStyle(LineButton())
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

/// Ланцюг блоків по горизонталі: розрив біжить від зміненого запису вправо, перерахунок проходить хвилею назад,
/// а відбиток, записаний окремо, лишається вердиктом.
private struct ChainCanvas: View {
    let blocks: [ChainLab.Block]
    let bad: [Bool]
    let anchor: String
    let anchorOK: Bool
    let selected: Int
    let wave: ChainWave?
    let onSelect: (Int) -> Void

    private let bw: CGFloat = 100, bh: CGFloat = 122, gap: CGFloat = 40, pad: CGFloat = 14, top: CGFloat = 16
    private let aw: CGFloat = 108
    private var width: CGFloat { pad + CGFloat(blocks.count) * (bw + gap) + aw + pad }

    private func rect(_ i: Int) -> CGRect { CGRect(x: pad + CGFloat(i) * (bw + gap), y: top, width: bw, height: bh) }
    private var anchorRect: CGRect { CGRect(x: pad + CGFloat(blocks.count) * (bw + gap), y: top + 22, width: aw, height: bh - 44) }
    private func short(_ h: String) -> String { String(h.prefix(8)) }
    private var zero: String { String(repeating: "0", count: 64) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                TimelineView(.animation) { tl in
                    Canvas { ctx, size in draw(&ctx, now: tl.date.timeIntervalSinceReferenceDate) }
                }
                .frame(width: width, height: bh + top * 2)
                .overlay {
                    Color.clear.contentShape(.rect).onTapGesture { p in
                        if let i = blocks.indices.first(where: { rect($0).insetBy(dx: -(gap / 2), dy: 0).contains(p) }) { onSelect(i) }
                    }
                }
                .overlay(alignment: .trailing) { Color.clear.frame(width: 1).id("end") }
            }
            .onChange(of: blocks.count) { _, _ in withAnimation { proxy.scrollTo("end", anchor: .trailing) } }
        }
        .frame(height: bh + top * 2)
        .accessibilityElement()
        .accessibilityLabel(L("Ланцюг").s)
    }

    private func duration(_ w: ChainWave) -> Double {
        switch w.kind {
        case .tamper(let i): 0.9 + Double(blocks.count - i) * 0.35 + 0.8
        case .reseal: 0.9 + Double(blocks.count) * 0.3 + 0.8
        case .append: 1.4
        }
    }

    private func draw(_ ctx: inout GraphicsContext, now t: TimeInterval) {
        let e = wave.map { t - $0.start } ?? .infinity
        let active = wave.map { e < duration($0) } ?? false
        func shown(_ k: Int) -> Bool {
            let b = k < bad.count ? bad[k] : false
            guard active, let w = wave else { return b }
            switch w.kind {
            case .tamper(let i): return b && k >= i ? e >= 0.1 + Double(k - i) * 0.35 : b
            case .reseal: return k < w.prevBad.count && w.prevBad[k] && e < 0.2 + Double(k) * 0.3 ? true : b
            case .append: return b
            }
        }
        var anchorBad = !anchorOK
        if active, let w = wave {
            switch w.kind {
            case .tamper(let i): anchorBad = !anchorOK && e >= 0.1 + Double(blocks.count - i) * 0.35
            case .reseal: anchorBad = !anchorOK && e >= 0.3 + Double(blocks.count) * 0.3
            case .append: break
            }
        }
        let appended: Int? = { if case .append(let i)? = wave?.kind, active { return i }; return nil }()

        // ланки між блоками
        for k in 0..<blocks.count {
            let a = CGPoint(x: rect(k).maxX, y: rect(k).midY)
            let b = CGPoint(x: k + 1 < blocks.count ? rect(k + 1).minX : anchorRect.minX, y: rect(k).midY)
            let broken = k + 1 < blocks.count ? shown(k + 1) : anchorBad
            if let ap = appended, k + 1 > ap { continue }
            if k + 1 == blocks.count {
                var d = Path(); d.move(to: a); d.addLine(to: b)
                ctx.stroke(d, with: .color((broken ? Theme.alert : Theme.accent).opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                if broken { LabFX.sparks(&ctx, CGPoint(x: (a.x + b.x) / 2, y: a.y), k: (e.truncatingRemainder(dividingBy: 1.2)) / 1.2, tint: Theme.alert, count: 5) }
                continue
            }
            link(&ctx, a, b, broken: broken, time: t)
        }

        // блоки
        for k in 0..<blocks.count {
            var r = rect(k)
            if let ap = appended, k == ap {
                let u = min(max((e - 0.5) / 0.5, 0), 1)
                r = r.offsetBy(dx: 30 * (1 - u), dy: 0)
                ctx.opacity = u
            }
            block(&ctx, k, r, bad: shown(k))
            ctx.opacity = 1
        }

        // якір
        let ar = anchorRect
        let ap = Path(roundedRect: ar, cornerRadius: 12, style: .continuous)
        ctx.fill(ap, with: .color(anchorBad ? Theme.alert.opacity(0.2) : Theme.ink.opacity(0.06)))
        ctx.stroke(ap, with: .color(anchorBad ? Theme.alert : Theme.accent.opacity(0.6)), style: StrokeStyle(lineWidth: 1.4, dash: [5, 3]))
        ctx.draw(Text(L("Записано окремо").s).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Theme.ink.opacity(0.55)), at: CGPoint(x: ar.midX, y: ar.minY + 14))
        ctx.draw(Text(short(anchor)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(anchorBad ? Theme.alert : Theme.accent), at: CGPoint(x: ar.midX, y: ar.midY))
        ctx.draw(Text(anchorBad ? "✕" : "✓").font(.system(size: 16, weight: .bold)).foregroundStyle(anchorBad ? Theme.alert : Theme.accent), at: CGPoint(x: ar.midX, y: ar.maxY - 14))

        // хвилі
        guard active, let w = wave else { return }
        switch w.kind {
        case .tamper(let i):
            let c = CGPoint(x: rect(i).midX, y: rect(i).midY)
            LabFX.ring(&ctx, c, r: 20 + 50 * min(e / 0.7, 1), tint: Theme.alert, alpha: 1 - min(e / 0.7, 1))
            LabFX.sparks(&ctx, CGPoint(x: rect(i).midX, y: rect(i).minY), k: e / 0.7, tint: Theme.alert)
            for k in i..<blocks.count {
                let a = CGPoint(x: rect(k).maxX, y: rect(k).midY)
                let b = CGPoint(x: k + 1 < blocks.count ? rect(k + 1).minX : anchorRect.minX, y: rect(k).midY)
                LabFX.comet(&ctx, from: a, to: b, t: (e - 0.1 - Double(k - i) * 0.35 + 0.35) / 0.35, tint: Theme.alert)
                if k + 1 < blocks.count {
                    let at = 0.1 + Double(k + 1 - i) * 0.35
                    LabFX.ring(&ctx, CGPoint(x: rect(k + 1).midX, y: rect(k + 1).midY), r: 24 + 40 * ((e - at) / 0.6), tint: Theme.alert, alpha: (e > at ? 1 - (e - at) / 0.6 : 0) * 0.7)
                }
            }
        case .reseal:
            for k in 0..<blocks.count {
                let at = 0.2 + Double(k) * 0.3
                if k > 0 {
                    LabFX.comet(&ctx, from: CGPoint(x: rect(k - 1).maxX, y: rect(k).midY), to: CGPoint(x: rect(k).minX, y: rect(k).midY), t: (e - at + 0.3) / 0.3, tint: Theme.accent)
                }
                LabFX.ring(&ctx, CGPoint(x: rect(k).midX, y: rect(k).midY), r: 24 + 36 * ((e - at) / 0.6), tint: Theme.accent, alpha: (e > at ? 1 - (e - at) / 0.6 : 0) * 0.8)
            }
            let end = 0.3 + Double(blocks.count) * 0.3
            let c = CGPoint(x: anchorRect.midX, y: anchorRect.midY)
            LabFX.comet(&ctx, from: CGPoint(x: rect(blocks.count - 1).maxX, y: rect(blocks.count - 1).midY), to: CGPoint(x: anchorRect.minX, y: rect(blocks.count - 1).midY), t: (e - end + 0.3) / 0.3, tint: Theme.accent)
            if !anchorOK { LabFX.sparks(&ctx, c, k: (e - end) / 0.7, tint: Theme.alert) }
            else { LabFX.ring(&ctx, c, r: 30 + 40 * ((e - end) / 0.7), tint: Theme.accent, alpha: e > end ? 1 - (e - end) / 0.7 : 0) }
        case .append(let i):
            LabFX.comet(&ctx, from: CGPoint(x: rect(i - 1).maxX - 10, y: rect(i).midY), to: CGPoint(x: rect(i).minX, y: rect(i).midY), t: (e - 0.1) / 0.5, tint: Theme.accent)
            LabFX.ring(&ctx, CGPoint(x: rect(i).midX, y: rect(i).midY), r: 24 + 40 * ((e - 0.9) / 0.5), tint: Theme.accent, alpha: e > 0.9 ? 1 - (e - 0.9) / 0.5 : 0)
        }
    }

    private func link(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, broken: Bool, time t: TimeInterval) {
        let tint = broken ? Theme.alert : Theme.accent
        let mid = (a.x + b.x) / 2
        func cell(_ cx: CGFloat) -> Path { Path(roundedRect: CGRect(x: cx - 12, y: a.y - 7, width: 24, height: 14), cornerRadius: 7) }
        if broken {
            let j = sin(t * 40) * 1.2
            ctx.stroke(cell(a.x + 8 - 3 + j), with: .color(tint), lineWidth: 2)
            ctx.stroke(cell(b.x - 8 + 3 - j), with: .color(tint), lineWidth: 2)
            LabFX.sparks(&ctx, CGPoint(x: mid, y: a.y), k: (t.truncatingRemainder(dividingBy: 1.1)) / 1.1, tint: tint, count: 5)
        } else {
            ctx.stroke(cell(mid - 7), with: .color(tint.opacity(0.75)), lineWidth: 2)
            ctx.stroke(cell(mid + 7), with: .color(tint.opacity(0.75)), lineWidth: 2)
        }
    }

    private func block(_ ctx: inout GraphicsContext, _ k: Int, _ r: CGRect, bad: Bool) {
        let b = blocks[k]
        let sel = k == selected
        let shape = Path(roundedRect: r, cornerRadius: 14, style: .continuous)
        ctx.fill(shape, with: .color(bad ? Theme.alert.opacity(0.2) : Theme.ink.opacity(sel ? 0.12 : 0.06)))
        ctx.stroke(shape, with: .color(bad ? Theme.alert : sel ? Theme.accent : Theme.accent.opacity(0.35)), lineWidth: sel || bad ? 1.8 : 1)
        let x = r.minX + 11
        ctx.draw(Text("№\(b.id)").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.ink.opacity(0.45)), at: CGPoint(x: x, y: r.minY + 15), anchor: .leading)
        ctx.draw(Text(String(b.note.prefix(11))).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink), at: CGPoint(x: x, y: r.minY + 36), anchor: .leading)
        ctx.draw(Text(Format.short(b.amount)).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundStyle(bad ? Theme.alert : Theme.ink), at: CGPoint(x: x, y: r.minY + 58), anchor: .leading)
        var line = Path()
        line.move(to: CGPoint(x: x, y: r.minY + 76)); line.addLine(to: CGPoint(x: r.maxX - 11, y: r.minY + 76))
        ctx.stroke(line, with: .color(Theme.ink.opacity(0.12)), lineWidth: 1)
        ctx.draw(Text("← " + short(k == 0 ? zero : blocks[k - 1].hash)).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(Theme.ink.opacity(0.35)),
                 at: CGPoint(x: x, y: r.minY + 92), anchor: .leading)
        ctx.draw(Text("# " + short(b.hash)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(bad ? Theme.alert : Theme.accent),
                 at: CGPoint(x: x, y: r.minY + 108), anchor: .leading)
    }
}
