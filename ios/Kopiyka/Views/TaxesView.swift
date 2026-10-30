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
                    ScreenTitle(title: L("Податки").s) {
                        Button { editingRates = true } label: { RoundGlyph(symbol: "slider.horizontal.3") }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L("Ставки").s)
                    }
                    hero
                    SegmentBar(items: [(Part.overview, L("Огляд").s), (.salary, L("Зарплата").s), (.fop, L("ФОП").s),
                                       (.deduction, L("Знижка").s), (.calendar, L("Календар").s)], selection: $part)
                    switch part {
                    case .overview: OverviewPart(rates: r, income: yearIncome, interest: interest, deposits: deposits)
                    case .salary: SalaryPart(rates: r)
                    case .fop: FopPart(tax: tax)
                    case .deduction: DeductionPart(tax: tax)
                    case .calendar: CalendarPart(group: tax.group)
                    }
                    Text(L("Ставки \(String(r.year)) року, 1 TAX = 1 гривня. Розрахунок орієнтовний.").s)
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
            HeroCaption(L("Доходи \(String(year))").s)
            BigAmount(value: incomeTotal, size: 44)
                .padding(.top, 6)
            HStack(alignment: .top, spacing: 16) {
                Stat(value: Format.money(incomeTotal * (r.pdfo + r.military)), label: L("податки, якщо це зарплата").s, inverted: true)
                Stat(value: Format.money(TaxMath.depositTax(interest: interest, r)), label: L("податок з депозитів").s, inverted: true)
            }
            .padding(.top, 16)
            if let next {
                HStack(alignment: .center, spacing: 12) {
                    GuillocheBadge(symbol: "calendar.badge.clock", tint: Theme.accent, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Найближчий строк").s).font(.caption.weight(.medium)).foregroundStyle(.secondary)
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
                    BlockTitle(L("Доходи по місяцях").s)
                    Surface {
                        Chart(byMonth, id: \.month) { m in
                            BarMark(x: .value(L("Місяць").s, m.month, unit: .month), y: .value(L("Сума").s, m.sum))
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
                BlockTitle(L("Ставки \(String(rates.year))").s)
                Surface {
                    rate(L("ПДФО з зарплати та інших доходів").s, percent(rates.pdfo))
                    Rule()
                    rate(L("Військовий збір").s, percent(rates.military))
                    Rule()
                    rate(L("ЄСВ роботодавця чи ФОП").s, percent(rates.esv))
                    Rule()
                    rate(L("Проценти за депозитом").s, percent(rates.pdfo + rates.military))
                    Rule()
                    rate(L("Мінімальна зарплата").s, Format.money(rates.minWage))
                    Rule()
                    rate(L("Прожитковий мінімум").s, Format.money(rates.subsistence))
                }
            }
            if !deposits.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    BlockTitle(L("Депозити").s)
                    Surface {
                        ForEach(Array(deposits.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Rule() }
                            AmountRow(title: L("\(Format.money(d.amount)) під \(String(format: "%.0f", d.interestRate))%").s,
                                      subtitle: L("проценти \(Format.money(d.interestEarned)), податок \(Format.money(TaxMath.depositTax(interest: d.interestEarned, rates)))").s,
                                      amount: Format.money(d.interestEarned - TaxMath.depositTax(interest: d.interestEarned, rates)))
                        }
                    }
                    Text(L("Податок з процентів банк утримує сам.").s)
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
            SegmentBar(items: [(false, L("Нараховано").s), (true, L("На руки").s)], selection: $fromNet)
            MoneyField(title: fromNet ? L("Хочу на руки на місяць").s : L("Зарплата до податків на місяць").s, value: $amount)
            HeroPanel {
                HeroCaption(fromNet ? L("Треба нарахувати").s : L("На руки").s)
                BigAmount(value: fromNet ? s.gross : s.net, size: 32).padding(.top, 6)
                SplitBar(parts: [(L("На руки").s, s.net), (L("ПДФО").s, s.pdfo), (L("ВЗ").s, s.military)], inverted: true)
                    .padding(.top, 16)
            }
            Surface {
                Line2(L("Нараховано").s, Format.money(s.gross))
                Rule()
                Line2(L("ПДФО \(percent(rates.pdfo))").s, "−" + Format.money(s.pdfo))
                Rule()
                Line2(L("Військовий збір \(percent(rates.military))").s, "−" + Format.money(s.military))
                Rule()
                Line2(L("На руки").s, Format.money(s.net))
            }
            VStack(alignment: .leading, spacing: 12) {
                BlockTitle(L("Роботодавець платить").s)
                Surface {
                    Line2(L("ЄСВ \(percent(rates.esv)) понад зарплату").s, Format.money(s.employerEsv))
                    Rule()
                    Line2(L("Повна вартість працівника").s, Format.money(s.employerCost))
                    Rule()
                    Line2(L("Частка податків у вартості").s, percent((s.employerCost - s.net) / max(s.employerCost, 1)))
                }
            }
            HStack(spacing: 12) {
                Surface { Stat(value: Format.money(s.net * 12), label: L("на руки за рік").s).padding(16) }
                Surface { Stat(value: Format.money((s.pdfo + s.military) * 12), label: L("податків за рік").s).padding(16) }
            }
            if gross < rates.minWage {
                Text(L("Менше за мінімальну зарплату (\(Format.money(rates.minWage))) за повну ставку платити не можна.").s)
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
            MoneyField(title: L("Дохід за рік").s, value: $income)
            HeroPanel {
                HeroCaption(L("Податки ФОП за рік").s)
                BigAmount(value: f.total, size: 32).padding(.top, 6)
                HStack(alignment: .top, spacing: 16) {
                    Stat(value: Format.money(f.total / 12), label: L("у середньому на місяць").s, inverted: true)
                    Stat(value: percent(f.effective), label: L("від доходу").s, inverted: true)
                }
                .padding(.top, 14)
                SplitBar(parts: [(L("Єдиний").s, f.single), (L("ЄСВ").s, f.esv), (L("ВЗ").s, f.military)], inverted: true)
                    .padding(.top, 16)
            }
            Surface {
                Line2(L("Єдиний податок").s, Format.money(f.single))
                Rule()
                Line2(L("ЄСВ «за себе»").s, Format.money(f.esv))
                Rule()
                Line2(L("Військовий збір").s, Format.money(f.military))
                Rule()
                Line2(L("Лишається").s, Format.money(income - f.total))
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L("Ліміт доходу").s).caption()
                    Spacer()
                    Text(Format.money(f.limit)).font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                }
                Meter(value: f.limit > 0 ? income / f.limit : 0)
                Text(f.overLimit
                     ? L("Дохід більший за ліміт групи: з наступного кварталу доведеться перейти на іншу групу або загальну систему.").s
                     : L("Використано \(percent(income / max(f.limit, 1))) ліміту.").s)
                    .font(.footnote)
                    .foregroundStyle(f.overLimit ? Theme.ink : .secondary)
                    .fontWeight(f.overLimit ? .semibold : .regular)
            }
            VStack(alignment: .leading, spacing: 12) {
                BlockTitle(L("Порівняння із зарплатою").s)
                Surface {
                    Line2(L("ФОП: лишається за рік").s, Format.money(income - f.total))
                    Rule()
                    Line2(L("Працівник: на руки за рік").s, Format.money(salary.net * 12))
                    Rule()
                    Line2(L("Різниця").s, Format.money(income - f.total - salary.net * 12))
                }
                }
            Button(tax.group == selected ? L("Це моя група - строки в календарі").s : L("Я ФОП цієї групи").s) {
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
            MoneyField(title: L("Зарплата до податків за рік").s, value: $salaryYear)
            HeroPanel {
                HeroCaption(L("Можна повернути").s)
                BigAmount(value: refund, size: 34).padding(.top, 6)
                HStack(alignment: .top, spacing: 16) {
                    Stat(value: Format.money(eligible), label: L("витрати").s, inverted: true)
                    Stat(value: Format.money(salaryYear * r.pdfo), label: L("ПДФО за рік").s, inverted: true)
                }
                .padding(.top, 14)
            }
            HStack {
                BlockTitle(L("Витрати").s)
                Spacer()
                Button { adding = true } label: { Label(L("Додати").s, systemImage: "plus") }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            }
            if tax.deductions.isEmpty {
                Text(L("Витрат ще немає.").s)
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Surface {
                    ForEach(Array(tax.deductions.enumerated()), id: \.element.id) { i, d in
                        if i > 0 { Rule() }
                        HStack {
                            AmountRow(title: d.kind.title, subtitle: d.note.isEmpty ? L("18% повернуть: \(Format.money(d.amount * r.pdfo))").s : d.note,
                                      amount: Format.money(d.amount))
                            Button { tax.deductions.removeAll { $0.id == d.id } } label: {
                                Image(systemName: "xmark").font(.footnote).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 14)
                            .accessibilityLabel(L("Прибрати").s)
                        }
                    }
                }
            }
            Text(L("Декларація - до 31 грудня наступного року. Навчання - до \(Format.money(TaxMath.educationLimitPerMonth(r))) на місяць.").s)
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
                    Picker(L("Витрата").s, selection: $kind) { ForEach(Deduction.Kind.allCases) { Text($0.title).tag($0) } }
                    TextField(L("Сума за рік, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                    TextField(L("Нотатка: заклад, банк, договір").s, text: $note)
                } footer: {
                    Text(kind.hint)
                }
                FormAction(title: L("Додати").s, disabled: (amount ?? 0) <= 0) {
                    add(Deduction(kind: kind, amount: amount ?? 0, note: note))
                    dismiss()
                }
            }
            .labForm()
            .navigationTitle(L("Витрата для знижки").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Календар

private struct CalendarPart: View {
    let group: FopGroup?

    static func left(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: date).day ?? 0
        return days == 0 ? L("сьогодні").s : days == 1 ? L("завтра").s : L("за \(days) дн.").s
    }

    var body: some View {
        let list = TaxDeadline.upcoming(group: group)
        let byMonth = Dictionary(grouping: list) { Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
            .sorted { $0.key < $1.key }
        VStack(alignment: .leading, spacing: 18) {
            Text(group.map { L("Строки для фізособи і ФОП, \($0.title.lowercased()).").s } ?? L("Строки для фізособи. Оберіть групу у вкладці ФОП, щоб додати строки підприємця.").s)
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
                    field(L("Мінімальна зарплата, TAX").s, \.minWage)
                    field(L("Прожитковий мінімум, TAX").s, \.subsistence)
                } header: {
                    Text(L("На 1 січня").s)
                }
                Section(L("Ставки, частки від 1").s) {
                    field(L("ПДФО").s, \.pdfo)
                    field(L("Військовий збір").s, \.military)
                    field(L("ЄСВ").s, \.esv)
                    field(L("3 група, ставка").s, \.group3Rate)
                    field(L("3 група з ПДВ, ставка").s, \.group3VatRate)
                    field(L("ВЗ 3 групи, від доходу").s, \.militaryFop3Rate)
                }
                Section {
                    Button(L("Повернути ставки \(String(TaxRates.default.year)) року").s) { tax.rates = .default }
                }
            }
            .labForm()
            .navigationTitle(L("Ставки").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Готово").s) { dismiss() } } }
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
