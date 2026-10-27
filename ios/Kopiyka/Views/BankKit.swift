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

    var body: some View {
        GeometryReader { g in
            Rectangle().fill(Theme.line)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Theme.ink).frame(width: g.size.width * max(0, min(value, 1)))
                }
        }
        .frame(height: 4)
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
                    TextField("Сума, ₴", value: $amount, format: .number).keyboardType(.decimalPad)
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

enum BankText {
    static let types = ["topup": "Поповнення", "transfer": "Перекази", "payment": "Покупки", "payout": "Виплати",
                        "donation": "Донати", "credit": "Кредити", "deposit": "Депозити", "savings": "Накопичення"]

    static func type(_ t: String) -> String { types[t] ?? t.capitalized }

    static let frequencies = [("weekly", "Щотижня"), ("monthly", "Щомісяця")]

    static func frequency(_ f: String) -> String { frequencies.first { $0.0 == f }?.1 ?? f }

    /// «2026-11-27» чи «2026-11-27 10:38:31» → «27 листопада 2026».
    static func date(_ s: String?) -> String {
        guard let s, s.count >= 10 else { return "-" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: String(s.prefix(10))) else { return s }
        return d.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "uk_UA")))
    }

    /// «2026-10-27» → дата; nil, якщо рядок не схожий на день.
    static func day(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    static func isoDay(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
