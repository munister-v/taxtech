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
                    ScreenTitle(title: L("Лабораторія").s) { MarkView(height: 28, color: Theme.gold) }
                    hero.rise(1)
                    VStack(spacing: 12) {
                        ForEach(Array(Experiment.allCases.enumerated()), id: \.element) { i, e in
                            NavigationLink(value: e) { card(e) }
                                .buttonStyle(PressScale())
                                .rise(2 + i)
                        }
                    }
                    RowGroup(title: L("Дані").s) {
                        Button { journal = true } label: {
                            IconRow(title: L("Журнал рішень").s, symbol: "list.bullet.rectangle",
                                    detail: model.decisions.isEmpty ? nil : "\(model.decisions.count)")
                        }
                        .buttonStyle(.plain)
                    }
                    .rise(5)
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

    private var hero: some View {
        let total = Experiment.allCases.count
        return HeroPanel {
            HeroCaption(L("Досліди").s)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(progress.passedCount)").font(Theme.balance(52)).monospacedDigit()
                Text(L("з \(total) пройдено").s).font(.title3).foregroundStyle(.secondary)
            }
            .padding(.top, 2)
            HStack(spacing: 6) {
                ForEach(Experiment.allCases) { e in
                    Capsule().fill(progress.passed(e) ? Theme.accent : Theme.ink.opacity(0.14)).frame(height: 5)
                }
            }
            .padding(.top, 12)
        }
    }

    private func card(_ e: Experiment) -> some View {
        HStack(spacing: 16) {
            Image(systemName: e.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 48, height: 48)
                .overlay(Circle().strokeBorder(Theme.gold.opacity(0.5), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title).font(.headline)
                Text(e.line).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            if progress.passed(e) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            } else {
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .goldEdge(22)
        .contentShape(.rect)
    }
}

/// «Пісочниця» без входу: що всередині й вхід. Сам банк відкривається лише після входу.
struct SandboxGate: View {
    @State private var signIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenTitle(L("Пісочниця").s)
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
