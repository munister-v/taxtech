import SwiftData
import SwiftUI

@main
struct KopiykaApp: App {
    @State private var model = AppModel()
    @AppStorage(Lang.key) private var langRaw = Lang.current.rawValue

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
