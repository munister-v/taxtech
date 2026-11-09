import SwiftUI
import UIKit

/// Шрифти EPRIS: Nunito для тексту й інтерфейсу, Cousine для заголовків, чисел і коду.
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

    private static func nunito(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        guard let base = UIFont(name: "Nunito-Regular", size: size) else { return .systemFont(ofSize: size) }
        let d = base.fontDescriptor.addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [0x77676874: wght(weight)]])
        return UIFont(descriptor: d, size: size)
    }

    private static func cousine(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
        let bold = wght(weight) >= 600
        return UIFont(name: bold ? "Cousine-Bold" : "Cousine-Regular", size: size) ?? .monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// Текст інтерфейсу фіксованого розміру.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { Font(nunito(size, weight)) }

    /// Текстовий стиль, що слухає Dynamic Type.
    static func ui(style: UIFont.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: nunito(base, weight)))
    }

    /// Cousine: хеші, суми, заголовки.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { Font(cousine(size, weight)) }

    static func mono(style: UIFont.TextStyle, _ weight: Font.Weight = .regular) -> Font {
        let base = UIFont.preferredFont(forTextStyle: style).pointSize
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: cousine(base, weight)))
    }
}
