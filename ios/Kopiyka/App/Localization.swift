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

    /// Поточна мова: вибрана в налаштуваннях, а без вибору - завжди English, незалежно від мови системи.
    nonisolated(unsafe) static var current: Lang = {
        if let raw = UserDefaults.standard.string(forKey: key), let l = Lang(rawValue: raw) { return l }
        return .en
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

    /// Шаблони з %@ у таблиці, зібрані в регулярні вирази: за ними впізнаємо речення сервера зі змінними частинами.
    nonisolated(unsafe) private static let templates: [(regex: NSRegularExpression, key: String)] = table.keys
        .filter { $0.contains("%@") }
        .sorted { $0.count > $1.count }
        .compactMap { key in
            let body = NSRegularExpression.escapedPattern(for: key).replacingOccurrences(of: "%@", with: "(.+?)")
            return (try? NSRegularExpression(pattern: "^" + body + "$")).map { ($0, key) }
        }

    /// Тексти, які пише сервер українською: назви операцій, спостереження, сповіщення, досягнення.
    /// Точні збіги беруться з таблиці, речення зі змінними частинами - за шаблоном.
    static func server(_ d: String) -> String {
        guard Lang.current != .uk else { return d }
        if let exact = table[d]?[Lang.current.rawValue] { return exact }
        let ns = d as NSString
        for (regex, key) in templates {
            guard let m = regex.firstMatch(in: d, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { continue }
            return text(key, (1..<m.numberOfRanges).map { fragment(ns.substring(with: m.range(at: $0))) })
        }
        return text(d, [])
    }

    /// Змінна частина серверного речення: кількість операцій, сума або вкладений текст.
    static func fragment(_ s: String) -> String {
        if let m = s.wholeMatch(of: /(\d+) (операція|операції|операцій)/), let n = Int(m.1) {
            // українська форма за числом, а в мовах без трьох форм - однина й множина
            let one = n % 10 == 1 && n % 100 != 11
            let few = (2...4).contains(n % 10) && !(12...14).contains(n % 100)
            let key = Lang.current == .ru ? (one ? "%@ операція" : few ? "%@ операції" : "%@ операцій") : (n == 1 ? "%@ операція" : "%@ операцій")
            return text(key, [String(n)])
        }
        if s.wholeMatch(of: /(\d{1,3}([\u00a0 ]\d{3})+|\d{1,3})(,\d+)?|\d+\.\d{2}/) != nil {
            let clean = s.replacingOccurrences(of: "\u{00a0}", with: "").replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")
            if let v = Double(clean) { return v.formatted(.number.precision(.fractionLength(0...2)).locale(Lang.current.locale)) }
        }
        return server(s)
    }

    /// Переклад ключа для мов, яких немає в Tx: італійська й німецька.
    static func extra(_ key: String) -> String? { table[key]?[Lang.current.rawValue] }

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

/// Имя для показа: заглушку сервера («Користувач Apple») заменяет имя из проверки личности,
/// а ВСЕ ЗАГЛАВНЫЕ и все строчные имена приводятся к виду «Имя Фамилия».
enum DisplayName {
    static func of(_ raw: String?) -> String {
        let name = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholder = name.hasPrefix("Користувач") || name.hasPrefix("Пользователь") || name.hasPrefix("User ")
        if name.isEmpty || placeholder {
            let kyc = KYCState.load().fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !kyc.isEmpty { return tidy(kyc) }
            return name.isEmpty ? "" : Translator.server(name)
        }
        return tidy(name)
    }

    static func tidy(_ s: String) -> String {
        guard s == s.lowercased() || s == s.uppercased() else { return s }
        return s.split(separator: " ").map { w in
            w.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                .joined(separator: "-")
        }.joined(separator: " ")
    }

    static func initials(_ raw: String?) -> String {
        of(raw).split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
