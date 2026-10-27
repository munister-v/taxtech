import Foundation

/// Маскування особистих даних перед відправкою на сервер (режим `redactedCloud`).
/// Суми й назви магазинів лишаються - без них сервер не розбере чек.
public enum Redactor {
    static let rules: [(NSRegularExpression, String)] = [
        (#"\bUA\d{2}[ ]?(?:\d[ ]?){25}\b"#, "[IBAN]"),
        (#"\b(?:\d[ -]?){15,18}\d\b"#, "[КАРТКА]"),
        (#"\b\d{4}[*xX•]{4,8}\d{4}\b"#, "[КАРТКА]"),
        (#"(?:\+?38[ -]?)?\(?0[ -]?\d{2}\)?[ -]?\d{3}[ -]?\d{2}[ -]?\d{2}\b"#, "[ТЕЛЕФОН]"),
        (#"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, "[ПОШТА]"),
        // РНОКПП (ІПН) - 10 цифр поспіль
        (#"\b\d{10}\b"#, "[ІПН]"),
        // паспорт-книжечка і ID-картка
        (#"\b[А-ЯІЇЄA-Z]{2}\d{6}\b|\b\d{9}\b"#, "[ПАСПОРТ]"),
    ].map { (try! NSRegularExpression(pattern: $0.0, options: [.caseInsensitive]), $0.1) }

    public static func redact(_ text: String) -> (text: String, count: Int) {
        var out = text
        var count = 0
        for (re, token) in rules {
            let range = NSRange(out.startIndex..., in: out)
            count += re.numberOfMatches(in: out, range: range)
            out = re.stringByReplacingMatches(in: out, range: range, withTemplate: token)
        }
        return (out, count)
    }
}
