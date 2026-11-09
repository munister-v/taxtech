import SwiftUI

/// Карта мережі: рахунки як вузли, перекази як комети. Шахрайство червоне: якщо його зупинено,
/// комета розбивається, якщо ні, долітає й лишає червоний слід. Бан - ударна хвиля, кліринг - спалах між банками.

struct MapNode: Identifiable {
    enum Role { case account, hub, you }
    let id: Int
    var pos: CGPoint
    var label: String
    var role: Role = .account
    /// 0...1: від розміру балансу
    var weight = 0.5
    var banned = false
    var strikes = 0
    var pending = false
    var parent: Int?
}

struct MapFlow: Identifiable {
    enum Kind { case ok, auto, interbank, blocked, ban, pulse, settle }
    let id: Int
    var kind: Kind
    var from: Int
    var to: Int
    var fraud = false
    /// де зупиняється заблокований переказ: частка шляху
    var stop = 0.55
}

@MainActor
final class MapPulses {
    struct Item { let flow: MapFlow; let start: TimeInterval }
    private(set) var items: [Item] = []
    private(set) var lastID = 0

    static func duration(_ f: MapFlow) -> Double {
        switch f.kind {
        case .ok, .auto: 0.9 + 0.6
        case .interbank: 1.3 + 0.6
        case .blocked: 0.7 * f.stop + 0.7
        case .ban: 1.4
        case .pulse: 0.9
        case .settle: 1.8
        }
    }

    func ingest(_ flows: [MapFlow], now: TimeInterval, stagger: Double = 0.14) {
        if let top = flows.map(\.id).max(), top < lastID { lastID = 0 }
        let fresh = flows.filter { $0.id > lastID }
        guard !fresh.isEmpty else { return }
        lastID = fresh.map(\.id).max() ?? lastID
        for (i, f) in fresh.enumerated() {
            items.append(Item(flow: f, start: now + min(Double(i) * stagger, 1.4)))
        }
    }

    func prune(now: TimeInterval) {
        items.removeAll { now - $0.start > Self.duration($0.flow) + 0.2 }
    }

}

struct NetworkMap: View {
    let nodes: [MapNode]
    let flows: [MapFlow]
    var aspect = 0.95
    var onTap: (Int) -> Void = { _ in }

    @State private var pulses = MapPulses()
    @State private var seen = 0

    private let teal = Color(red: 0.50, green: 0.80, blue: 0.82)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                draw(&ctx, size, now: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .aspectRatio(1 / aspect, contentMode: .fit)
        .contentShape(.rect)
        .overlay { GeometryReader { g in Color.clear.contentShape(.rect).onTapGesture { p in tap(p, g.size) } } }
        .onChange(of: flows.last?.id ?? 0) { _, _ in
            pulses.ingest(flows, now: Date.timeIntervalSinceReferenceDate)
        }
        .accessibilityElement()
        .accessibilityLabel(L("Карта мережі").s)
    }

    private func tap(_ p: CGPoint, _ size: CGSize) {
        var best: (Int, CGFloat)?
        for n in nodes {
            let d = hypot(point(n.pos, size).x - p.x, point(n.pos, size).y - p.y)
            if d < 30, d < (best?.1 ?? .infinity) { best = (n.id, d) }
        }
        if let b = best { onTap(b.0) }
    }

    private func point(_ u: CGPoint, _ size: CGSize) -> CGPoint { CGPoint(x: u.x * size.width, y: u.y * size.height) }

    private func radius(_ n: MapNode) -> CGFloat {
        switch n.role {
        case .hub: 15
        case .you: 17
        case .account: 6 + 5 * n.weight
        }
    }

    // MARK: Малювання

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, now: TimeInterval) {
        pulses.prune(now: now)
        let pos = nodes.map { point($0.pos, size) }
        func at(_ i: Int) -> CGPoint { i >= 0 && i < pos.count ? pos[i] : .zero }

        // спиці й трикутник банків
        for n in nodes {
            guard let p = n.parent, p < pos.count else { continue }
            var line = Path()
            line.move(to: pos[n.id]); line.addLine(to: pos[p])
            ctx.stroke(line, with: .color(Theme.ink.opacity(0.10)), lineWidth: 1)
        }
        let hubs = nodes.filter { $0.role == .hub }.map(\.id)
        if hubs.count > 1 {
            var tri = Path()
            tri.move(to: pos[hubs[0]])
            for h in hubs.dropFirst() { tri.addLine(to: pos[h]) }
            tri.closeSubpath()
            ctx.stroke(tri, with: .color(Theme.ink.opacity(0.08)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        }

        // сяйво під вузлами від свіжих прильотів
        ctx.drawLayer { glow in
            glow.addFilter(.blur(radius: 9))
            for it in pulses.items {
                let age = now - it.start
                let f = it.flow
                guard age >= 0 else { continue }
                switch f.kind {
                case .ok, .auto, .interbank:
                    let arrive = f.kind == .interbank ? 1.3 : 0.9
                    let u = (age - arrive) / 0.6
                    if u >= 0, u <= 1 {
                        glow.fill(Path(ellipseIn: CGRect(x: at(f.to).x - 16, y: at(f.to).y - 16, width: 32, height: 32)),
                                  with: .color(color(f).opacity(0.55 * (1 - u))))
                    }
                case .ban:
                    let u = min(age / 1.4, 1)
                    glow.fill(Path(ellipseIn: CGRect(x: at(f.from).x - 26, y: at(f.from).y - 26, width: 52, height: 52)),
                              with: .color(Theme.alert.opacity(0.5 * (1 - u))))
                default: break
                }
            }
        }

        // вузли
        for n in nodes { drawNode(&ctx, n, pos[n.id]) }

        // комети й вибухи
        for it in pulses.items {
            let age = now - it.start
            if age < 0 { continue }
            drawFlow(&ctx, it.flow, age, pos, hubs)
        }
    }

    private func color(_ f: MapFlow) -> Color {
        if f.fraud { return Theme.alert }
        switch f.kind {
        case .auto: return Color.white
        case .interbank: return teal
        case .blocked, .ban: return Theme.alert
        default: return Theme.accent
        }
    }

    private func drawNode(_ ctx: inout GraphicsContext, _ n: MapNode, _ p: CGPoint) {
        let r = radius(n)
        let rect = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        switch n.role {
        case .hub:
            ctx.fill(Path(ellipseIn: rect), with: .color(Theme.accent.opacity(0.12)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.accent.opacity(0.7)), lineWidth: 1.4)
            ctx.draw(Text(n.label).font(Theme.ui(13, .semibold)).foregroundStyle(Theme.accent), at: p)
        case .you:
            ctx.fill(Path(ellipseIn: rect), with: .color(Theme.accent))
            ctx.draw(Text("TU").font(Theme.ui(9, .heavy)).foregroundStyle(Color.black.opacity(0.75)), at: p)
            if !n.label.isEmpty {
                ctx.draw(Text(n.label).font(Theme.ui(10, .medium).monospacedDigit()).foregroundStyle(Theme.ink.opacity(0.7)),
                         at: CGPoint(x: p.x, y: p.y + r + 10))
            }
        case .account:
            if n.banned {
                ctx.fill(Path(ellipseIn: rect), with: .color(Theme.alert.opacity(0.9)))
                var x = Path()
                let k = r * 0.5
                x.move(to: CGPoint(x: p.x - k, y: p.y - k)); x.addLine(to: CGPoint(x: p.x + k, y: p.y + k))
                x.move(to: CGPoint(x: p.x + k, y: p.y - k)); x.addLine(to: CGPoint(x: p.x - k, y: p.y + k))
                ctx.stroke(x, with: .color(.white), lineWidth: 1.6)
            } else {
                ctx.fill(Path(ellipseIn: rect), with: .color(Theme.ink.opacity(0.14)))
                ctx.stroke(Path(ellipseIn: rect), with: .color(Theme.accent.opacity(0.55)), lineWidth: 1)
                if n.strikes > 0 {
                    let ring = rect.insetBy(dx: -3.5, dy: -3.5)
                    var arc = Path()
                    arc.addArc(center: p, radius: ring.width / 2, startAngle: .degrees(-90),
                               endAngle: .degrees(-90 + 360 * Double(min(n.strikes, 3)) / 3), clockwise: false)
                    ctx.stroke(arc, with: .color(Theme.alert), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            if n.pending {
                ctx.fill(Path(ellipseIn: CGRect(x: p.x + r - 2, y: p.y - r - 2, width: 5, height: 5)), with: .color(teal))
            }
            ctx.draw(Text(n.label).font(Theme.mono(8.5, .medium)).foregroundStyle(Theme.ink.opacity(n.banned ? 0.8 : 0.45)),
                     at: CGPoint(x: p.x, y: p.y + r + (n.strikes > 0 ? 12 : 9)))
        }
    }

    /// Точка на дузі від a до b: дуга вигнута вбік, щоб зустрічні перекази йшли різними шляхами.
    private func curve(_ a: CGPoint, _ b: CGPoint, _ t: Double, bend: Double = 0.16) -> CGPoint {
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let dx = b.x - a.x, dy = b.y - a.y
        let sign: CGFloat = a.x + a.y * 1.3 < b.x + b.y * 1.3 ? 1 : -1
        let c = CGPoint(x: mid.x - dy * bend * sign, y: mid.y + dx * bend * sign)
        let u = 1 - t
        return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
    }

    private func comet(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, head t: Double, tint: Color, fade: Double = 1) {
        let steps = 14
        var prev = curve(a, b, t)
        for k in 1...steps {
            let tk = max(0, t - Double(k) * 0.022)
            let p = curve(a, b, tk)
            let f = 1 - Double(k) / Double(steps)
            var seg = Path()
            seg.move(to: prev); seg.addLine(to: p)
            ctx.stroke(seg, with: .color(tint.opacity(0.75 * f * fade)), style: StrokeStyle(lineWidth: 1 + 2.4 * f, lineCap: .round))
            prev = p
        }
        let h = curve(a, b, t)
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: 5))
            g.fill(Path(ellipseIn: CGRect(x: h.x - 8, y: h.y - 8, width: 16, height: 16)), with: .color(tint.opacity(0.7 * fade)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: h.x - 3, y: h.y - 3, width: 6, height: 6)), with: .color(Color.white.opacity(fade)))
    }

    private func ring(_ ctx: inout GraphicsContext, _ c: CGPoint, r: CGFloat, tint: Color, alpha: Double, width: CGFloat = 1.6) {
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(max(alpha, 0))), lineWidth: width)
    }

    private func drawFlow(_ ctx: inout GraphicsContext, _ f: MapFlow, _ age: Double, _ pos: [CGPoint], _ hubs: [Int]) {
        func at(_ i: Int) -> CGPoint { i >= 0 && i < pos.count ? pos[i] : .zero }
        let tint = color(f)
        switch f.kind {
        case .ok, .auto, .interbank:
            let travel = f.kind == .interbank ? 1.3 : 0.9
            let u = min(age / travel, 1)
            let eased = u * u * (3 - 2 * u)
            if age <= travel + 0.25 {
                comet(&ctx, at(f.from), at(f.to), head: eased, tint: tint, fade: age > travel ? max(0, 1 - (age - travel) / 0.25) : 1)
            }
            let r = (age - travel) / 0.6
            if r >= 0, r <= 1 {
                ring(&ctx, at(f.to), r: 7 + 20 * r, tint: tint, alpha: 1 - r)
                if f.fraud { ring(&ctx, at(f.to), r: 5 + 30 * r, tint: Theme.alert, alpha: 0.7 * (1 - r), width: 1) }
            }
        case .blocked:
            let travel = 0.7 * f.stop
            let u = min(age / travel, 1)
            let eased = u * u * (3 - 2 * u)
            let a = at(f.from), b = at(f.to)
            if age <= travel { comet(&ctx, a, b, head: eased * f.stop, tint: tint) }
            let e = (age - travel) / 0.7
            if e >= 0, e <= 1 {
                let c = curve(a, b, f.stop)
                let ease = 1 - pow(1 - e, 3)
                for k in 0..<9 {
                    let ang = Double(k) / 9 * 2 * .pi + 0.3
                    var s = Path()
                    s.move(to: CGPoint(x: c.x + cos(ang) * (4 + 6 * ease), y: c.y + sin(ang) * (4 + 6 * ease)))
                    s.addLine(to: CGPoint(x: c.x + cos(ang) * (6 + 22 * ease), y: c.y + sin(ang) * (6 + 22 * ease)))
                    ctx.stroke(s, with: .color(Theme.alert.opacity(1 - e)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                ring(&ctx, c, r: 5 + 24 * ease, tint: Theme.alert, alpha: 0.8 * (1 - e))
                var x = Path()
                let k: CGFloat = 5
                x.move(to: CGPoint(x: c.x - k, y: c.y - k)); x.addLine(to: CGPoint(x: c.x + k, y: c.y + k))
                x.move(to: CGPoint(x: c.x + k, y: c.y - k)); x.addLine(to: CGPoint(x: c.x - k, y: c.y + k))
                ctx.stroke(x, with: .color(Color.white.opacity(1 - e)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        case .ban:
            let c = at(f.from)
            for k in 0..<3 {
                let e = (age - Double(k) * 0.22) / 1.0
                guard e >= 0, e <= 1 else { continue }
                ring(&ctx, c, r: 10 + 56 * (1 - pow(1 - e, 2)), tint: Theme.alert, alpha: 0.9 * (1 - e), width: 2.2 - Double(k) * 0.5)
            }
        case .pulse:
            let e = age / 0.9
            if e <= 1 { ring(&ctx, at(f.from), r: 14 + 34 * e, tint: Theme.accent, alpha: 1 - e) }
        case .settle:
            let e = age / 1.8
            guard e <= 1, hubs.count > 1 else { return }
            let bright = sin(min(e, 1) * .pi)
            for i in hubs.indices {
                let a = at(hubs[i]), b = at(hubs[(i + 1) % hubs.count])
                var line = Path()
                line.move(to: a); line.addLine(to: b)
                ctx.stroke(line, with: .color(Theme.accent.opacity(0.9 * bright)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6], dashPhase: -age * 40))
                ring(&ctx, a, r: 16 + 22 * e, tint: Theme.accent, alpha: 0.8 * (1 - e))
            }
            let c = CGPoint(x: hubs.map { at($0).x }.reduce(0, +) / Double(hubs.count), y: hubs.map { at($0).y }.reduce(0, +) / Double(hubs.count))
            ctx.draw(Text(L("Кліринг").s).font(Theme.ui(11, .semibold)).foregroundStyle(Theme.accent.opacity(bright)), at: c)
        }
    }
}
