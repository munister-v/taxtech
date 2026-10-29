import QuickLook
import Charts
import SwiftUI

struct TransactionDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let tx: API.Transaction
    @State private var note = ""
    @State private var screen = Screen()
    @State private var receipt: URL?
    @State private var preview: URL?
    @State private var copied = false
    @State private var document: API.DocumentRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HeroPanel {
                        GuillocheRibbon(label: "КВИТАНЦІЯ · TAXTECH").padding(.bottom, 16)
                        VStack(spacing: 10) {
                            TxGlyph(tx: tx, size: 76)
                            Text(TransactionRow(tx: tx).title)
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Text((tx.isIncome ? "+" : "−") + Format.money(tx.amount))
                                .font(.system(size: 42, weight: .semibold, design: .serif)).monospacedDigit()
                                .minimumScaleFactor(0.5).lineLimit(1)
                                .foregroundStyle(tx.isIncome ? Color.green : Theme.ink)
                            Label("Виконано", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(.green)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.green.opacity(0.14), in: .capsule)
                                .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 0.6))
                        }
                        .frame(maxWidth: .infinity)
                        Perforation().padding(.top, 14)
                        VStack(spacing: 0) {
                            LeaderRow(title: "Вид", value: BankText.type(tx.txType))
                            LeaderRow(title: "Коли", value: tx.date.formatted(date: .long, time: .shortened))
                            if let r = tx.relatedAccount { LeaderRow(title: tx.isIncome ? "Від" : "Кому", value: r) }
                            LeaderRow(title: "Номер операції", value: "№ " + String(format: "%08d", tx.id))
                        }
                        .padding(.horizontal, -18)
                        Microprint().padding(.top, 8)
                    }

                    Button {
                        if let receipt { preview = receipt; return }
                        Task {
                            await screen.run {
                                receipt = try await model.api.document("transactions/\(tx.id)/receipt", name: "Квитанція \(tx.id).pdf")
                                preview = receipt
                            }
                        }
                    } label: {
                        Label(receipt == nil ? "Переглянути квитанцію" : "Відкрити квитанцію", systemImage: "doc.richtext")
                    }
                    .buttonStyle(InkButton())
                    .disabled(screen.busy)

                    if let document {
                        Surface { VerifySeal(doc: document).padding(18) }
                    }

                    if let h = tx.hash {
                        Surface {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Хеш запису").font(.footnote).foregroundStyle(.secondary)
                                Text(h.prefix(32) + "\n" + h.suffix(32))
                                    .font(.footnote.monospaced()).textSelection(.enabled)
                                Button(copied ? "Скопійовано" : "Скопіювати хеш") {
                                    UIPasteboard.general.string = h
                                    copied = true
                                }
                                .font(.footnote.weight(.semibold)).foregroundStyle(Theme.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                        }
                    }

                    Surface {
                        TextField("Додайте нотатку", text: $note, axis: .vertical)
                            .lineLimit(1...4)
                            .padding(16)
                    }

                    if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }

                    if note != (tx.note ?? "") {
                        Button("Зберегти нотатку") {
                            Task { if await screen.run({ try await model.api.setNote(tx.id, note) }) { dismiss() } }
                        }
                        .buttonStyle(LineButton())
                        .disabled(screen.busy)
                    }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .navigationTitle("Операція")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .onAppear { note = tx.note ?? "" }
            .task { document = try? await model.api.receiptDocument(tx.id) }
        }
        .quickLookPreview($preview)
        .presentationDetents([.medium, .large])
    }
}

// MARK: Аналітика

struct AnalyticsView: View {
    @Environment(AppModel.self) private var model
    @State private var summary: API.Analytics?
    @State private var balance: [API.BalancePoint] = []
    @State private var insights: [API.Insight] = []
    @State private var velocity: API.Velocity?
    @State private var recipients: [API.Recipient] = []
    @State private var days = 30

    private static let months = ["01": "січ", "02": "лют", "03": "бер", "04": "кві", "05": "тра", "06": "чер",
                                 "07": "лип", "08": "сер", "09": "вер", "10": "жов", "11": "лис", "12": "гру"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let s = summary {
                    hero(s)
                    if let velocity { pace(velocity) }
                    monthly(s)
                }
                balanceChart
                if let s = summary { byType(s) }
                if !recipients.isEmpty { recipientList }
                if !insights.isEmpty { insightList }
                NavigationLink { AchievementsView() } label: {
                    HStack {
                        Text("Досягнення")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.gutter)
        }
        .screenBackground()
        .navigationTitle("Аналітика")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: days) { Task { balance = (try? await model.api.balanceHistory(days: days)) ?? [] } }
    }

    private func load() async {
        async let s = model.api.analytics()
        async let b = model.api.balanceHistory(days: days)
        async let i = model.api.insights()
        async let v = model.api.velocity()
        async let r = model.api.topRecipients()
        summary = try? await s
        balance = (try? await b) ?? []
        insights = (try? await i) ?? []
        velocity = try? await v
        recipients = (try? await r) ?? []
    }

    private func hero(_ s: API.Analytics) -> some View {
        let out = s.currentMonth.totalOut, prev = s.prevMonth.totalOut
        let delta = prev > 0 ? (out - prev) / prev * 100 : nil
        return VStack(spacing: 6) {
            Text("Витрати цього місяця").caption()
            Text(Format.money(out)).font(Theme.balance()).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            if let delta {
                Text("\(delta >= 0 ? "+" : "−")\(Int(abs(delta)))% до минулого місяця")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("Надійшло \(Format.money(s.currentMonth.totalIn)), операцій: \(s.currentMonth.txCount)")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func monthly(_ s: API.Analytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Місяці")
            Surface {
                Chart {
                    ForEach(s.monthly) { m in
                        BarMark(x: .value("Місяць", Self.months[String(m.month.suffix(2))] ?? m.month),
                                y: .value("Сума", m.totalIn))
                            .foregroundStyle(by: .value("Рух", "Надійшло"))
                            .position(by: .value("Рух", "Надійшло"))
                        BarMark(x: .value("Місяць", Self.months[String(m.month.suffix(2))] ?? m.month),
                                y: .value("Сума", m.totalOut))
                            .foregroundStyle(by: .value("Рух", "Витрачено"))
                            .position(by: .value("Рух", "Витрачено"))
                    }
                }
                .chartForegroundStyleScale(["Надійшло": Theme.ink.opacity(0.3), "Витрачено": Theme.ink])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                        AxisGridLine().foregroundStyle(Theme.line)
                        AxisValueLabel()
                    }
                }
                .frame(height: 190)
                .padding(16)
            }
        }
    }

    private var balanceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Баланс", trailing: "\(days) днів")
            Surface {
                VStack(spacing: 12) {
                    Chart(balance) { p in
                        LineMark(x: .value("День", BankText.day(p.day) ?? .now, unit: .day), y: .value("Баланс", p.balance))
                            .foregroundStyle(Theme.ink)
                            .interpolationMethod(.monotone)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "uk_UA")))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                            AxisGridLine().foregroundStyle(Theme.line)
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 160)
                    Picker("Період", selection: $days) {
                        Text("14 днів").tag(14)
                        Text("30 днів").tag(30)
                        Text("90 днів").tag(90)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
            }
        }
    }

    private func byType(_ s: API.Analytics) -> some View {
        let out = s.byType.filter { $0.direction == "out" }.sorted { $0.total > $1.total }
        let total = max(out.reduce(0) { $0 + $1.total }, 1)
        return VStack(alignment: .leading, spacing: 12) {
            BlockTitle("На що йдуть гроші")
            Surface {
                ForEach(Array(out.enumerated()), id: \.element.id) { i, t in
                    if i > 0 { Rule() }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(BankText.type(t.txType))
                            Spacer()
                            Text("\(t.cnt) оп.").font(.footnote).foregroundStyle(.secondary)
                            Text(Format.money(t.total)).font(.body.weight(.semibold)).monospacedDigit()
                        }
                        Meter(value: t.total / total)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }
        }
    }

    /// Темп витрат: скільки в середньому на день і на скільки днів вистачить рахунку.
    private func pace(_ v: API.Velocity) -> some View {
        HStack(spacing: 0) {
            tile("на день", Format.money(v.avgDailySpend))
            Rectangle().fill(Theme.line).frame(width: Theme.hairline).padding(.vertical, 14)
            tile("вистачить", v.daysUntilZero.map { "\($0) дн." } ?? "-")
        }
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var recipientList: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Кому найбільше")
            Surface {
                ForEach(Array(recipients.prefix(5).enumerated()), id: \.element.id) { i, r in
                    if i > 0 { Rule() }
                    AmountRow(title: BankText.recipient(r.relatedAccount), subtitle: "\(r.txCount) операцій", amount: Format.money(r.totalSent))
                }
            }
        }
    }

    private var insightList: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Спостереження")
            Surface {
                ForEach(Array(insights.enumerated()), id: \.offset) { i, ins in
                    if i > 0 { Rule() }
                    Text(ins.text).padding(16)
                }
            }
        }
    }
}

struct AchievementsView: View {
    @Environment(AppModel.self) private var model
    @State private var list: API.AchievementList?

    var body: some View {
        LabForm {
            if let list {
                Section { Line("Виконано", "\(list.done) з \(list.total)") }
                Section {
                    ForEach(list.achievements) { a in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.title).fontWeight(a.done ? .semibold : .regular)
                                Text(a.desc).font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if a.done { Image(systemName: "checkmark") }
                        }
                        .opacity(a.done ? 1 : 0.55)
                    }
                }
            }
        }
        .labForm()
        .navigationTitle("Досягнення")
        .navigationBarTitleDisplayMode(.inline)
        .task { list = try? await model.api.achievements() }
    }
}
