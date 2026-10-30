import Foundation

/// Податки України для навчального розділу: ставки, розрахунки й строки.
/// Ставки - станом на 2026 рік; їх можна змінити в застосунку, якщо закон зміниться.
struct TaxRates: Codable, Equatable, Sendable {
    var year = 2026
    /// Мінімальна заробітна плата на 1 січня.
    var minWage: Double = 8_647
    /// Прожитковий мінімум для працездатних осіб на 1 січня.
    var subsistence: Double = 3_328
    var pdfo = 0.18
    /// Військовий збір з доходів фізичних осіб.
    var military = 0.05
    /// ЄСВ.
    var esv = 0.22

    // ФОП
    var group1Share = 0.10        // від прожиткового мінімуму на місяць
    var group2Share = 0.20        // від мінімальної зарплати на місяць
    var group3Rate = 0.05
    var group3VatRate = 0.03
    var militaryFopFixedShare = 0.10  // ВЗ для 1 і 2 груп - від мінімальної зарплати на місяць
    var militaryFop3Rate = 0.01       // ВЗ для 3 групи - від доходу
    var limit1 = 167.0, limit2 = 834.0, limit3 = 1_167.0  // ліміти доходу в мінімальних зарплатах на рік

    static let `default` = TaxRates()
}

enum FopGroup: String, CaseIterable, Codable, Identifiable, Sendable {
    case first, second, third, thirdVat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .first: L("1 група").s
        case .second: L("2 група").s
        case .third: L("3 група, 5%").s
        case .thirdVat: L("3 група, 3% + ПДВ").s
        }
    }

    var who: String {
        switch self {
        case .first: L("Роздрібна торгівля на ринку й побутові послуги населенню, без найманих працівників.").s
        case .second: L("Послуги й продаж населенню та платникам єдиного податку, до 10 працівників.").s
        case .third, .thirdVat: L("Будь-які дозволені види діяльності, клієнти - будь-хто, працівників без обмежень.").s
        }
    }
}

enum TaxMath {
    struct Salary: Sendable {
        let gross, pdfo, military, net, employerEsv, employerCost: Double
    }

    /// Зарплата: з «брудних» на руки. ЄСВ платить роботодавець понад зарплату (з обмеженням бази 20 мінімалками).
    static func salary(gross: Double, _ r: TaxRates) -> Salary {
        let pdfo = gross * r.pdfo, mil = gross * r.military
        let esv = min(gross, r.minWage * 20) * r.esv
        return Salary(gross: gross, pdfo: pdfo, military: mil, net: gross - pdfo - mil,
                      employerEsv: esv, employerCost: gross + esv)
    }

    /// Скільки треба нарахувати, щоб на руки вийшла сума.
    static func gross(forNet net: Double, _ r: TaxRates) -> Double { net / (1 - r.pdfo - r.military) }

    struct Fop: Sendable {
        let single, military, esv, total, limit: Double
        let income: Double
        var effective: Double { income > 0 ? total / income : 0 }
        var overLimit: Bool { income > limit }
    }

    /// ФОП на рік: єдиний податок, військовий збір і ЄСВ «за себе» (мінімальний).
    static func fop(_ g: FopGroup, income: Double, months: Int = 12, _ r: TaxRates) -> Fop {
        let m = Double(months)
        let esv = r.minWage * r.esv * m
        switch g {
        case .first:
            let single = r.subsistence * r.group1Share * m, mil = r.minWage * r.militaryFopFixedShare * m
            return Fop(single: single, military: mil, esv: esv, total: single + mil + esv, limit: r.limit1 * r.minWage, income: income)
        case .second:
            let single = r.minWage * r.group2Share * m, mil = r.minWage * r.militaryFopFixedShare * m
            return Fop(single: single, military: mil, esv: esv, total: single + mil + esv, limit: r.limit2 * r.minWage, income: income)
        case .third, .thirdVat:
            let single = income * (g == .third ? r.group3Rate : r.group3VatRate), mil = income * r.militaryFop3Rate
            return Fop(single: single, military: mil, esv: esv, total: single + mil + esv, limit: r.limit3 * r.minWage, income: income)
        }
    }

    /// Податок з процентів за депозитом: банк утримує ПДФО і військовий збір сам.
    static func depositTax(interest: Double, _ r: TaxRates) -> Double { interest * (r.pdfo + r.military) }

    /// Податкова знижка: повертається 18% від витрат, але не більше за ПДФО, сплачений із зарплати за рік.
    static func refund(eligible: Double, salaryYear: Double, _ r: TaxRates) -> Double {
        min(eligible * r.pdfo, salaryYear * r.pdfo)
    }

    /// Ліміт витрат на навчання, що йде в знижку: 1,4 прожиткового мінімуму на місяць, округлено до 10 грн.
    static func educationLimitPerMonth(_ r: TaxRates) -> Double { (r.subsistence * 1.4 / 10).rounded() * 10 }
}

/// Витрата, що дає право на податкову знижку.
struct Deduction: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var kind: Kind
    var amount: Double
    var note: String

    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        case education, mortgage, ivf, insurance, charity, housing
        var id: String { rawValue }
        var title: String {
            switch self {
            case .education: L("Навчання").s
            case .mortgage: L("Відсотки за іпотекою").s
            case .ivf: L("Лікування безпліддя").s
            case .insurance: L("Страхування життя, пенсійні внески").s
            case .charity: L("Благодійність").s
            case .housing: L("Будівництво житла за програмою").s
            }
        }
        var hint: String {
            switch self {
            case .education: L("Своє або дітей у закладах України. До 1,4 прожиткового мінімуму на місяць навчання.").s
            case .mortgage: L("Відсотки за кредитом на житло в межах норм площі.").s
            case .ivf: L("Запліднення in vitro та сурогатне материнство.").s
            case .insurance: L("Договори довгострокового страхування й недержавне пенсійне забезпечення.").s
            case .charity: L("Пожертви неприбутковим організаціям - до 4% річного доходу.").s
            case .housing: L("Внески на доступне житло й обслуговування кредиту за державною програмою.").s
            }
        }
    }
}

/// Податковий строк для календаря.
struct TaxDeadline: Identifiable, Sendable {
    let date: Date
    let title: String
    let detail: String
    let forFop: Bool
    var id: String { "\(date.timeIntervalSince1970)\(title)" }

    /// Найближчі строки на рік уперед від сьогодні.
    static func upcoming(group: FopGroup?, from now: Date = .now) -> [TaxDeadline] {
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        func d(_ year: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: year, month: m, day: day)) ?? now }
        var list: [TaxDeadline] = []
        for year in [y, y + 1] {
            list.append(.init(date: d(year, 5, 1), title: L("Декларація про майновий стан").s,
                              detail: L("Якщо були доходи без утримання податку: оренда, продаж, іноземні доходи, виграші.").s, forFop: false))
            list.append(.init(date: d(year, 7, 31), title: L("Сплата податку за декларацією").s,
                              detail: L("ПДФО і військовий збір за минулий рік, задекларовані до 1 травня.").s, forFop: false))
            list.append(.init(date: d(year, 12, 31), title: L("Податкова знижка за минулий рік").s,
                              detail: L("Останній день подати декларацію на знижку за витрати попереднього року.").s, forFop: false))
            if let group {
                for (m, label) in [(1, L("IV квартал").s), (4, L("I квартал").s), (7, L("II квартал").s), (10, L("III квартал").s)] {
                    list.append(.init(date: d(year, m, 20), title: L("ЄСВ за \(label)").s,
                                      detail: L("Внесок «за себе» - щонайменше 22% мінімальної зарплати за кожен місяць.").s, forFop: true))
                }
                switch group {
                case .first, .second:
                    for m in 1...12 {
                        list.append(.init(date: d(year, m, 20), title: L("Єдиний податок і військовий збір").s,
                                          detail: L("Авансом за поточний місяць.").s, forFop: true))
                    }
                    list.append(.init(date: d(year, 3, 1), title: L("Річна декларація ФОП").s,
                                      detail: L("Декларація платника єдиного податку за минулий рік.").s, forFop: true))
                case .third, .thirdVat:
                    for (m, day, label) in [(2, 9, L("IV квартал").s), (5, 9, L("I квартал").s), (8, 9, L("II квартал").s), (11, 9, L("III квартал").s)] {
                        list.append(.init(date: d(year, m, day), title: L("Декларація за \(label)").s,
                                          detail: L("Протягом 40 днів після кінця кварталу.").s, forFop: true))
                        list.append(.init(date: d(year, m, day + 10), title: L("Єдиний податок за \(label)").s,
                                          detail: L("Сплата протягом 10 днів після строку декларації, разом із військовим збором 1%.").s, forFop: true))
                    }
                }
            }
        }
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .year, value: 1, to: start) ?? now
        return list.filter { $0.date >= start && $0.date <= end }.sorted { $0.date < $1.date }
    }
}

/// Налаштування податкового розділу - лише на телефоні.
@MainActor @Observable
final class TaxStore {
    var rates: TaxRates { didSet { save("taxRates", rates) } }
    var group: FopGroup? { didSet { save("taxFopGroup", group) } }
    var deductions: [Deduction] { didSet { save("taxDeductions", deductions) } }

    init() {
        rates = Self.load("taxRates") ?? .default
        group = Self.load("taxFopGroup") ?? nil
        deductions = Self.load("taxDeductions") ?? []
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private func save<T: Encodable>(_ key: String, _ value: T) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
