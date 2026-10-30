import SwiftUI

/// Стан екрана банку: помилка й «зайнято» для дій, що ходять на сервер.
@MainActor @Observable
final class Screen {
    var error: String?
    var busy = false

    /// Виконує дію, показує помилку сервера, якщо вона є. Повертає, чи вдалося.
    @discardableResult
    func run(_ work: () async throws -> Void) async -> Bool {
        busy = true
        defer { busy = false }
        do {
            try await work()
            error = nil
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

/// Помилка сервера під формою.
struct ErrorSection: View {
    let error: String?

    var body: some View {
        if let error {
            Section { Text(error).font(.footnote).foregroundStyle(.secondary) }
        }
    }
}

/// Головна дія форми: чорна плитка на всю ширину.
struct FormAction: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Section {
            Button(title, action: action)
                .buttonStyle(InkButton())
                .disabled(disabled)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}

/// Плоска смуга прогресу.
struct Meter: View {
    let value: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { g in
            Capsule().fill(Theme.line)
                .overlay(alignment: .leading) {
                    Capsule().fill(tint).frame(width: max(6, g.size.width * max(0, min(value, 1))))
                }
        }
        .frame(height: 6)
    }
}

/// Два підписи в рядок: ліворуч назва, праворуч значення.
struct Line: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        LabeledContent(title, value: value).monospacedDigit()
    }
}

/// Мала форма з однією сумою: поповнити ціль, картку, внести платіж.
struct AmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let action: String
    var hint: String?
    @State var amount: Double?
    let submit: (Double) async throws -> Void
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    TextField(L("Сума, TAX").s, value: $amount, format: .number).keyboardType(.decimalPad)
                } footer: {
                    if let hint { Text(hint) }
                }
                ErrorSection(error: screen.error)
                FormAction(title: action, disabled: (amount ?? 0) <= 0 || screen.busy) {
                    Task {
                        if await screen.run({ try await submit(amount ?? 0) }) { dismiss() }
                    }
                }
            }
            .labForm()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

enum BankText {
    static var types: [String: String] { ["topup": L("Поповнення").s, "transfer": L("Перекази").s, "payment": L("Покупки").s, "payout": L("Виплати").s,
                        "donation": L("Донати").s, "credit": L("Кредити").s, "deposit": L("Депозити").s, "savings": L("Накопичення").s,
                        "marketplace": L("Магазин").s, "credit_repay": L("Погашення кредиту").s, "card_topup": L("Поповнення картки").s] }

    static func type(_ t: String) -> String { types[t] ?? t.capitalized }

    /// Службові рахунки продавців навчального банку - людською мовою.
    static var merchants: [String: String] { ["MRC-UTILITIES-01": L("Комунальні послуги").s, "MRC-ONLINE-01": L("Онлайн-покупки").s,
                            "MRC-FUEL-01": "Пальне", "MRC-GROCERY-01": "Продукти", "MRC-CAFE-01": "Кафе",
                            "MRC-GROCERY-02": "Продукти", "MRC-TRANSPORT-01": "Транспорт", "MRC-PHARMA-01": "Аптека",
                            "MRC-CINEMA-01": L("Кіно").s, "MRC-TELECOM-01": L("Зв'язок").s] }

    static func recipient(_ account: String) -> String { merchants[account] ?? account }

    static var frequencies: [(String, String)] { [("weekly", L("Щотижня").s), ("monthly", L("Щомісяця").s)] }

    static func frequency(_ f: String) -> String { frequencies.first { $0.0 == f }?.1 ?? f }

    /// «2026-11-27» чи «2026-11-27 10:38:31» → «27 листопада 2026».
    static func date(_ s: String?) -> String {
        guard let s, s.count >= 10 else { return "-" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: String(s.prefix(10))) else { return s }
        // без «р.»: «27 жовтня 2026»
        return d.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "uk_UA"))) + " "
            + String(Calendar.current.component(.year, from: d))
    }

    /// «2026-10-27» → дата; nil, якщо рядок не схожий на день.
    static func day(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    /// «Травень 2027» - без «р.» і без розділювача тисяч у році.
    static func monthYear(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "uk_UA")
        f.dateFormat = "LLLL"
        return f.string(from: d).capitalized + " " + String(Calendar.current.component(.year, from: d))
    }

    /// «Сьогодні», «Учора» або «27 жовтня».
    static func dayTitle(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return L("Сьогодні").s }
        if cal.isDateInYesterday(day) { return L("Учора").s }
        return day.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "uk_UA")))
    }

    static func isoDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
