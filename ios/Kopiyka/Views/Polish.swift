import SwiftUI
import UIKit

// MARK: Тост

/// Коротка підказка над панеллю: «Скопійовано», «Немає посилання».
struct ToastView: View {
    let text: String
    var symbol = "checkmark.circle.fill"

    /// Успіх - м'ята, помилка - тепла червінь, решта - золото.
    private var tone: Color {
        if symbol.hasPrefix("checkmark") { return Theme.income }
        if symbol.hasPrefix("exclamation") || symbol.hasPrefix("xmark") || symbol.contains("slash") { return Theme.alert }
        return Theme.goldLight
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tone)
            Text(text).font(Theme.ui(style: .subheadline, .semibold)).lineLimit(1)
        }
        .foregroundStyle(Theme.ink)
        .padding(.horizontal, 18)
        .frame(height: 44)
        .glassEffect(.regular.tint(Theme.bg.opacity(0.6)), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

extension AppModel {
    /// Показує тост на пару секунд; новий замінює старий.
    func showToast(_ text: String, symbol: String = "checkmark.circle.fill") {
        toastTask?.cancel()
        toastSymbol = symbol
        withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) { toast = text }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { self?.toast = nil }
        }
    }

    /// Копіює текст і каже про це.
    func copy(_ text: String, note: String? = nil) {
        UIPasteboard.general.string = text
        showToast(note ?? L("Скопійовано").s)
    }
}

/// Повторне торкання вибраної вкладки: екрани, що її показують, їдуть нагору.
struct TabRetap: Equatable {
    let tab: RootView.AppTab
    let n: Int
}

private struct RetapScrollTop: ViewModifier {
    @Environment(AppModel.self) private var model
    let tab: RootView.AppTab
    @State private var pos = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($pos)
            .onChange(of: model.retap) { _, r in
                guard r?.tab == tab else { return }
                withAnimation(.smooth(duration: 0.5)) { pos.scrollTo(edge: .top) }
            }
    }
}

extension View {
    func scrollsToTopOnRetap(_ tab: RootView.AppTab) -> some View { modifier(RetapScrollTop(tab: tab)) }
}

// MARK: Клавіатура

extension View {
    /// Кнопка «Готово» над клавіатурою: цифрові клавіатури самі її не мають.
    func keyboardDone() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L("Готово").s) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: Недавні запити

/// Останні запити пошуку: п'ять штук, найновіший першим.
enum RecentSearches {
    private static let key = "recentSearches"
    static var all: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func add(_ q: String) -> [String] {
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > 1 else { return all }
        let list = Array(([t] + all.filter { $0.caseInsensitiveCompare(t) != .orderedSame }).prefix(5))
        UserDefaults.standard.set(list, forKey: key)
        return list
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
