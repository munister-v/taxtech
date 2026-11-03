import CryptoKit
import SwiftUI

/// Дослід: дерево Меркла з чотирьох записів. Корінь підписує весь набір, а доказ для одного запису -
/// це лише сусідні відбитки на шляху до кореня.
struct MerkleLab: View {
    private struct Tree {
        let leaves: [String]
        let pair: [String]
        let root: String

        init(_ texts: [String]) {
            leaves = texts.map(MerkleLab.hash)
            pair = [MerkleLab.hash(leaves[0] + leaves[1]), MerkleLab.hash(leaves[2] + leaves[3])]
            root = MerkleLab.hash(pair[0] + pair[1])
        }
    }

    private static func initial() -> [String] {
        [L("Оплата 120").s, L("Переказ 40").s, L("Зарахування 500").s, L("Оплата 75").s]
    }

    /// Чотири найновіші операції рахунку: назва й сума записом дерева.
    private static func records(_ ops: [LiveOperation]) -> [String] {
        ops.map { "\($0.title) \($0.income ? "+" : "−")\(Format.short($0.amount))" }
    }

    nonisolated static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func short(_ h: String) -> String { String(h.prefix(8)) }

    @Environment(AppModel.self) private var model
    @State private var mine = false
    @State private var base = MerkleLab.initial()
    @State private var texts = MerkleLab.initial()
    /// Дерево, корінь якого «записано окремо»: з нього беруться сусідні відбитки для доказу.
    @State private var anchor = Tree(MerkleLab.initial())
    @State private var selected = 0
    @State private var wave: Wave?

    private var tree: Tree { Tree(texts) }

    /// Доказ: перераховуємо корінь від поточного тексту запису й двох сусідніх відбитків із записаного дерева.
    private var proofOK: Bool {
        let i = selected
        let leaf = Self.hash(texts[i])
        let sibling = anchor.leaves[i ^ 1]
        let level1 = i % 2 == 0 ? Self.hash(leaf + sibling) : Self.hash(sibling + leaf)
        let uncle = anchor.pair[(i / 2) ^ 1]
        let root = (i / 2) % 2 == 0 ? Self.hash(level1 + uncle) : Self.hash(uncle + level1)
        return root == anchor.root
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            rootPanel
            records
            proof
        }
        .animation(.snappy, value: tree.root)
        .onChange(of: texts) { old, new in
            guard let i = new.indices.first(where: { old[$0] != new[$0] }), tree.leaves[i] != anchor.leaves[i] else { return }
            selected = i
            wave = Wave(kind: .tamper, leaf: i, start: Date.timeIntervalSinceReferenceDate)
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
        }
    }

    struct Wave {
        enum Kind: Equatable { case tamper, verify(ok: Bool) }
        let kind: Kind
        let leaf: Int
        let start: TimeInterval
    }

    private func verify() {
        let ok = proofOK
        wave = Wave(kind: .verify(ok: ok), leaf: selected, start: Date.timeIntervalSinceReferenceDate)
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .error)
        }
    }

    private var rootPanel: some View {
        let same = tree.root == anchor.root
        return LabHero(ok: same) {
            HeroCaption(L("Корінь дерева").s)
            Text(Self.short(tree.root)).font(.system(size: 34, weight: .medium, design: .monospaced)).padding(.top, 4)
            Text(same ? L("Збігається із записаним").s : L("Змінився: записаний був \(Self.short(anchor.root))").s)
                .font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)
            TreeCanvas(now: tree.leaves + tree.pair + [tree.root], saved: anchor.leaves + anchor.pair + [anchor.root],
                       labels: texts, selected: selected, wave: wave) { i in
                selected = i
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .padding(.top, 10)
            legend.padding(.top, 2)
            HStack(spacing: 10) {
                Button(L("Підмінити запис").s) { texts[selected] += "0" }.buttonStyle(LineButton())
                Button(L("Перевірити доказ").s) { verify() }.buttonStyle(InkButton())
            }
            .padding(.top, 12)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            ForEach([(Theme.accent, L("Шлях запису").s), (Color(red: 0.50, green: 0.80, blue: 0.82), L("Відбитки доказу").s),
                     (Theme.alert, L("Змінено").s)], id: \.1) { c, t in
                HStack(spacing: 5) {
                    Circle().fill(c).frame(width: 6, height: 6)
                    Text(t).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var records: some View {
        LabPanel(title: L("Записи").s) {
            if model.signedIn {
                SegmentBar(items: [(false, L("Приклад").s), (true, L("Мої операції").s)], selection: $mine)
                    .onChange(of: mine) { _, on in
                        Task {
                            let ops = await LiveData.operations(model, limit: 4)
                            if on && ops.count == 4 { base = Self.records(ops) } else if on { mine = false; return } else { base = Self.initial() }
                            texts = base
                            anchor = Tree(base)
                        }
                    }
            }
            ForEach(0..<4, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("№\(i + 1)").caption()
                        TextField(L("Запис").s, text: $texts[i]).font(.subheadline.weight(.medium))
                    }
                    Text(Self.short(tree.leaves[i]))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(tree.leaves[i] == anchor.leaves[i] ? Color.secondary : Theme.alert)
                }
                if i < 3 { Rule() }
            }
            HStack(spacing: 10) {
                Button(L("Записати корінь").s) { anchor = tree }.buttonStyle(LineButton())
                Button(L("Скинути").s) { texts = base; anchor = Tree(base) }.buttonStyle(LineButton())
            }
        }
    }

    private var proof: some View {
        LabPanel(title: L("Доказ для запису").s) {
            Picker(L("Запис").s, selection: $selected) {
                ForEach(0..<4, id: \.self) { Text("№\($0 + 1)").tag($0) }
            }
            .pickerStyle(.segmented)
            let i = selected
            row(L("Сусідній листок").s, Self.short(anchor.leaves[i ^ 1]))
            row(L("Сусідня пара").s, Self.short(anchor.pair[(i / 2) ^ 1]))
            HStack {
                Image(systemName: proofOK ? "checkmark.seal.fill" : "xmark.seal.fill").foregroundStyle(proofOK ? Theme.accent : Theme.alert)
                Text(proofOK ? L("Доказ вірний: корінь збігається").s : L("Доказ не проходить: запис змінено").s)
                    .font(.subheadline.weight(.medium))
            }
            Text(L("Для доказу потрібні лише два відбитки, а не весь набір.").s).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced))
        }
    }

    // MARK: Дерево

    /// Дерево малюється з тих самих відбитків: листки 0-3, пари 4-5, корінь 6.
    private struct TreeCanvas: View {
        let now: [String]
        let saved: [String]
        let labels: [String]
        let selected: Int
        let wave: Wave?
        let onSelect: (Int) -> Void

        private let teal = Color(red: 0.50, green: 0.80, blue: 0.82)
        private let aspect = 0.78

        private func center(_ n: Int, _ size: CGSize) -> CGPoint {
            switch n {
            case 0..<4: CGPoint(x: (0.125 + 0.25 * Double(n)) * size.width, y: 0.70 * size.height)
            case 4..<6: CGPoint(x: (0.25 + 0.5 * Double(n - 4)) * size.width, y: 0.41 * size.height)
            default: CGPoint(x: 0.5 * size.width, y: 0.12 * size.height)
            }
        }

        private func box(_ n: Int, _ size: CGSize) -> CGRect {
            let c = center(n, size)
            let w = size.width * (n == 6 ? 0.30 : 0.22), h: CGFloat = n == 6 ? 32 : 28
            return CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        }

        private func parent(_ n: Int) -> Int? { n < 4 ? 4 + n / 2 : n < 6 ? 6 : nil }

        var body: some View {
            TimelineView(.animation) { tl in
                Canvas { ctx, size in draw(&ctx, size, now: tl.date.timeIntervalSinceReferenceDate) }
            }
            .aspectRatio(1 / aspect, contentMode: .fit)
            .overlay {
                GeometryReader { g in
                    Color.clear.contentShape(.rect).onTapGesture { p in
                        if let i = (0..<4).first(where: { box($0, g.size).insetBy(dx: -6, dy: -22).contains(p) }) { onSelect(i) }
                    }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(L("Дерево").s)
        }

        private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, now t: TimeInterval) {
            let e = wave.map { t - $0.start } ?? .infinity
            let w = wave
            func changed(_ n: Int) -> Bool { now[n] != saved[n] }
            // під час хвилі підміни вузол червоніє, коли хвиля до нього дійшла
            func lit(_ n: Int) -> Bool {
                guard changed(n) else { return false }
                guard let w, w.kind == .tamper, e < 1.6 else { return true }
                let path = [w.leaf, 4 + w.leaf / 2, 6]
                guard let level = path.firstIndex(of: n) else { return true }
                return e >= [0.0, 0.7, 1.25][level]
            }
            let path = [selected, 4 + selected / 2, 6]
            let proof = [selected ^ 1, 4 + (selected / 2) ^ 1]

            // ребра
            for n in 0..<6 {
                guard let p = parent(n) else { continue }
                var line = Path()
                line.move(to: CGPoint(x: center(n, size).x, y: box(n, size).minY))
                line.addLine(to: CGPoint(x: center(p, size).x, y: box(p, size).maxY))
                let hot = lit(n) && lit(p)
                let onPath = path.contains(n) && path.contains(p)
                let color: Color = hot ? Theme.alert : onPath ? Theme.accent : proof.contains(n) ? teal.opacity(0.7) : Theme.ink.opacity(0.16)
                ctx.stroke(line, with: .color(color), lineWidth: hot || onPath ? 2 : 1)
            }

            // вузли
            for n in 0..<7 {
                var r = box(n, size)
                if n == 6, let w, w.kind == .tamper, e > 1.25, e < 1.65 { r.origin.x += sin(e * 70) * 3 * (1.65 - e) / 0.4 }
                let bad = lit(n)
                let stroke: Color = bad ? Theme.alert : path.contains(n) ? Theme.accent : proof.contains(n) ? teal : Theme.accent.opacity(0.35)
                let rr = Path(roundedRect: r, cornerRadius: 9, style: .continuous)
                ctx.fill(rr, with: .color(bad ? Theme.alert.opacity(0.22) : Theme.ink.opacity(path.contains(n) ? 0.12 : 0.06)))
                ctx.stroke(rr, with: .color(stroke), lineWidth: path.contains(n) || proof.contains(n) || bad ? 1.8 : 1)
                ctx.draw(Text(String(now[n].prefix(6))).font(.system(size: n == 6 ? 13 : 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(bad ? Theme.alert : Theme.ink), at: CGPoint(x: r.midX, y: r.midY))
                if n < 4 {
                    ctx.draw(Text(String(labels[n].prefix(15))).font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(lit(n) ? Theme.alert : Theme.ink.opacity(0.5)), at: CGPoint(x: r.midX, y: r.maxY + 12))
                }
            }

            guard let w, e >= 0, e < 3 else { return }
            switch w.kind {
            case .tamper:
                ring(&ctx, center(w.leaf, size), r: 16 + 26 * min(e / 0.6, 1), tint: Theme.alert, a: 1 - min(e / 0.6, 1))
                comet(&ctx, from: top(w.leaf, size), to: bottom(4 + w.leaf / 2, size), t: (e - 0.15) / 0.55, tint: Theme.alert)
                ring(&ctx, center(4 + w.leaf / 2, size), r: 14 + 26 * ((e - 0.7) / 0.6), tint: Theme.alert, a: 1 - (e - 0.7) / 0.6, on: e > 0.7)
                comet(&ctx, from: top(4 + w.leaf / 2, size), to: bottom(6, size), t: (e - 0.7) / 0.55, tint: Theme.alert)
                ring(&ctx, center(6, size), r: 18 + 40 * ((e - 1.25) / 0.7), tint: Theme.alert, a: 1 - (e - 1.25) / 0.7, on: e > 1.25)
            case .verify(let ok):
                let pair = 4 + w.leaf / 2
                ring(&ctx, center(w.leaf, size), r: 16 + 22 * min(e / 0.5, 1), tint: Theme.accent, a: 1 - min(e / 0.5, 1))
                comet(&ctx, from: top(w.leaf, size), to: bottom(pair, size), t: (e - 0.1) / 0.6, tint: Theme.accent)
                comet(&ctx, from: top(w.leaf ^ 1, size), to: bottom(pair, size), t: (e - 0.3) / 0.6, tint: teal)
                ring(&ctx, center(pair, size), r: 14 + 24 * ((e - 0.9) / 0.6), tint: Theme.accent, a: 1 - (e - 0.9) / 0.6, on: e > 0.9)
                comet(&ctx, from: top(pair, size), to: bottom(6, size), t: (e - 0.9) / 0.6, tint: Theme.accent)
                comet(&ctx, from: top(4 + (w.leaf / 2) ^ 1, size), to: bottom(6, size), t: (e - 0.9) / 0.6, tint: teal)
                let k = (e - 1.55) / 0.9
                if k >= 0, k <= 1 {
                    let c = center(6, size)
                    let tint = ok ? Theme.accent : Theme.alert
                    ring(&ctx, c, r: 20 + 50 * k, tint: tint, a: 1 - k)
                    ring(&ctx, c, r: 20 + 30 * k, tint: tint, a: 0.8 * (1 - k))
                    if !ok {
                        for j in 0..<10 {
                            let ang = Double(j) / 10 * 2 * .pi
                            var sp = Path()
                            sp.move(to: CGPoint(x: c.x + cos(ang) * 22, y: c.y + sin(ang) * 22))
                            sp.addLine(to: CGPoint(x: c.x + cos(ang) * (26 + 22 * k), y: c.y + sin(ang) * (26 + 22 * k)))
                            ctx.stroke(sp, with: .color(Theme.alert.opacity(1 - k)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                    }
                    ctx.draw(Text(ok ? "✓" : "✕").font(.system(size: 22, weight: .bold)).foregroundStyle(tint.opacity(1 - max(0, k - 0.5) * 2)),
                             at: CGPoint(x: c.x, y: c.y - 32))
                }
            }
        }

        private func top(_ n: Int, _ size: CGSize) -> CGPoint { CGPoint(x: center(n, size).x, y: box(n, size).minY) }
        private func bottom(_ n: Int, _ size: CGSize) -> CGPoint { CGPoint(x: center(n, size).x, y: box(n, size).maxY) }

        private func ring(_ ctx: inout GraphicsContext, _ c: CGPoint, r: CGFloat, tint: Color, a: Double, on: Bool = true) {
            guard on, a > 0 else { return }
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(a)), lineWidth: 1.8)
        }

        private func comet(_ ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint, t: Double, tint: Color) {
            guard t > 0, t < 1.12 else { return }
            let head = min(t, 1)
            let fade = t > 1 ? max(0, 1 - (t - 1) / 0.12) : 1
            func pt(_ u: Double) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * u, y: a.y + (b.y - a.y) * u) }
            var prev = pt(head)
            for k in 1...10 {
                let p = pt(max(0, head - Double(k) * 0.03))
                let f = 1 - Double(k) / 10
                var seg = Path()
                seg.move(to: prev); seg.addLine(to: p)
                ctx.stroke(seg, with: .color(tint.opacity(0.8 * f * fade)), style: StrokeStyle(lineWidth: 1 + 2.6 * f, lineCap: .round))
                prev = p
            }
            let h = pt(head)
            ctx.drawLayer { g in
                g.addFilter(.blur(radius: 5))
                g.fill(Path(ellipseIn: CGRect(x: h.x - 8, y: h.y - 8, width: 16, height: 16)), with: .color(tint.opacity(0.75 * fade)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: h.x - 3, y: h.y - 3, width: 6, height: 6)), with: .color(Color.white.opacity(fade)))
        }
    }
}
