import EdgeRouter
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var showConsent = false
    @State private var selection = AppTab.overview
    @State private var pinRequired = false
    @State private var splash = true

    enum AppTab: Hashable { case overview, operations, cards, taxes, shop }

    var body: some View {
        Group {
            if !model.signedIn {
                AuthView()
            } else if pinRequired && !model.bankUnlocked {
                PinLockView()
            } else {
                TabView(selection: $selection) {
                    Tab(L("Огляд").s, systemImage: "square.grid.2x2", value: AppTab.overview) { OverviewView { selection = $0 } }
                    Tab(L("Операції").s, systemImage: "waveform.path.ecg", value: AppTab.operations) { OperationsView() }
                    Tab(L("Картки").s, systemImage: "creditcard", value: AppTab.cards) { CardsTab() }
                    Tab(L("Податки").s, systemImage: "percent", value: AppTab.taxes) { TaxesView() }
                    Tab(L("Магазин").s, systemImage: "bag", value: AppTab.shop) { ShopView() }
                }
                .tint(Theme.tint)
                .tabBarMinimizeBehavior(.onScrollDown)
                // на «Огляді» темна шапка сама під статус-баром, світла смуга там зайва
                .overlay(alignment: .top) { if selection != .overview { TopFade() } }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .animation(.smooth(duration: 0.45), value: model.signedIn)
        .animation(.smooth(duration: 0.35), value: model.bankUnlocked)
        .overlay { if splash { LaunchSplash { splash = false } } }
        .task(id: model.signedIn) {
            pinRequired = model.signedIn ? ((try? await model.api.hasPin()) ?? false) : false
        }
        .onChange(of: phase) { _, p in
            // з фону банк знову просить PIN
            guard p == .background else { return }
            model.bankUnlocked = false
            Task { pinRequired = model.signedIn ? ((try? await model.api.hasPin()) ?? pinRequired) : false }
        }
        .onAppear {
            #if DEBUG
            // simctl launch з SIMCTL_CHILD_KOPIYKA_TAB=operations|cards|taxes|shop
            switch ProcessInfo.processInfo.environment["KOPIYKA_TAB"] {
            case "operations": selection = .operations
            case "cards": selection = .cards
            case "taxes": selection = .taxes
            case "shop": selection = .shop
            default: break
            }
            #endif
            showConsent = !model.consentAsked
            #if DEBUG
            if ProcessInfo.processInfo.environment["KOPIYKA_SHOW_CONSENT"] == "1" { showConsent = true }
            #endif
        }
        .fullScreenCover(isPresented: $showConsent) { ConsentView() }
    }
}

enum Format {
    static func money(_ v: Double) -> String {
        // валюта застосунку - навчальний токен TAX, не гривня
        v.formatted(.number.precision(.fractionLength(2)).locale(Lang.current.locale)) + " TAX"
    }

    /// Сума без «,00»: копійки лише якщо вони є.
    static func short(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...2)).locale(Lang.current.locale)) + " TAX"
    }

    static func ms(_ v: Double) -> String {
        v < 10 ? String(format: L("%.1f мс").s, v) : v < 1000 ? L("\(Int(v)) мс").s : String(format: L("%.1f с").s, v / 1000)
    }

    static func ms(_ d: Duration) -> String {
        ms(Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15)
    }

    static func joules(_ v: Double) -> String {
        v < 0.1 ? String(format: L("%.3f Дж").s, v) : String(format: L("%.2f Дж").s, v)
    }
}

/// Де виконалась задача і чому - простий текст під результатом.
struct RoutedNote: View {
    let record: DecisionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary)
                .font(.subheadline)
                .monospacedDigit()
            Text(record.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    var summary: String {
        var parts = [record.placement.title, Format.ms(record.latencyMs), Format.joules(record.energyJ)]
        if record.escalated { parts.append(L("телефон засумнівався").s) }
        if record.redactions > 0 { parts.append(L("замасковано \(record.redactions)").s) }
        return parts.joined(separator: ", ")
    }
}

/// «Правильно / ні» - відгук, з якого метод вчиться.
struct FeedbackButtons: View {
    @Environment(AppModel.self) private var model
    let id: UUID
    @State private var sent: Bool?

    var body: some View {
        HStack(spacing: 16) {
            Button { send(true) } label: { Image(systemName: sent == true ? "hand.thumbsup.fill" : "hand.thumbsup") }
                .accessibilityLabel(L("Правильно").s)
            Button { send(false) } label: { Image(systemName: sent == false ? "hand.thumbsdown.fill" : "hand.thumbsdown") }
                .accessibilityLabel(L("Неправильно").s)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .disabled(sent != nil)
    }

    private func send(_ correct: Bool) {
        sent = correct
        Task { await model.feedback(id, correct: correct) }
    }
}
