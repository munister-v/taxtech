import EdgeRouter
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var showConsent = false
    @State private var selection = AppTab.overview
    @State private var pinRequired = false
    @State private var splash = true
    @State private var moreJump: MoreHub.Jump?

    enum AppTab: Hashable { case lab, overview, operations, cards, taxes, shop, more }

    var body: some View {
        Group {
            if !model.signedIn && !model.expert {
                // без входу вкладка одна: окрема панель з єдиним «Home» лише заважає, тож TabView не показуємо
                SandboxGate()
            } else {
            TabView(selection: $selection) {
                if model.signedIn {
                    Tab(AppTab.overview.title, systemImage: "square.stack.3d.up", value: AppTab.overview) { bank { OverviewView { selection = $0 } } }
                    Tab(AppTab.operations.title, systemImage: "list.bullet.rectangle", value: AppTab.operations) { bank { OperationsView() } }
                    Tab(AppTab.cards.title, systemImage: "creditcard", value: AppTab.cards) { bank { CardsTab() } }
                    Tab(AppTab.taxes.title, systemImage: "percent", value: AppTab.taxes) { bank { TaxesView() } }
                    if Build.shop || model.expert {
                        Tab(Tx("Ще", "More", "Ещё"), systemImage: "ellipsis", value: AppTab.more) { bank { MoreHub(jump: $moreJump) } }
                    }
                } else {
                    Tab(AppTab.overview.title, systemImage: "square.stack.3d.up", value: AppTab.overview) { SandboxGate() }
                }
                if model.expert && !model.signedIn {
                    Tab("Studio", systemImage: "flask", value: AppTab.lab) { LabHome() }
                }
            }
            .tint(Theme.tint)
            .toolbarVisibility(model.signedIn || model.expert ? .automatic : .hidden, for: .tabBar)
            .tabBarMinimizeBehavior(.onScrollDown)
            // на «Огляді» темна шапка сама під статус-баром, світла смуга там зайва
            .overlay(alignment: .top) { if selection != .overview && selection != .lab && selection != .more { TopFade() } }
            }
        }
        .animation(.smooth(duration: 0.45), value: model.signedIn)
        .animation(.smooth(duration: 0.35), value: model.bankUnlocked)
        .overlay { if splash { LaunchSplash { splash = false } } }
        .task(id: model.signedIn) {
            pinRequired = model.signedIn ? ((try? await model.api.hasPin()) ?? false) : false
        }
        .onChange(of: model.jumpTab) { _, tab in
            guard let tab else { return }
            model.jumpTab = nil
            if model.signedIn && (tab == .shop || tab == .lab) {
                selection = .more
                moreJump = tab == .shop ? .shop : .lab
            } else {
                selection = tab
            }
        }
        .onChange(of: model.signedIn) { _, signedIn in
            if !signedIn { selection = .overview }
        }
        .onChange(of: model.expert) { _, on in
            if !on && selection == .lab { selection = .overview }
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
            if ProcessInfo.processInfo.environment["KOPIYKA_EXPERT"] == "1" || ProcessInfo.processInfo.environment["KOPIYKA_EXPERIMENT"] != nil { model.expert = true }
            switch ProcessInfo.processInfo.environment["KOPIYKA_TAB"] {
            case "more": selection = .more
            case "lab": selection = .lab
            case "overview": selection = .overview
            case "operations": selection = .operations
            case "cards": selection = .cards
            case "taxes": selection = .taxes
            case "shop": selection = .more; moreJump = .shop
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

extension RootView {
    /// Банк відкривається кодом, якщо він задан; лабораторія кодом не закрита.
    @ViewBuilder func bank<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if pinRequired && !model.bankUnlocked { PinLockView() } else { content() }
    }
}

enum Format {
    static func money(_ v: Double) -> String {
        // валюта застосунку - навчальний токен TAX, не гривня
        v.formatted(.number.precision(.fractionLength(2)).locale(Lang.current.locale)) + " TAX"
    }

    /// Число без «,00»: копійки лише якщо вони є, і тоді завжди дві цифри («350,50», не «350,5»).
    static func amount(_ v: Double) -> String {
        let whole = abs(v - v.rounded()) < 0.005
        return v.formatted(.number.precision(.fractionLength(whole ? 0 : 2)).locale(Lang.current.locale))
    }

    /// Сума без «,00»: копійки лише якщо вони є.
    static func short(_ v: Double) -> String { amount(v) + " TAX" }

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
                .font(Theme.ui(style: .subheadline))
                .monospacedDigit()
            Text(record.reason)
                .font(Theme.ui(style: .footnote))
                .foregroundStyle(.secondary)
            LearnLink(.router).padding(.top, 4).expertOnly()
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
        .font(Theme.ui(style: .footnote))
        .foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .disabled(sent != nil)
    }

    private func send(_ correct: Bool) {
        sent = correct
        Task { await model.feedback(id, correct: correct) }
    }
}
