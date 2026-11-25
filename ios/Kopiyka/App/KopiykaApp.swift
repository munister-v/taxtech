import SwiftData
import SwiftUI

@main
struct KopiykaApp: App {
    @State private var model = AppModel()
    @AppStorage(Lang.key) private var langRaw = Lang.current.rawValue

    init() { Appearance.apply() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .environment(\.locale, Lang.current.locale)
                .id(langRaw)
                .task {
                    #if DEBUG && targetEnvironment(simulator)
                    await model.debugSignIn()
                    #endif
                    await model.refresh()
                }
        }
        .modelContainer(for: Expense.self)
    }
}

/// Витрата в особистому обліку. Живе лише на телефоні.
@Model
final class Expense {
    var amount: Double
    var merchant: String
    var category: String
    var date: Date
    /// «Вручну» або «Чек».
    var source: String

    init(amount: Double, merchant: String, category: String, date: Date = .now, source: String) {
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.date = date
        self.source = source
    }
}

/// Заголовки навігації (New York) і таб-бар (SF Pro).
@MainActor
enum Appearance {
    static func apply() {
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        func serif(_ size: CGFloat) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: .semibold)
            return base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
        }
        bar.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: serif(32)), .foregroundColor: UIColor(Theme.ink)]
        bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: serif(17)), .foregroundColor: UIColor(Theme.ink)]
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar

        let item = UITabBarItemAppearance()
        let semi = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
        item.normal.titleTextAttributes = [.font: semi]
        item.selected.titleTextAttributes = [.font: semi]
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
