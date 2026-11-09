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
                            IconRow(title: RootView.AppTab.overview.title, symbol: "square.stack.3d.up",
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
    @Environment(AppModel.self) private var model
    @State private var signIn = false
    @State private var float = false

    var body: some View {
        ZStack {
            GateBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    MarkView(height: 26)
                    Spacer()
                    GearButton()
                }
                .padding(.top, 8)
                .rise(0)
                Spacer(minLength: 0)
                fan
                    .padding(.horizontal, 6)
                    .offset(y: float ? -5 : 5)
                    .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: float)
                    .rise(1)
                Spacer(minLength: 0)
                Text(Brand.name)
                    .font(.display(64, .semibold)).tracking(-2.4)
                    .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.90, blue: 0.68), Color(red: 0.86, green: 0.66, blue: 0.34)],
                                                    startPoint: .top, endPoint: .bottom))
                    .frame(maxWidth: .infinity)
                    .rise(2)
                VStack(spacing: 12) {
                    Button(L("Увійти").s) { signIn = true }
                        .buttonStyle(InkButton())
                    Text(L("Токен TAX - навчальна одиниця, а не гроші.").s)
                        .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                }
                .padding(.top, 30).padding(.bottom, model.expert ? 78 : 8) // у режимі Expert знизу плаваюча панель вкладок
                .rise(3)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .onAppear { float = true }
        .fullScreenCover(isPresented: $signIn) { AuthView(onClose: { signIn = false }) }
    }

    /// Три картки віялом: золота, графітова й чорна спереду, під ними золоте сяйво.
    private var fan: some View {
        ZStack {
            Ellipse().fill(Color(red: 1.0, green: 0.25, blue: 0.2).opacity(0.5)).blur(radius: 55)
                .frame(width: 280, height: 80).offset(y: 135)
            GateCard(look: CardLook(material: .metal, color: .gold, pattern: .guilloche), phase: 0.0)
                .scaleEffect(0.8).rotationEffect(.degrees(-14)).offset(x: -28, y: -68)
            GateCard(look: CardLook(material: .glass, color: .graphite, pattern: .microprint), phase: 0.33)
                .scaleEffect(0.86).rotationEffect(.degrees(-6)).offset(x: -10, y: -30)
                .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
            GateCard(look: CardLook(material: .metal, color: .black, pattern: .guilloche), phase: 0.66, glow: true)
                .tilt(cornerRadius: 20)
                .scaleEffect(0.93).rotationEffect(.degrees(3)).offset(x: 6, y: 20)
                .shadow(color: Color(red: 1.0, green: 0.2, blue: 0.2).opacity(0.45), radius: 34, y: 18)
        }
        .frame(height: 330)
    }
}

/// Тло входу: майже чорне бордо, повільні багряні й золоті плями, знизу темніє під кнопку.
struct GateBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.01, blue: 0.02)
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { ctx in
                let t = reduce ? 0 : ctx.date.timeIntervalSinceReferenceDate
                Canvas { g, size in
                    g.addFilter(.blur(radius: 80))
                    let orbs: [(Color, Double, Double, Double, Double)] = [
                        (Color(red: 0.86, green: 0.07, blue: 0.17), 0.28, 0.20, 0.62, 0.85),
                        (Color(red: 0.52, green: 0.03, blue: 0.16), 0.88, 0.40, 0.55, 0.75),
                        (Color(red: 0.98, green: 0.62, blue: 0.24), 0.68, 0.12, 0.26, 0.40),
                    ]
                    for (i, o) in orbs.enumerated() {
                        let k = Double(i) * 2.3
                        let cx = size.width * (o.1 + 0.14 * sin(t * 0.35 + k))
                        let cy = size.height * (o.2 + 0.09 * cos(t * 0.45 + k))
                        let r = size.width * (o.3 + 0.05 * sin(t * 0.5 + k))
                        g.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(o.0.opacity(o.4)))
                    }
                }
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: Color(red: 0.03, green: 0.0, blue: 0.01), location: 0.70)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}

/// Картка для входу: власний вигляд плюс золотий відблиск, що пробігає її раз на кілька секунд.
struct GateCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    let look: CardLook
    let phase: Double
    var glow = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { tl in
            let period = 5.0
            let u = reduce ? 0.5 : ((tl.date.timeIntervalSinceReferenceDate / period + phase).truncatingRemainder(dividingBy: 1))
            // відблиск займає лише частину циклу, решту часу картка спокійна
            let k = min(max((u - 0.15) / 0.5, 0), 1)
            VirtualCardView(number: "•••• •••• •••• 2026", expiry: "10/30", holder: "TAXTECH", look: look)
                .overlay {
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Color(red: 1, green: 0.88, blue: 0.6).opacity(glow ? 0.5 : 0.34), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.45)
                            .rotationEffect(.degrees(18))
                            .offset(x: -g.size.width * 0.5 + k * g.size.width * 1.6)
                            .blendMode(.plusLighter)
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
                .overlay(shape.strokeBorder(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.55).opacity(0.7), .white.opacity(0.05), Color(red: 1, green: 0.7, blue: 0.3).opacity(0.4)],
                                                           startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
    }
}
