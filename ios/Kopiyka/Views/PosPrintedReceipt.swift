import CoreImage.CIFilterBuiltins
import SwiftUI

/// Нижній край чека зубчиками, як відрив на касовій стрічці.
private struct TornEdge: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let tooth: CGFloat = 8
        let n = max(1, Int(r.width / tooth))
        let w = r.width / CGFloat(n)
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: r.width, y: 0))
        p.addLine(to: CGPoint(x: r.width, y: r.height - tooth * 0.7))
        for i in stride(from: n, to: 0, by: -1) {
            let x = CGFloat(i) * w
            p.addLine(to: CGPoint(x: x - w / 2, y: r.height))
            p.addLine(to: CGPoint(x: x - w, y: r.height - tooth * 0.7))
        }
        p.closeSubpath()
        return p
    }
}

/// Справжній штрихкод Code 128 із RRN платежу: його прочитає будь-який сканер.
private struct Code128: View {
    let message: String

    var body: some View {
        if let img = Self.render(message) {
            Image(uiImage: img).interpolation(.none).resizable().frame(maxWidth: .infinity).frame(height: 50).blendMode(.multiply)
        }
    }

    private static let context = CIContext()
    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]

    static func render(_ text: String) -> UIImage? {
        if let hit = cache[text] { return hit }
        let f = CIFilter.code128BarcodeGenerator()
        f.message = Data(text.utf8)
        f.quietSpace = 4
        guard let out = f.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        let img = context.createCGImage(scaled, from: scaled.extent).map { UIImage(cgImage: $0) }
        if let img { cache[text] = img }
        return img
    }
}

/// Касовий чек, що виїжджає зі щілини термінала кроками, як із термодруку, відривається й нахиляється за пальцем.
struct PosPrintedReceipt: View {
    let payment: API.PosPayment
    let cardLast4: String?
    var symbol = "creditcard.fill"
    @State private var reveal: CGFloat = 0
    @State private var step = 0
    @State private var height: CGFloat = 520
    @State private var torn = false
    @State private var done = false
    @State private var drag = CGSize.zero
    @State private var shareImage: Image?

    private let paper = Color(red: 0.985, green: 0.978, blue: 0.955)
    private let ink = Color(red: 0.14, green: 0.14, blue: 0.15)
    private let steps = 22

    private var date: String {
        let d = payment.createdAt.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
        return d.formatted(.dateTime.day().month(.twoDigits).year().hour().minute().locale(Lang.current.locale))
    }

    private func digits(_ seed: String, _ n: Int) -> String {
        var h: UInt64 = 1469598103934665603
        for u in seed.utf8 { h = (h ^ UInt64(u)) &* 1099511628211 }
        return String(String(h).prefix(n)).padding(toLength: n, withPad: "0", startingAt: 0)
    }

    private var rows: [(String, String)] {
        var r: [(String, String)] = [
            (Tx("КАРТКА", "CARD", "КАРТА"), "**** **** **** " + (cardLast4 ?? payment.cardLast4 ?? "----")),
            (Tx("СПОСІБ", "ENTRY", "СПОСОБ"), payment.threeDs == true ? "ECOM 3-D SECURE" : "CONTACTLESS"),
            (Tx("КОД АВТОРИЗАЦІЇ", "AUTH CODE", "КОД АВТОРИЗАЦИИ"), payment.authCode ?? "-"),
            ("RRN", payment.rrn ?? "-"),
            ("MID", digits(payment.merchant ?? "", 8)),
            ("TID", digits("tid" + (payment.merchant ?? ""), 8)),
            ("STAN", String(format: "%06d", (payment.id ?? 1) % 1_000_000)),
        ]
        if let ms = payment.latencyMs { r.append((Tx("ЧАС ОБРОБКИ", "LATENCY", "ВРЕМЯ ОБРАБОТКИ"), "\(ms) ms")) }
        return r
    }

    var body: some View {
        VStack(spacing: 0) {
            slot.zIndex(1)
            ZStack(alignment: .top) {
                receipt
                    .offset(y: -height * (1 - reveal))
                    .rotationEffect(.degrees(torn ? -0.5 : 0), anchor: .bottomLeading)
                    .offset(y: torn ? 6 : 0)
                    .rotation3DEffect(.degrees(Double(drag.width) / 14), axis: (0, 1, 0), perspective: 0.6)
                    .rotation3DEffect(.degrees(Double(-drag.height) / 18), axis: (1, 0, 0), perspective: 0.6)
            }
            .padding(.bottom, 30)
            .clipped()
            .padding(.horizontal, 36)
            .padding(.top, -7)
            .padding(.bottom, 14)
            .contentShape(.rect)
            .gesture(DragGesture().onChanged { drag = $0.translation }.onEnded { _ in withAnimation(.spring(duration: 0.6, bounce: 0.5)) { drag = .zero } })
        }
        .overlay(alignment: .bottom) {
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview(Tx("Чек", "Receipt", "Чек"), image: shareImage)) {
                    Label(Tx("Поділитися чеком", "Share receipt", "Поделиться чеком"), systemImage: "square.and.arrow.up")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                .transition(.opacity)
            }
        }
        .task { await printReceipt() }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: step)
        .sensoryFeedback(.success, trigger: done) { _, new in new }
    }

    private var slot: some View {
        Capsule().fill(Color.black).frame(height: 14)
            .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.6), lineWidth: 1))
            .overlay {
                Capsule().fill(Theme.accent.opacity(step > 0 && !torn ? 0.9 : 0.15)).frame(height: 2).padding(.horizontal, 12)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
            .shadow(color: Theme.accent.opacity(torn ? 0.15 : 0.5), radius: 12)
            .padding(.horizontal, 24)
    }

    /// Друк кроками з паузами, як голівка термопринтера; наприкінці відрив.
    private func printReceipt() async {
        try? await Task.sleep(for: .milliseconds(250))
        for i in 1...steps {
            try? await Task.sleep(for: .milliseconds(i % 5 == 0 ? 120 : 55))
            withAnimation(.linear(duration: 0.07)) { reveal = CGFloat(i) / CGFloat(steps) }
            step = i
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { torn = true }
        try? await Task.sleep(for: .milliseconds(200))
        done = true
        shareImage = snapshot
    }

    @MainActor private var snapshot: Image {
        // не чіпає стан: рендер одноразовий, після друку
        let r = ImageRenderer(content: receipt.frame(width: 320).padding(20).background(Color.black))
        r.scale = 3
        return r.uiImage.map { Image(uiImage: $0) } ?? Image(systemName: "doc.text")
    }

    private var receipt: some View {
        VStack(spacing: 6) {
            Text((payment.merchant ?? "").uppercased()).font(.system(size: 15, weight: .bold, design: .monospaced)).tracking(0.8).multilineTextAlignment(.center)
            Text("ROMA · IT").font(.system(size: 10, design: .monospaced)).opacity(0.7)
            Text(date).font(.system(size: 10, design: .monospaced)).opacity(0.7)
            dash
            Text(Tx("ПРОДАЖ / SALE", "SALE", "ПРОДАЖА / SALE")).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(2)
            line(Tx("СУМА", "AMOUNT", "СУММА"), Format.money(payment.amount ?? 0))
            line(Tx("КОМІСІЯ ЕКВАЙРА", "ACQUIRER FEE", "КОМИССИЯ ЭКВАЙРА"), Format.money(payment.fee ?? 0))
            line(Tx("МАГАЗИН ОТРИМАЄ", "MERCHANT NET", "МАГАЗИН ПОЛУЧИТ"), Format.money(payment.net ?? 0))
            dash
            HStack(alignment: .firstTextBaseline) {
                Text(Tx("РАЗОМ", "TOTAL", "ИТОГО")).font(.system(size: 14, weight: .bold, design: .monospaced))
                Spacer()
                Text(Format.money(payment.amount ?? 0)).font(.system(size: 17, weight: .bold, design: .monospaced)).monospacedDigit()
            }
            dash
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in line(row.0, row.1) }
            dash
            Text("\(Tx("СХВАЛЕНО", "APPROVED", "ОДОБРЕНО")) · \(payment.responseCode)")
                .font(.system(size: 13, weight: .bold, design: .monospaced)).tracking(1.5)
                .padding(.vertical, 2)
            Code128(message: payment.rrn ?? "TAXTECH").padding(.top, 4)
            Text(payment.rrn ?? "").font(.system(size: 9, design: .monospaced)).tracking(2).opacity(0.7)
            Text(Tx("КОПІЯ ДЛЯ КЛІЄНТА", "CARDHOLDER COPY", "КОПИЯ КЛИЕНТА")).font(.system(size: 9, design: .monospaced)).tracking(1.5).padding(.top, 6)
            Text(Tx("Дякуємо за покупку", "Thank you", "Спасибо за покупку")).font(.system(size: 9, design: .monospaced)).opacity(0.7)
            Text("TAXTECH · " + Tx("навчальний платіж", "training payment", "учебный платёж")).font(.system(size: 8, design: .monospaced)).opacity(0.45)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(paper, in: TornEdge())
        .overlay(TornEdge().fill(LinearGradient(colors: [.black.opacity(0.03), .clear, .black.opacity(0.04)], startPoint: .leading, endPoint: .trailing)).allowsHitTesting(false))
        .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 + 20 }
    }

    private func line(_ t: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(t).font(.system(size: 10, design: .monospaced)).opacity(0.75)
            Spacer(minLength: 8)
            Text(v).font(.system(size: 11, weight: .medium, design: .monospaced)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var dash: some View {
        DashLine().stroke(ink.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
    }

    private struct DashLine: Shape {
        func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: r.midY)); p.addLine(to: CGPoint(x: r.width, y: r.midY)); return p }
    }
}
