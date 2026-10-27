import SwiftData
import SwiftUI

/// Особистий облік: витрати місяця, вручну або з чека.
struct MoneyView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(\.modelContext) private var context
    @State private var adding = false

    private var thisMonth: [Expense] {
        let cal = Calendar.current
        return expenses.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Date.now.formatted(.dateTime.month(.wide).locale(Locale(identifier: "uk_UA"))).capitalized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(Format.money(thisMonth.reduce(0) { $0 + $1.amount }))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                }
                if !byCategory.isEmpty {
                    Section("За категоріями") {
                        ForEach(byCategory, id: \.0) { name, sum in
                            LabeledContent(name, value: Format.money(sum)).monospacedDigit()
                        }
                    }
                }
                if !expenses.isEmpty {
                    Section("Останні") { recent }
                }
            }
            .overlay {
                if expenses.isEmpty {
                    ContentUnavailableView("Витрат ще немає", systemImage: "list.bullet.rectangle",
                                           description: Text("Додайте вручну або сфотографуйте чек"))
                }
            }
            .navigationTitle("Гроші")
            .toolbar {
                Button("Додати", systemImage: "plus") { adding = true }
            }
            .sheet(isPresented: $adding) { AddExpenseView() }
        }
    }

    private var recent: some View {
        ForEach(expenses) { e in
            HStack {
                VStack(alignment: .leading) {
                    Text(e.merchant)
                    Text("\(e.category), \(e.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Format.money(e.amount)).monospacedDigit()
            }
        }
        .onDelete { idx in idx.forEach { context.delete(expenses[$0]) } }
    }

    private var byCategory: [(String, Double)] {
        Dictionary(grouping: thisMonth, by: \.category)
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.1 > $1.1 }
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
            Form {
                TextField("Сума, ₴", value: $amount, format: .number).keyboardType(.decimalPad)
                TextField("Де", text: $merchant)
                Picker("Категорія", selection: $category) {
                    ForEach(Self.categories, id: \.self, content: Text.init)
                }
            }
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
