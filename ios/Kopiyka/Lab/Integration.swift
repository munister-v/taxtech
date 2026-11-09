import SwiftUI

/// Досліди й банк - одне ціле: з екранів банку відкривається дослід про той самий механізм,
/// а в досліді видно, де цей механізм працює в застосунку й на рахунку користувача.

private struct StudioEmbeddedKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Дослід відкрито листом з екрана банку: кнопки «до банку» там зайві.
    var studioEmbedded: Bool {
        get { self[StudioEmbeddedKey.self] }
        set { self[StudioEmbeddedKey.self] = newValue }
    }
}

extension Experiment {
    /// Де в банку працює цей механізм.
    var bankTab: RootView.AppTab? {
        switch self {
        case .router, .fraud, .idempotency, .network: .overview
        case .ledger, .chain, .seal, .merkle: .operations
        case .hold: .cards
        case .tax: .taxes
        case .work: nil
        }
    }
}

extension RootView.AppTab {
    var title: String {
        switch self {
        case .overview: L("Домівка").s
        case .operations: L("Активність").s
        case .cards: L("Картки").s
        case .taxes: L("Податки").s
        case .lab: "Studio"
        case .shop: L("Магазин").s
        case .more: Tx("Ще", "More", "Ещё")
        }
    }
}

/// Рядок на екрані банку: «Як це працює» і назва досліду. Дослід відкривається листом.
struct LearnLink: View {
    let experiment: Experiment
    @State private var open = false

    init(_ experiment: Experiment) { self.experiment = experiment }

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 12) {
                Image(systemName: experiment.symbol).foregroundStyle(Theme.accent).frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Як це працює").s).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(experiment.title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $open) { LearnSheet(experiment: experiment) }
    }
}

/// Дослід листом поверх екрана банку.
struct LearnSheet: View {
    @Environment(\.dismiss) private var dismiss
    let experiment: Experiment

    var body: some View {
        NavigationStack {
            ExperimentScreen(experiment: experiment)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button(L("Готово").s) { dismiss() } }
                }
        }
        .environment(\.studioEmbedded, true)
        .presentationDragIndicator(.visible)
    }
}

/// Внизу досліду: те саме в застосунку. Із входом веде на вкладку банку, без входу - до входу на Piazza.
struct BankBridge: View {
    @Environment(AppModel.self) private var model
    @Environment(\.studioEmbedded) private var embedded
    let experiment: Experiment

    var body: some View {
        if !embedded, let tab = experiment.bankTab {
            Button {
                model.jumpTab = model.signedIn ? tab : .overview
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.signedIn ? L("Відкрити в \(tab.title)").s : L("Увійти, щоб побачити на своєму рахунку").s)
                            .font(.subheadline.weight(.semibold))
                        Text(L("Той самий механізм у банку").s).font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.accent)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1))
                .contentShape(.rect)
            }
            .buttonStyle(PressScale())
        }
    }
}

/// Операції з рахунку користувача для дослідів: найновіші, від старих до нових.
struct LiveOperation: Sendable {
    let title: String
    let amount: Double
    let income: Bool
}

enum LiveData {
    @MainActor static func operations(_ model: AppModel, limit: Int) async -> [LiveOperation] {
        guard model.signedIn, let all = try? await model.api.history() else { return [] }
        return all.sorted { $0.date > $1.date }.prefix(limit).reversed().map {
            LiveOperation(title: TransactionRow(tx: $0).title, amount: $0.amount, income: $0.isIncome)
        }
    }

    /// Середній місячний дохід цього року без поповнень: стартове значення для досліду про податки.
    @MainActor static func monthlyIncome(_ model: AppModel) async -> Double? {
        guard model.signedIn, let all = try? await model.api.history() else { return nil }
        let cal = Calendar.current
        let year = cal.component(.year, from: .now)
        let sum = all.filter { $0.isIncome && $0.txType != "topup" && cal.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.amount }
        guard sum > 0 else { return nil }
        return sum / Double(max(cal.component(.month, from: .now), 1))
    }
}
