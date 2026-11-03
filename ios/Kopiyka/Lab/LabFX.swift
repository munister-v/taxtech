import SwiftUI

/// Общие эффекты для анимированных опытов: комета и расходящееся кольцо.
enum LabFX {
    static func ring(_ ctx: inout GraphicsContext, _ c: CGPoint, r: CGFloat, tint: Color, alpha: Double, width: CGFloat = 1.8) {
        guard alpha > 0, r > 0 else { return }
        ctx.stroke(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(alpha)), lineWidth: width)
    }

    /// Комета по прямой: t от 0 до 1 летит, до 1.12 гаснет.
    static func comet(_ ctx: inout GraphicsContext, from a: CGPoint, to b: CGPoint, t: Double, tint: Color) {
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

    static func sparks(_ ctx: inout GraphicsContext, _ c: CGPoint, k: Double, tint: Color, count: Int = 9) {
        guard k >= 0, k <= 1 else { return }
        for j in 0..<count {
            let ang = Double(j) / Double(count) * 2 * .pi + 0.3
            var sp = Path()
            sp.move(to: CGPoint(x: c.x + cos(ang) * (4 + 6 * k), y: c.y + sin(ang) * (4 + 6 * k)))
            sp.addLine(to: CGPoint(x: c.x + cos(ang) * (6 + 22 * k), y: c.y + sin(ang) * (6 + 22 * k)))
            ctx.stroke(sp, with: .color(tint.opacity(1 - k)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}
