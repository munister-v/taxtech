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

/// Заголовки навігації й таб-бар шрифтами EPRIS.
@MainActor
enum Appearance {
    static func apply() {
        let bar = UINavigationBarAppearance()
        bar.configureWithTransparentBackground()
        if let large = UIFont(name: "Cousine-Bold", size: 30) {
            bar.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large), .foregroundColor: UIColor(Theme.ink)]
        }
        if let inline = UIFont(name: "Cousine-Bold", size: 16) {
            bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline), .foregroundColor: UIColor(Theme.ink)]
        }
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().compactAppearance = bar

        let item = UITabBarItemAppearance()
        if let base = UIFont(name: "Nunito-Regular", size: 10.5) {
            let semi = UIFont(descriptor: base.fontDescriptor.addingAttributes([UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [0x77676874: 650]]), size: 10.5)
            item.normal.titleTextAttributes = [.font: semi]
            item.selected.titleTextAttributes = [.font: semi]
        }
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.stackedLayoutAppearance = item
        tab.inlineLayoutAppearance = item
        tab.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
