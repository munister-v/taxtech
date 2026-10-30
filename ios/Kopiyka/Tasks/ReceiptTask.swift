import CoreGraphics
import EdgeRouter
import Foundation
import Vision

/// Чек. Фото завжди розпізнається на телефоні (Vision) і нікуди не йде.
/// Маршрутизується розбір тексту: правила на телефоні або мовна модель на сервері,
/// куди текст іде лише після маскування особистих даних.
enum ReceiptTask {
    struct Line: Sendable {
        let text: String
        let confidence: Double
    }

    struct Fields: Sendable, Equatable {
        var merchant: String
        var total: Double?
        var category: String
    }

    static let profile = TaskProfile(
        id: "receipt", sensitivity: .personal, payloadBytes: 2_000,
        available: [.device, .redactedCloud],
        prior: .init(latencyMs: [.device: 5, .redactedCloud: 1500], quality: [.device: 0.7, .redactedCloud: 0.92],
                     cloudCost: 1)
    )

    static func recognize(_ image: CGImage) async throws -> [Line] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "uk-UA"), Locale.Language(identifier: "en-US")]
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: image)
        return observations.compactMap { o in
            o.topCandidates(1).first.map { Line(text: $0.string, confidence: Double($0.confidence)) }
        }
    }

    static func executors(cloud api: API?) -> Executors<[Line], Fields> {
        var ex = Executors<[Line], Fields>(device: { lines in
            let (fields, uncertainty) = parse(lines)
            return Attempt(fields, uncertainty: uncertainty)
        })
        if let api {
            ex.redactedCloud = { lines in
                let (text, count) = Redactor.redact(lines.map(\.text).joined(separator: "\n"))
                let reply = try await api.llm(task: "receipt", prompt: text)
                return Attempt(try decode(reply.text), redactions: count)
            }
        }
        return ex
    }

    // MARK: Розбір на телефоні

    static let totalWords = ["до сплати", "сума", "разом", "всього", "усього", "total", "итого"]

    static func amounts(in s: String) -> [Double] {
        let re = /(\d{1,6})[.,](\d{2})(?!\d)/
        return s.matches(of: re).compactMap { Double("\($0.1).\($0.2)") }
    }

    /// Сума - число в рядку з «до сплати / сума / разом»; якщо такого рядка немає - найбільше число.
    static func parse(_ lines: [Line]) -> (Fields, uncertainty: Double) {
        let merchant = lines.first { $0.text.contains(where: \.isLetter) }?.text ?? "Без назви"
        var total: Double?
        var confidence = 0.0
        var byKeyword = false
        for (i, line) in lines.enumerated() where totalWords.contains(where: line.text.lowercased().contains) {
            // сума буває в тому ж рядку або в наступному
            let candidates = amounts(in: line.text) + (i + 1 < lines.count ? amounts(in: lines[i + 1].text) : [])
            if let a = candidates.first {
                total = a
                confidence = line.confidence
                byKeyword = true
                break
            }
        }
        if total == nil, let best = lines.flatMap({ l in amounts(in: l.text).map { ($0, l.confidence) } })
            .max(by: { $0.0 < $1.0 }) {
            total = best.0
            confidence = best.1
        }
        let uncertainty: Double = total == nil ? 1 : min(1, (1 - confidence) + (byKeyword ? 0 : 0.5))
        return (Fields(merchant: merchant, total: total, category: category(for: lines)), uncertainty)
    }

    static func category(for lines: [Line]) -> String {
        let text = lines.map(\.text).joined(separator: " ").lowercased()
        let map: [(String, [String])] = [
            ("Продукти", ["сільпо", "атб", "novus", "фора", "ашан", "metro", "хліб", "молоко"]),
            ("Аптека", ["аптека", "pharm", "ліки"]),
            ("Пальне", ["окко", "wog", "socar", "upg", "а-95", "дизель"]),
            ("Кафе", ["кава", "coffee", "кафе", "ресторан", "піца"]),
        ]
        return map.first { $0.1.contains(where: text.contains) }?.0 ?? "Інше"
    }

    // MARK: Відповідь сервера

    struct Reply: Decodable {
        let merchant: String?
        let total: Double?
        let category: String?
    }

    /// Модель відповідає JSON; беремо від першої `{` до останньої `}`.
    static func decode(_ text: String) throws -> Fields {
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}") else {
            throw API.Failure(message: L("Сервер не повернув полів чека").s)
        }
        let r = try JSONDecoder().decode(Reply.self, from: Data(text[a...b].utf8))
        return Fields(merchant: r.merchant ?? "Без назви", total: r.total, category: r.category ?? "Інше")
    }
}
