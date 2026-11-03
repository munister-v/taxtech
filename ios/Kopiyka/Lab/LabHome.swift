import SwiftUI

/// Головна вкладка: досліди з прогресом і вхід до журналу рішень.
struct LabHome: View {
    @Environment(AppModel.self) private var model
    @State private var progress = LabProgress.shared
    @State private var journal = false
    @State private var path: [Experiment] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    photo.rise(1)
                    progressRow.rise(2)
                    VStack(spacing: 0) {
                        ForEach(Array(Experiment.allCases.enumerated()), id: \.element) { i, e in
                            if i > 0 { Rectangle().fill(Theme.ink.opacity(0.12)).frame(height: 0.5) }
                            NavigationLink(value: e) { row(e) }
                                .buttonStyle(PressScale())
                                .rise(3 + i)
                        }
                    }
                    RowGroup(title: L("Дані").s) {
                        Button { journal = true } label: {
                            IconRow(title: L("Журнал рішень").s, symbol: "list.bullet.rectangle",
                                    detail: model.decisions.isEmpty ? nil : "\(model.decisions.count)")
                        }
                        .buttonStyle(.plain)
                    }
                    .rise(3 + Experiment.allCases.count)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Experiment.self) { ExperimentScreen(experiment: $0) }
            .sheet(isPresented: $journal) { LabView().presentationDragIndicator(.visible) }
            .task { await model.refresh() }
            #if DEBUG
            // simctl launch з SIMCTL_CHILD_KOPIYKA_EXPERIMENT=ledger і SIMCTL_CHILD_KOPIYKA_PART=lab|quiz
            .onAppear {
                if let id = ProcessInfo.processInfo.environment["KOPIYKA_EXPERIMENT"], let e = Experiment(rawValue: id) { path = [e] }
            }
            #endif
        }
    }

    private var photo: some View {
        ZStack(alignment: .bottomLeading) {
            Image("RomeHero")
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 300, alignment: .bottom)
                .clipped()
            LinearGradient(colors: [.clear, Theme.bg.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Досліди").s).caption()
                Text("Studio").font(.display(58, .medium)).tracking(-2).foregroundStyle(.white)
            }
            .padding(20)
        }
        .frame(height: 300)
        .clipShape(.rect(cornerRadius: 6, style: .continuous))
    }

    private var progressRow: some View {
        let total = Experiment.allCases.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(progress.passedCount)").font(.display(40, .medium)).monospacedDigit()
                Text(L("з \(total) пройдено").s).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                ForEach(Experiment.allCases) { e in
                    Rectangle().fill(progress.passed(e) ? Theme.accent : Theme.ink.opacity(0.14)).frame(height: 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ e: Experiment) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(String(format: "%02d", e.number))
                .font(.custom("Futura-Medium", size: 13)).tracking(1.5)
                .foregroundStyle(Theme.gold)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(e.title).font(.display(22, .medium)).tracking(-0.4)
                Text(e.line).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: progress.passed(e) ? "checkmark" : "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(progress.passed(e) ? Theme.accent : Color.secondary)
                .padding(.top, 8)
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

/// «Пісочниця» без входу: що всередині й вхід. Сам банк відкривається лише після входу.
struct SandboxGate: View {
    @State private var signIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenTitle(title: "Piazza", subtitle: L("Пісочниця").s) { EmptyView() }
                RowGroup {
                    row("creditcard", L("Рахунок і картки").s)
                    row("arrow.left.arrow.right", L("Перекази з перевіркою антифроду").s)
                    row("link", L("Операції в хеш-ланцюзі").s)
                }
                Button(L("Увійти").s) { signIn = true }.buttonStyle(InkButton())
                Text(L("Токен TAX - навчальна одиниця, а не гроші.").s)
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .fullScreenCover(isPresented: $signIn) { AuthView(onClose: { signIn = false }) }
    }

    private func row(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
            Text(title).font(.body.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 15)
    }
}
