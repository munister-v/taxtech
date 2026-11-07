import SwiftUI

/// Головна вкладка: досліди з прогресом і вхід до журналу рішень.
struct LabHome: View {
    @Environment(AppModel.self) private var model
    @State private var progress = LabProgress.shared
    @State private var journal = false
    @State private var path: [Experiment] = []
    @State private var balance: Double?

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
                    RowGroup(title: L("Застосунок").s) {
                        Button { model.jumpTab = .overview } label: {
                            IconRow(title: "Piazza", symbol: "square.stack.3d.up",
                                    detail: model.signedIn ? balance.map(Format.short) : L("Увійти").s)
                        }
                        .buttonStyle(.plain)
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
            .task(id: model.signedIn) {
                balance = model.signedIn ? (try? await model.api.account())?.balance : nil
            }
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
                .font(.system(size: 13, weight: .semibold)).tracking(1.5)
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

/// Piazza без входу: живе тло, картка-предмет і одна кнопка. Шестерня відкриває експертний режим із лабораторією.
struct SandboxGate: View {
    @State private var signIn = false
    @State private var float = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            AuroraField().frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    MarkView(height: 30)
                    Spacer()
                    GearButton()
                }
                .padding(.top, 8)
                .rise(0)
                Spacer(minLength: 0)
                VStack(spacing: 26) {
                    ZStack {
                        VirtualCardView(number: "•••• •••• •••• 2026", expiry: "10/30", holder: "TAXTECH", design: .gold)
                            .scaleEffect(0.9).offset(y: -34).brightness(-0.22).rotationEffect(.degrees(-5))
                        VirtualCardView(number: "•••• •••• •••• 2026", expiry: "10/30", holder: "TAXTECH", design: .dark)
                            .tilt(cornerRadius: 20)
                    }
                    .padding(.top, 34)
                    .offset(y: float ? -6 : 6)
                    .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: float)
                    Text(Brand.name)
                        .font(.display(54, .medium)).tracking(-1.5)
                        .foregroundStyle(Theme.goldFill)
                    VStack(spacing: 4) {
                        Text(Brand.lab).foregroundStyle(.secondary)
                        Text(L("Токен TAX - навчальна одиниця, а не гроші.").s).foregroundStyle(Theme.ink)
                    }
                    .font(.footnote).multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .rise(1)
                Spacer(minLength: 0)
                Button(L("Увійти").s) { signIn = true }
                    .buttonStyle(InkButton())
                    .padding(.bottom, 8)
                    .rise(2)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .onAppear { float = true }
        .fullScreenCover(isPresented: $signIn) { AuthView(onClose: { signIn = false }) }
    }
}
