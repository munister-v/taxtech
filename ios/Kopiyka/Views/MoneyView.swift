import Charts
import SwiftData
import SwiftUI

/// Особистий облік: витрати місяця, графік по днях, категорії, останні витрати.
struct MoneyView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(\.modelContext) private var context
    @State private var adding = false

    private var thisMonth: [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    private var total: Double { thisMonth.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    hero
                    if expenses.isEmpty {
                        ContentUnavailableView("Витрат ще немає", systemImage: "list.bullet.rectangle",
                                               description: Text("Додайте вручну або сфотографуйте чек"))
                            .padding(.top, 40)
                    } else {
                        chart
                        categories
                        recent
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Гроші")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Додати", systemImage: "plus") { adding = true }
            }
            .sheet(isPresented: $adding) { AddExpenseView() }
            #if DEBUG
            .task { seedDemoIfAsked() }
            #endif
        }
    }

    #if DEBUG
    /// Демо-витрати для перевірки вигляду: simctl launch з SIMCTL_CHILD_KOPIYKA_DEMO_EXPENSES=1.
    private func seedDemoIfAsked() {
        guard expenses.isEmpty, ProcessInfo.processInfo.environment["KOPIYKA_DEMO_EXPENSES"] == "1" else { return }
        let samples: [(String, String, Double)] = [
            ("Сільпо", "Продукти", 412.5), ("АТБ", "Продукти", 186.3), ("Aroma Kava", "Кафе", 95),
            ("ОККО", "Пальне", 1450), ("Аптека Доброго Дня", "Аптека", 238.9), ("Novus", "Продукти", 654.2),
            ("Метро", "Транспорт", 16), ("ДТЕК", "Комуналка", 1180.4), ("Піца Челентано", "Кафе", 340),
        ]
        let today = Calendar.current.component(.day, from: .now)
        for i in 0..<min(26, today * 2) {
            let s = samples[i % samples.count]
            let day = Calendar.current.date(byAdding: .day, value: -(i % today), to: .now)!
            context.insert(Expense(amount: s.2 * Double(1 + i % 3) / 2, merchant: s.0, category: s.1,
                                   date: day, source: "Демо"))
        }
    }
    #endif

    private var hero: some View {
        VStack(spacing: 6) {
            Text("Витрати за \(Date.now.formatted(.dateTime.month(.wide).locale(Locale(identifier: "uk_UA"))))")
                .caption()
            Text(Format.money(total))
                .font(Theme.balance())
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let avg = dailyAverage {
                Text("у середньому \(Format.money(avg)) на день")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var dailyAverage: Double? {
        let day = Calendar.current.component(.day, from: .now)
        return total > 0 ? total / Double(day) : nil
    }

    private var byDay: [(day: Date, sum: Double)] {
        Dictionary(grouping: thisMonth) { Calendar.current.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.day < $1.day }
    }

    private var chart: some View {
        Surface {
            Chart(byDay, id: \.day) { d in
                BarMark(x: .value("День", d.day, unit: .day), y: .value("Сума", d.sum), width: .ratio(0.62))
                    .foregroundStyle(Theme.ink)
            }
            .chartXScale(domain: monthRange)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) {
                    AxisValueLabel(format: .dateTime.day())
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

    private var monthRange: ClosedRange<Date> {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: .now)!
        return interval.start...interval.end
    }

    private var byCategory: [(name: String, sum: Double)] {
        Dictionary(grouping: thisMonth, by: \.category)
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.sum > $1.sum }
    }

    private func rank(_ name: String) -> Int { byCategory.firstIndex { $0.name == name } ?? 0 }

    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Категорії")
            Surface {
                // кільце й смуги одного відтінку - легенда не потрібна
                Chart(byCategory, id: \.name) { c in
                    SectorMark(angle: .value("Сума", c.sum), innerRadius: .ratio(0.72), angularInset: 1.5)
                        .foregroundStyle(Theme.shade(rank(c.name)))
                }
                .chartBackground { _ in
                    VStack(spacing: 2) {
                        Text("\(byCategory.count) категорій")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(Format.money(total))
                            .font(.system(.title3, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                .frame(height: 210)
                .padding(.vertical, 20)

                ForEach(Array(byCategory.enumerated()), id: \.element.name) { i, c in
                    Rule()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(c.name)
                            Spacer()
                            Text("\(Int((c.sum / max(total, 1) * 100).rounded()))%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(Format.money(c.sum))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                        GeometryReader { g in
                            Rectangle().fill(Theme.line)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(Theme.shade(i))
                                        .frame(width: g.size.width * c.sum / max(total, 1))
                                }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Останні")
            Surface {
                ForEach(Array(expenses.prefix(20).enumerated()), id: \.element.id) { i, e in
                    if i > 0 { Rule() }
                    AmountRow(title: e.merchant,
                              subtitle: "\(e.category), \(BankView.dayTitle(Calendar.current.startOfDay(for: e.date)).lowercased())",
                              amount: "−" + Format.money(e.amount))
                        .contentShape(.rect)
                        .contextMenu {
                            Button("Видалити", systemImage: "trash", role: .destructive) { context.delete(e) }
                        }
                }
            }
        }
    }
}

struct AddExpenseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double?
    @State private var merchant = ""
    @State private var category = "Інше"

    static let categories = ["Продукти", "Кафе", "Аптека", "Пальне", "Транспорт", "Комуналка", "Інше"]

    var body: some View {
        NavigationStack {
            LabForm {
                TextField("Сума, ₴", value: $amount, format: .number).keyboardType(.decimalPad)
                TextField("Де", text: $merchant)
                Picker("Категорія", selection: $category) {
                    ForEach(Self.categories, id: \.self, content: Text.init)
                }
            }
            .labForm()
            .navigationTitle("Нова витрата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        context.insert(Expense(amount: amount ?? 0, merchant: merchant.isEmpty ? "Без назви" : merchant,
                                               category: category, source: "Вручну"))
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
        }
    }
}
