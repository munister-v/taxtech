import SwiftUI
import UIKit

/// Шрифти: SF Pro для тексту й інтерфейсу, New York (із засічками) для заголовків і сум, SF Mono для хешів і кодів.
extension Theme {
    private static func wght(_ w: Font.Weight) -> CGFloat {
        switch w {
        case .ultraLight, .thin: 200
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }

    private static func uiWeight(_ w: Font.Weight) -> UIFont.Weight {
        switch w {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }

    /// Текст інтерфейсу: системний SF Pro. Нейтральний і дорогий, на великих розмірах сам перемикається на Display.
    private static func nunito(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        .systemFont(ofSize: size, weight: uiWeight(weight))
    }

    /// Заголовки й суми: New York, системний шрифт із засічками. Жирне тут важке, тож усе від 600 - напівжирне.
    private static func cousine(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        let w: UIFont.Weight = wght(weight) >= 600 ? .semibold : (wght(weight) >= 500 ? .medium : .regular)
        let base = UIFont.systemFont(ofSize: size, weight: w)
        guard let d = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: d, size: size)
    }

    /// Хеші, коди, реквізити: справжній моноширинний.
    static func code(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        FontCache.shared.font("c", size, wght(weight)) { Font(UIFont.monospacedSystemFont(ofSize: size, weight: uiWeight(weight))) }
    }

    static func code(style: UIFont.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return FontCache.shared.font("C" + style.rawValue + "\(UIFontMetrics(forTextStyle: style).scaledValue(for: 100))", base, wght(weight)) {
            Font(UIFontMetrics(forTextStyle: style).scaledFont(for: UIFont.monospacedSystemFont(ofSize: base, weight: uiWeight(weight))))
        }
    }

    /// Текст інтерфейсу фіксованого розміру.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        FontCache.shared.font("u", size, wght(weight)) { Font(nunito(size, weight)) }
    }

    /// Текстовий стиль, що слухає Dynamic Type.
    static func ui(style: UIFont.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return FontCache.shared.font("U" + style.rawValue + "\(UIFontMetrics(forTextStyle: style).scaledValue(for: 100))", base, wght(weight)) {
            Font(UIFontMetrics(forTextStyle: style).scaledFont(for: nunito(base, weight)))
        }
    }

    /// Cousine: хеші, суми, заголовки.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        FontCache.shared.font("m", size, wght(weight)) { Font(cousine(size, weight)) }
    }

    static func mono(style: UIFont.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return FontCache.shared.font("M" + style.rawValue + "\(UIFontMetrics(forTextStyle: style).scaledValue(for: 100))", base, wght(weight)) {
            Font(UIFontMetrics(forTextStyle: style).scaledFont(for: cousine(base, weight)))
        }
    }
}

/// Готові шрифти за ключем. Кожен екран просить їх сотні разів за один прохід body, а збирати UIFont
/// із дескриптора щоразу - зайва робота.
final class FontCache: @unchecked Sendable {
    static let shared = FontCache()
    private var store: [String: Font] = [:]
    private let lock = NSLock()

    func font(_ kind: String, _ size: CGFloat, _ weight: CGFloat, make: () -> Font) -> Font {
        let key = "\(kind)|\(size)|\(weight)"
        lock.lock(); defer { lock.unlock() }
        if let f = store[key] { return f }
        let f = make()
        store[key] = f
        return f
    }
}
