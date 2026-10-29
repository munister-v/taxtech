import Charts
import SwiftUI

/// Податки: огляд року за даними банку, зарплата, ФОП, податкова знижка, календар строків і ставки.
struct TaxesView: View {
    @Environment(AppModel.self) private var model
    @State private var tax = TaxStore()
    @State private var part = Part.overview
    @State private var income: [API.Transaction] = []
    @State private var deposits: [API.Deposit] = []
    @State private var editingRates = false

    enum Part: String { case overview, salary, fop, deduction, calendar }

    private var r: TaxRates { tax.rates }
    private var year: Int { Calendar.current.component(.year, from: .now) }
    private var yearIncome: [API.Transaction] {
        income.filter { $0.isIncome && Calendar.current.component(.year, from: $0.date) == year && $0.txType != "topup" }
    }
    private var incomeTotal: Double { yearIncome.reduce(0) { $0 + $1.amount } }
    private var interest: Double { deposits.reduce(0) { $0 + $1.interestEarned } }
    private var next: TaxDeadline? { TaxDeadline.upcoming(group: tax.group).first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ScreenTitle(title: "Податки") {
                        Button { editingRates = true } label: { RoundGlyph(symbol: "slider.horizontal.3") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ставки")
                    }
                    hero
                    SegmentBar(items: [(Part.overview, "Огляд"), (.salary, "Зарплата"), (.fop, "ФОП"),
                                       (.deduction, "Знижка"), (.calendar, "Календар")], selection: $part)
                    switch part {
                    case .overview: OverviewPart(rates: r, income: yearIncome, interest: interest, deposits: deposits)
                    case .salary: SalaryPart(rates: r)
                    case .fop: FopPart(tax: tax)
                    case .deduction: DeductionPart(tax: tax)
                    case .calendar: CalendarPart(group: tax.group)
                    }
                    Text("Ставки \(String(r.year)) року, 1 TAX = 1 гривня. Розрахунок орієнтовний.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                async let h = model.api.history(API.HistoryFilter())
                async let d = model.api.deposits()
                income = (try? await h) ?? []
                deposits = (try? await d) ?? []
            }
            .sheet(isPresented: $editingRates) { RatesView(tax: tax) }
        }
    }

    private var hero: some View {
        HeroPanel {
            HeroCaption("Доходи \(String(year))")
            BigAmount(value: incomeTotal, size: 44)
                .padding(.top, 6)
            HStack(alignment: .top, spacing: 16) {
                Stat(value: Format.money(incomeTotal * (r.pdfo + r.military)), label: "податки, якщо це зарплата", inverted: true)
                Stat(value: Format.money(TaxMath.depositTax(interest: interest, r)), label: "податок з депозитів", inverted: true)
            }
            .padding(.top, 16)
            if let next {
                HStack(alignment: .center, spacing: 12) {
                    GuillocheBadge(symbol: "calendar.badge.clock", tint: Theme.accent, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Найближчий строк").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        Text(next.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(next.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "uk_UA"))))
                            .font(.subheadline.weight(.semibold))
                        Text(CalendarPart.left(next.date)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(Theme.ink.opacity(0.06), in: .rect(cornerRadius: 16, style: .continuous))
                .padding(.top, 18)
            }
        }
    }
}

// MARK: Огляд

private struct OverviewPart: View {
    let rates: TaxRates
    let income: [API.Transaction]
    let interest: Double
    let deposits: [API.Deposit]

    private var byMonth: [(month: Date, sum: Double)] {
        Dictionary(grouping: income) { Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.month < $1.month }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !byMonth.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    BlockTitle("Доходи по місяцях")
                    Surface {
                        Chart(byMonth, id: \.month) { m in
                            BarMark(x: .value("Місяць", m.month, unit: .month), y: .value("Сума", m.sum))
                                .foregroundStyle(m.month == byMonth.last?.month ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.ink.opacity(0.78)))
                                .cornerRadius(4)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Locale(identifier: "uk_UA")))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                                AxisGridLine().foregroundStyle(Theme.line)
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 160)
                        .padding(16)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                BlockTitle("Ставки \(String(rates.year))")
                Surface {
                    rate("ПДФО з зарплати та інших доходів", percent(rates.pdfo))
                    Rule()
                    rate("Військовий збір", percent(rates.military))
                    Rule()
                    rate("ЄСВ роботодавця чи ФОП", percent(rates.esv))
                    Rule()
                    rate("Проценти за депозитом", percent(rates.pdfo + rates.military))
                    Rule()
                    rate("Мінімальна зарплата", Format.money(rates.minWage))
                    Rule()
                    rate("Прожитковий мінімум", Format.money(rates.subsistence))
                }
            }
            if !deposits.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    BlockTitle("Депозити")
                    Surface {
                        ForEach(Array(deposits.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Rule() }
                            AmountRow(title: "\(Format.money(d.amount)) під \(String(format: "%.0f", d.interestRate))%",
                                      subtitle: "проценти \(Format.money(d.interestEarned)), податок \(Format.money(TaxMath.depositTax(interest: d.interestEarned, rates)))",
                                      amount: Format.money(d.interestEarned - TaxMath.depositTax(interest: d.interestEarned, rates)))
                        }
                    }
                    Text("Податок з процентів банк утримує сам.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rate(_ t: String, _ v: String) -> some View { Line2(t, v) }
}

func percent(_ v: Double) -> String {
    let p = v * 100
    return (p == p.rounded() ? String(format: "%.0f", p) : String(format: "%.1f", p).replacingOccurrences(of: ".", with: ",")) + "%"
}

// MARK: Зарплата

private struct SalaryPart: View {
    let rates: TaxRates
    @State private var amount: Double = 30_000
    @State private var fromNet = false

    var body: some View {
        let gross = fromNet ? TaxMath.gross(forNet: amount, rates) : amount
        let s = TaxMath.salary(gross: gross, rates)
        VStack(alignment: .leading, spacing: 18) {
            SegmentBar(items: [(false, "Нараховано"), (true, "На руки")], selection: $fromNet)
            MoneyField(title: fromNet ? "Хочу на руки на місяць" : "Зарплата до податків на місяць", value: $amount)
            HeroPanel {
                HeroCaption(fromNet ? "Треба нарахувати" : "На руки")
                BigAmount(value: fromNet ? s.gross : s.net, size: 32).padding(.top, 6)
                SplitBar(parts: [("На руки", s.net), ("ПДФО", s.pdfo), ("ВЗ", s.military)], inverted: true)
                    .padding(.top, 16)
            }
            Surface {
                Line2("Нараховано", Format.money(s.gross))
                Rule()
                Line2("ПДФО \(percent(rates.pdfo))", "−" + Format.money(s.pdfo))
                Rule()
                Line2("Військовий збір \(percent(rates.military))", "−" + Format.money(s.military))
                Rule()
                Line2("На руки", Format.money(s.net))
            }
            VStack(alignment: .leading, spacing: 12) {
                BlockTitle("Роботодавець платить")
                Surface {
                    Line2("ЄСВ \(percent(rates.esv)) понад зарплату", Format.money(s.employerEsv))
                    Rule()
                    Line2("Повна вартість працівника", Format.money(s.employerCost))
                    Rule()
                    Line2("Частка податків у вартості", percent((s.employerCost - s.net) / max(s.employerCost, 1)))
                }
            }
            HStack(spacing: 12) {
                Surface { Stat(value: Format.money(s.net * 12), label: "на руки за рік").padding(16) }
                Surface { Stat(value: Format.money((s.pdfo + s.military) * 12), label: "податків за рік").padding(16) }
            }
            if gross < rates.minWage {
                Text("Менше за мінімальну зарплату (\(Format.money(rates.minWage))) за повну ставку платити не можна.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: ФОП

private struct FopPart: View {
    @Bindable var tax: TaxStore
    @State private var income: Double = 1_200_000
    @State private var selected = FopGroup.third

    var body: some View {
        let r = tax.rates
        let f = TaxMath.fop(selected, income: income, r)
        let salary = TaxMath.salary(gross: income / 12, r)
        VStack(alignment: .leading, spacing: 18) {
            SegmentBar(items: FopGroup.allCases.map { ($0, $0.title) }, selection: $selected)
            Text(selected.who).font(.footnote).foregroundStyle(.secondary)
            MoneyField(title: "Дохід за рік", value: $income)
            HeroPanel {
                HeroCaption("Податки ФОП за рік")
                BigAmount(value: f.total, size: 32).padding(.top, 6)
                HStack(alignment: .top, spacing: 16) {
                    Stat(value: Format.money(f.total / 12), label: "у середньому на місяць", inverted: true)
                    Stat(value: percent(f.effective), label: "від доходу", inverted: true)
                }
                .padding(.top, 14)
                SplitBar(parts: [("Єдиний", f.single), ("ЄСВ", f.esv), ("ВЗ", f.military)], inverted: true)
                    .padding(.top, 16)
            }
            Surface {
                Line2("Єдиний податок", Format.money(f.single))
                Rule()
                Line2("ЄСВ «за себе»", Format.money(f.esv))
                Rule()
                Line2("Військовий збір", Format.money(f.military))
                Rule()
                Line2("Лишається", Format.money(income - f.total))
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Ліміт доходу").caption()
                    Spacer()
                    Text(Format.money(f.limit)).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                }
                Meter(value: f.limit > 0 ? income / f.limit : 0)
                Text(f.overLimit
                     ? "Дохід більший за ліміт групи: з наступного кварталу доведеться перейти на іншу групу або загальну систему."
                     : "Використано \(percent(income / max(f.limit, 1))) ліміту.")
                    .font(.footnote)
                    .foregroundStyle(f.overLimit ? Theme.ink : .secondary)
                    .fontWeight(f.overLimit ? .semibold : .regular)
            }
            VStack(alignment: .leading, spacing: 12) {
                BlockTitle("Порівняння із зарплатою")
                Surface {
                    Line2("ФОП: лишається за рік", Format.money(income - f.total))
                    Rule()
                    Line2("Працівник: на руки за рік", Format.money(salary.net * 12))
                    Rule()
                    Line2("Різниця", Format.money(income - f.total - salary.net * 12))
                }
                }
            Button(tax.group == selected ? "Це моя група - строки в календарі" : "Я ФОП цієї групи") {
                tax.group = tax.group == selected ? nil : selected
            }
            .buttonStyle(tax.group == selected ? AnyButtonStyle(InkButton()) : AnyButtonStyle(LineButton()))
        }
        .onAppear { if let g = tax.group { selected = g } }
    }
}

/// Обгортка, щоб обирати стиль кнопки за умовою.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: Податкова знижка

private struct DeductionPart: View {
    @Bindable var tax: TaxStore
    @State private var salaryYear: Double = 360_000
    @State private var adding = false

    var body: some View {
        let r = tax.rates
        let eligible = tax.deductions.reduce(0) { $0 + $1.amount }
        let refund = TaxMath.refund(eligible: eligible, salaryYear: salaryYear, r)
        VStack(alignment: .leading, spacing: 18) {
            MoneyField(title: "Зарплата до податків за рік", value: $salaryYear)
            HeroPanel {
                HeroCaption("Можна повернути")
                BigAmount(value: refund, size: 34).padding(.top, 6)
                HStack(alignment: .top, spacing: 16) {
                    Stat(value: Format.money(eligible), label: "витрати", inverted: true)
                    Stat(value: Format.money(salaryYear * r.pdfo), label: "ПДФО за рік", inverted: true)
                }
                .padding(.top, 14)
            }
            HStack {
                BlockTitle("Витрати")
                Spacer()
                Button { adding = true } label: { Label("Додати", systemImage: "plus") }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            if tax.deductions.isEmpty {
                Text("Витрат ще немає.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Surface {
                    ForEach(Array(tax.deductions.enumerated()), id: \.element.id) { i, d in
                        if i > 0 { Rule() }
                        HStack {
                            AmountRow(title: d.kind.title, subtitle: d.note.isEmpty ? "18% повернуть: \(Format.money(d.amount * r.pdfo))" : d.note,
                                      amount: Format.money(d.amount))
                            Button { tax.deductions.removeAll { $0.id == d.id } } label: {
                                Image(systemName: "xmark").font(.footnote).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 14)
                            .accessibilityLabel("Прибрати")
                        }
                    }
                }
            }
            Text("Декларація - до 31 грудня наступного року. Навчання - до \(Format.money(TaxMath.educationLimitPerMonth(r))) на місяць.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .sheet(isPresented: $adding) { NewDeductionView { tax.deductions.append($0) } }
    }
}

private struct NewDeductionView: View {
    @Environment(\.dismiss) private var dismiss
    let add: (Deduction) -> Void
    @State private var kind = Deduction.Kind.education
    @State private var amount: Double?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    Picker("Витрата", selection: $kind) { ForEach(Deduction.Kind.allCases) { Text($0.title).tag($0) } }
                    TextField("Сума за рік, TAX", value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField("Нотатка: заклад, банк, договір", text: $note)
                } footer: {
                    Text(kind.hint)
                }
                FormAction(title: "Додати", disabled: (amount ?? 0) <= 0) {
                    add(Deduction(kind: kind, amount: amount ?? 0, note: note))
                    dismiss()
                }
            }
            .labForm()
            .navigationTitle("Витрата для знижки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Календар

private struct CalendarPart: View {
    let group: FopGroup?

    static func left(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: date).day ?? 0
        return days == 0 ? "сьогодні" : days == 1 ? "завтра" : "за \(days) дн."
    }

    var body: some View {
        let list = TaxDeadline.upcoming(group: group)
        let byMonth = Dictionary(grouping: list) { Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
            .sorted { $0.key < $1.key }
        VStack(alignment: .leading, spacing: 18) {
            Text(group.map { "Строки для фізособи і ФОП, \($0.title.lowercased())." } ?? "Строки для фізособи. Оберіть групу у вкладці ФОП, щоб додати строки підприємця.")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(byMonth, id: \.key) { month, items in
                VStack(alignment: .leading, spacing: 10) {
                    BlockTitle(BankText.monthYear(month))
                    Surface {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Rule() }
                            HStack(alignment: .top, spacing: 14) {
                                VStack(spacing: 0) {
                                    Text(d.date.formatted(.dateTime.day())).font(.title3.weight(.bold)).monospacedDigit()
                                    Text(d.date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "uk_UA"))))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(width: 40)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(d.title).font(.subheadline.weight(.semibold))
                                    Text(d.detail).font(.footnote).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Text(Self.left(d.date)).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(14)
                        }
                    }
                }
            }
        }
    }
}

// MARK: Ставки

private struct RatesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var tax: TaxStore

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    field("Мінімальна зарплата, TAX", \.minWage)
                    field("Прожитковий мінімум, TAX", \.subsistence)
                } header: {
                    Text("На 1 січня")
                }
                Section("Ставки, частки від 1") {
                    field("ПДФО", \.pdfo)
                    field("Військовий збір", \.military)
                    field("ЄСВ", \.esv)
                    field("3 група, ставка", \.group3Rate)
                    field("3 група з ПДВ, ставка", \.group3VatRate)
                    field("ВЗ 3 групи, від доходу", \.militaryFop3Rate)
                }
                Section {
                    Button("Повернути ставки \(String(TaxRates.default.year)) року") { tax.rates = .default }
                }
            }
            .labForm()
            .navigationTitle("Ставки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }

    private func field(_ title: String, _ key: WritableKeyPath<TaxRates, Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: Binding(get: { tax.rates[keyPath: key] }, set: { tax.rates[keyPath: key] = $0 }),
                      format: .number.precision(.fractionLength(0...3)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
    }
}
