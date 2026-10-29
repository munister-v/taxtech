import CoreImage.CIFilterBuiltins
import SwiftUI

// MARK: Єдине сховище документів

extension API {
    /// Квитанція чи виписка в реєстрі документів. Код і QR відкривають публічну перевірку.
    struct DocumentRecord: Decodable, Sendable, Identifiable, Hashable {
        let id: Int
        let kind: String
        let ref: String
        let code: String
        let title: String
        let amount: Double?
        let direction: String?
        let createdAt: String
        let verifyUrl: String
        let meta: Meta

        struct Meta: Decodable, Sendable, Hashable {
            let fromDate: String?
            let toDate: String?
            let period: String?
            let reportType: String?
            let count: Int?
            let totalIn: Double?
            let totalOut: Double?
        }

        var isReceipt: Bool { kind == "receipt" }
        var url: URL? { URL(string: verifyUrl) }
        /// Час у UTC без зони, як і в операціях.
        var date: Date {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return f.date(from: String(createdAt.prefix(19))) ?? .distantPast
        }

        /// Шлях, з якого сервер збирає PDF цього документа.
        var pdfPath: String {
            if isReceipt { return "transactions/\(ref)/receipt" }
            var q = ["report_type=\(meta.reportType ?? "detailed")"]
            if let f = meta.fromDate, !f.isEmpty { q.append("from_date=\(f)") }
            if let t = meta.toDate, !t.isEmpty { q.append("to_date=\(t)") }
            return "transactions/statement?" + q.joined(separator: "&")
        }

        var fileName: String { isReceipt ? "Квитанція \(code).pdf" : "Виписка \(code).pdf" }
    }

    func documents(kind: String? = nil) async throws -> [DocumentRecord] {
        let q = kind.map { "?kind=\($0)" } ?? ""
        let w: Wrapped<[DocumentRecord]> = try await send(request("documents" + q, method: "GET"))
        return w.data
    }

    /// Код квитанції операції: сервер видає його при першому зверненні й далі повертає той самий.
    func receiptDocument(_ txId: Int) async throws -> DocumentRecord {
        let w: Wrapped<DocumentRecord> = try await send(request("documents/receipt/\(txId)", method: "GET"))
        return w.data
    }
}

// MARK: QR

enum QR {
    /// Чорно-білий QR із посиланням, масштабований цілими пікселями - без розмиття.
    static func image(_ text: String, scale: CGFloat = 10) -> UIImage? {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8)
        f.correctionLevel = "Q"
        guard let out = f.outputImage?.transformed(by: .init(scaleX: scale, y: scale)),
              let cg = CIContext().createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// QR на білій плитці з золотими кутами: так він читається в будь-якій темі.
struct QRPlate: View {
    let text: String
    var size: CGFloat = 168

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white)
            if let img = QR.image(text) {
                Image(uiImage: img).interpolation(.none).resizable().scaledToFit()
                    .padding(14)
            }
            QRCorners().stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .padding(5)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .accessibilityLabel("QR-код перевірки документа")
    }
}

private struct QRCorners: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = 16
        for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0),
                               (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
            p.move(to: CGPoint(x: x + dx * l, y: y)); p.addLine(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y + dy * l))
        }
        return p
    }
}

// MARK: Печатка перевірки

/// Блок «Перевірка документа»: QR, код, відкриття сторінки перевірки, поширення посилання.
struct VerifySeal: View {
    let doc: API.DocumentRecord
    @State private var copied = false

    var body: some View {
        VStack(spacing: 14) {
            GuillocheRibbon(label: "ПЕРЕВІРКА · QR")
            QRPlate(text: doc.verifyUrl)
            VStack(spacing: 4) {
                Text("Код документа").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                Text(doc.code)
                    .font(.system(.title3, design: .monospaced).weight(.bold)).tracking(1.2)
                    .textSelection(.enabled).minimumScaleFactor(0.7).lineLimit(1)
            }
            Text("Наведіть камеру на QR або введіть код на сторінці перевірки: вона звіряє документ із реєстром і не показує особистих даних.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            HStack(spacing: 10) {
                if let url = doc.url {
                    Link(destination: url) {
                        Label("Перевірити онлайн", systemImage: "checkmark.shield")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(Theme.onAccent)
                            .background(Theme.accent, in: .rect(cornerRadius: 14, style: .continuous))
                    }
                    ShareLink(item: url, subject: Text(doc.title), message: Text("Код \(doc.code)")) {
                        Image(systemName: "square.and.arrow.up").font(.subheadline.weight(.semibold))
                            .frame(width: 48).padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Theme.accent.opacity(0.7), lineWidth: 1))
                    }
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Поділитися посиланням")
                }
            }
            Button(copied ? "Код скопійовано" : "Скопіювати код") {
                UIPasteboard.general.string = doc.code
                copied = true
            }
            .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Список документів

struct DocumentsView: View {
    @Environment(AppModel.self) private var model
    @State private var all: [API.DocumentRecord] = []
    @State private var loaded = false
    @State private var kind: Kind = .all
    @State private var selected: API.DocumentRecord?
    @State private var failed = false

    enum Kind: Hashable { case all, receipt, statement }

    private var rows: [API.DocumentRecord] {
        switch kind {
        case .all: all
        case .receipt: all.filter { $0.kind == "receipt" }
        case .statement: all.filter { $0.kind == "statement" }
        }
    }

    private var groups: [(day: Date, items: [API.DocumentRecord])] {
        let cal = Calendar.current
        return Dictionary(grouping: rows) { cal.startOfDay(for: $0.date) }
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeroPanel {
                    GuillocheRibbon(label: "СХОВИЩЕ ДОКУМЕНТІВ").padding(.bottom, 14)
                    HStack(alignment: .top, spacing: 12) {
                        count("Квитанції", all.filter { $0.isReceipt }.count)
                        count("Виписки", all.filter { !$0.isReceipt }.count)
                        count("Усього", all.count)
                    }
                    Perforation().padding(.top, 14)
                    Text("Кожен документ має власний код і QR. Перевірити його можна в інтернеті: сторінка звіряє запис із реєстром операцій.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 6)
                    Microprint().padding(.top, 10)
                }

                SegmentBar(items: [(Kind.all, "Усі"), (.receipt, "Квитанції"), (.statement, "Виписки")], selection: $kind)

                if loaded && rows.isEmpty {
                    Surface {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.viewfinder").font(.system(size: 34)).foregroundStyle(Theme.tint)
                            Text(failed ? "Не вдалося завантажити документи" : "Документів поки немає")
                                .font(.headline)
                            Text("Відкрийте операцію й натисніть «Переглянути квитанцію», або сформуйте виписку: вони з'являться тут.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(24)
                    }
                }

                ForEach(groups, id: \.day) { g in
                    DayRibbon(title: BankText.dayTitle(g.day), trailing: "\(g.items.count)")
                    Surface {
                        ForEach(Array(g.items.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Rule() }
                            Button { selected = d } label: { DocumentRow(doc: d) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Мої документи")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { DocumentDetailView(doc: $0) }
    }

    private func load() async {
        do { all = try await model.api.documents(); failed = false } catch { failed = true }
        loaded = true
    }

    private func count(_ title: String, _ n: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.system(size: 30, weight: .semibold, design: .serif)).monospacedDigit()
            Text(title.uppercased()).font(.system(size: 9.5, weight: .bold)).tracking(1.2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DocumentRow: View {
    let doc: API.DocumentRecord

    var body: some View {
        HStack(spacing: 14) {
            GuillocheBadge(symbol: doc.isReceipt ? "checkmark.seal.fill" : "doc.text.fill",
                           tint: doc.isReceipt ? .green : Theme.accent, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title).font(.body.weight(.medium)).lineLimit(2).minimumScaleFactor(0.85)
                Text(doc.code).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                if let a = doc.amount {
                    Text((doc.direction == "in" ? "+" : doc.direction == "out" ? "−" : "") + Format.money(a))
                        .font(.system(.callout, design: .serif).weight(.semibold)).monospacedDigit()
                        .lineLimit(1).fixedSize()
                        .foregroundStyle(doc.direction == "in" ? Color.green : Theme.ink)
                }
                Image(systemName: "qrcode").font(.footnote).foregroundStyle(Theme.tint)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .contentShape(.rect)
    }
}

// MARK: Документ

struct DocumentDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let doc: API.DocumentRecord
    @State private var screen = Screen()
    @State private var preview: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeroPanel {
                        GuillocheRibbon(label: doc.isReceipt ? "КВИТАНЦІЯ" : "ВИПИСКА").padding(.bottom, 14)
                        VStack(spacing: 8) {
                            GuillocheBadge(symbol: doc.isReceipt ? "checkmark.seal.fill" : "doc.text.fill",
                                           tint: doc.isReceipt ? .green : Theme.accent, size: 72)
                            Text(doc.title).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            if let a = doc.amount {
                                Text((doc.direction == "in" ? "+" : "−") + Format.money(a))
                                    .font(.system(size: 38, weight: .bold)).monospacedDigit()
                                    .minimumScaleFactor(0.5).lineLimit(1)
                                    .foregroundStyle(doc.direction == "in" ? Color.green : Theme.ink)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Perforation().padding(.top, 14)
                        VStack(spacing: 0) {
                            LeaderRow(title: "Вид", value: doc.isReceipt ? "Квитанція" : "Виписка")
                            LeaderRow(title: "Видано", value: doc.date.formatted(date: .long, time: .shortened))
                            if doc.isReceipt {
                                LeaderRow(title: "Операція", value: "№ " + String(format: "%08d", Int(doc.ref) ?? 0))
                            } else {
                                if let p = doc.meta.period { LeaderRow(title: "Період", value: p) }
                                if let n = doc.meta.count { LeaderRow(title: "Операцій", value: "\(n)") }
                                if let i = doc.meta.totalIn { LeaderRow(title: "Надійшло", value: Format.money(i)) }
                                if let o = doc.meta.totalOut { LeaderRow(title: "Витрачено", value: Format.money(o)) }
                            }
                        }
                        .padding(.horizontal, -18)
                        Microprint().padding(.top, 8)
                    }

                    Surface { VerifySeal(doc: doc).padding(18) }

                    Button {
                        Task {
                            await screen.run {
                                preview = try await model.api.document(doc.pdfPath, name: doc.fileName)
                            }
                        }
                    } label: {
                        Label("Відкрити PDF", systemImage: "doc.richtext")
                    }
                    .buttonStyle(InkButton())
                    .disabled(screen.busy)
                    if screen.busy { ProgressView() }
                    if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .navigationTitle(doc.isReceipt ? "Квитанція" : "Виписка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
        .quickLookPreview($preview)
        .presentationDetents([.large])
    }
}
