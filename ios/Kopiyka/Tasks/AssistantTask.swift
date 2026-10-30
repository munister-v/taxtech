import EdgeRouter
import Foundation
import FoundationModels

/// Питання про гроші й навчальний банк. На телефоні - Foundation Models (якщо Apple Intelligence
/// доступна й мова підтримується), на сервері - модель із закріпленою версією, лише після маскування.
enum AssistantTask {
    static let instructions = """
    Ти помічник у застосунку обліку витрат «TaxTech» з навчальним банком на віртуальних грошах. \
    Відповідай українською, коротко, 2-4 речення. Справжніх грошей, рахунків і переказів у застосунку немає. \
    Якщо не знаєш відповіді або питання не про гроші й застосунок - так і скажи.
    """

    @Generable
    struct Answer {
        @Guide(description: "Коротка відповідь українською")
        var text: String
        @Guide(description: "true, лише якщо відповідь точно правильна і не вигадана")
        var confident: Bool
    }

    static var deviceAvailable: Bool {
        let model = SystemLanguageModel.default
        return model.availability == .available && model.supportsLocale(Locale(identifier: "uk_UA"))
    }

    /// Чому модель телефона недоступна - показується в «Лабораторії».
    static var deviceStatus: String {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(Locale(identifier: "uk_UA")) ? L("Доступна").s : L("Доступна, але без української").s
        case .unavailable(.deviceNotEligible): return L("Цей iPhone не підтримує Apple Intelligence").s
        case .unavailable(.appleIntelligenceNotEnabled): return L("Apple Intelligence вимкнено").s
        case .unavailable(.modelNotReady): return L("Модель ще завантажується").s
        case .unavailable: return L("Недоступна").s
        }
    }

    static let profile = TaskProfile(
        id: "assistant", sensitivity: .personal, payloadBytes: 600,
        available: [.device, .redactedCloud],
        prior: .init(latencyMs: [.device: 1800, .redactedCloud: 2500], quality: [.device: 0.6, .redactedCloud: 0.9],
                     cloudCost: 1)
    )

    static func executors(cloud api: API?) -> Executors<String, String> {
        var ex = Executors<String, String>()
        if deviceAvailable {
            ex.device = { question in
                let session = LanguageModelSession(instructions: instructions)
                let answer = try await session.respond(to: question, generating: Answer.self).content
                // самооцінка моделі - слабкий сигнал; далі її замінить узгодженість кількох відповідей
                return Attempt(answer.text, uncertainty: answer.confident ? 0.25 : 0.8)
            }
        }
        if let api {
            ex.redactedCloud = { question in
                let (text, count) = Redactor.redact(question)
                let reply = try await api.llm(task: "support", prompt: text)
                return Attempt(reply.text, redactions: count)
            }
        }
        return ex
    }
}
