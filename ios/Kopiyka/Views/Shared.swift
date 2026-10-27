import EdgeRouter
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    @State private var showConsent = false
    @State private var selection = AppTab.overview
    @State private var pinRequired = false

    enum AppTab: Hashable { case overview, operations, cards, shop, profile }

    var body: some View {
        Group {
            if !model.signedIn {
                AuthView()
            } else if pinRequired && !model.bankUnlocked {
                PinLockView()
            } else {
                TabView(selection: $selection) {
                    Tab("Огляд", systemImage: "square.grid.2x2", value: AppTab.overview) { OverviewView { selection = $0 } }
                    Tab("Операції", systemImage: "waveform.path.ecg", value: AppTab.operations) { OperationsView() }
                    Tab("Картки", systemImage: "creditcard", value: AppTab.cards) { CardsTab() }
                    Tab("Магазин", systemImage: "bag", value: AppTab.shop) { ShopView() }
                    Tab("Профіль", systemImage: "person", value: AppTab.profile) { ProfileView() }
                }
            }
        }
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
            // simctl launch з SIMCTL_CHILD_KOPIYKA_TAB=operations|cards|shop|profile
            switch ProcessInfo.processInfo.environment["KOPIYKA_TAB"] {
            case "operations": selection = .operations
            case "cards": selection = .cards
            case "shop": selection = .shop
            case "profile": selection = .profile
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
        v.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "uk_UA"))) + " ₴"
    }

    static func ms(_ v: Double) -> String {
        v < 10 ? String(format: "%.1f мс", v) : v < 1000 ? "\(Int(v)) мс" : String(format: "%.1f с", v / 1000)
    }

    static func ms(_ d: Duration) -> String {
        ms(Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15)
    }

    static func joules(_ v: Double) -> String {
        v < 0.1 ? String(format: "%.3f Дж", v) : String(format: "%.2f Дж", v)
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
        if record.escalated { parts.append("телефон засумнівався") }
        if record.redactions > 0 { parts.append("замасковано \(record.redactions)") }
        return parts.joined(separator: ", ")
    }
}

/// «Правильно / ні» - відгук, з якого метод вчиться.
struct FeedbackButtons: View {
    @Environment(AppModel.self) private var model
    let id: UUID
    @State private var sent: Bool?

    var body: some View {
        if let sent {
            Text(sent ? "Дякуємо, враховано" : "Враховано як помилку")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 20) {
                Button("Правильно") { send(true) }
                Button("Неправильно") { send(false) }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
    }

    private func send(_ correct: Bool) {
        sent = correct
        Task { await model.feedback(id, correct: correct) }
    }
}
