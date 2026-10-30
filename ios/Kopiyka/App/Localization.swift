import SwiftUI

/// Мови застосунку. Українська - основна: тексти в коді написані нею й слугують ключами.
enum Lang: String, CaseIterable, Identifiable {
    case uk, en, it, de, ru
    var id: String { rawValue }

    var title: String {
        switch self {
        case .uk: "Українська"
        case .en: "English"
        case .it: "Italiano"
        case .de: "Deutsch"
        case .ru: "Русский"
        }
    }

    static let key = "appLang"

    /// Поточна мова: вибрана в профілі, а без вибору - мова системи (інші мови системи -> English).
    nonisolated(unsafe) static var current: Lang = {
        if let raw = UserDefaults.standard.string(forKey: key), let l = Lang(rawValue: raw) { return l }
        let sys = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "uk"
        return Lang(rawValue: sys) ?? .en
    }()

    static func set(_ l: Lang) {
        current = l
        UserDefaults.standard.set(l.rawValue, forKey: key)
        // Системні елементи (кнопка Apple) беруть мову з цього списку при наступному запуску.
        UserDefaults.standard.set([l.rawValue], forKey: "AppleLanguages")
    }

    var locale: Locale { Locale(identifier: self == .uk ? "uk_UA" : rawValue) }
}

/// Переклади: ключ - український текст, значення - слова за мовами. Лежать у translations.json.
enum Translator {
    nonisolated(unsafe) private static let table: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "translations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let t = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return t
    }()

    /// Назви операцій, які пише сервер українською: точні збіги й шаблони з номером чи приміткою.
    static func server(_ d: String) -> String {
        guard Lang.current != .uk else { return d }
        if d.hasPrefix("Надходження: ") { return text("Надходження: %@", [String(d.dropFirst("Надходження: ".count))]) }
        if d.hasPrefix("Оплата інвойсу "), d.hasSuffix(" у магазині TaxTech") {
            let n = d.dropFirst("Оплата інвойсу ".count).dropLast(" у магазині TaxTech".count)
            return text("Оплата інвойсу %@ у магазині TaxTech", [String(n)])
        }
        return text(d, [])
    }

    static func text(_ key: String, _ args: [String]) -> String {
        var s = Lang.current == .uk ? key : (table[key]?[Lang.current.rawValue] ?? key)
        guard !args.isEmpty else { return s }
        for (i, a) in args.enumerated() { s = s.replacingOccurrences(of: "%\(i + 1)$@", with: a) }
        for a in args {
            guard let r = s.range(of: "%@") else { break }
            s.replaceSubrange(r, with: a)
        }
        return s
    }
}

/// Локалізований текст: `L("Привіт, \(name)").s`. Підстановки йдуть як %@ у ключі.
struct L: ExpressibleByStringInterpolation {
    let key: String
    let args: [String]

    init(stringLiteral value: String) { key = value; args = [] }
    init(stringInterpolation i: Interpolation) { key = i.key; args = i.args }

    struct Interpolation: StringInterpolationProtocol {
        var key = ""
        var args: [String] = []
        init(literalCapacity: Int, interpolationCount: Int) {}
        mutating func appendLiteral(_ s: String) { key += s }
        mutating func appendInterpolation<T>(_ v: T) { key += "%@"; args.append(String(describing: v)) }
    }

    var s: String { Translator.text(key, args) }
}
