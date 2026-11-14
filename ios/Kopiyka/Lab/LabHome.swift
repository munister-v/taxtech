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
                Text(L("з \(total) пройдено").s).font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary)
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
                .font(Theme.ui(13, .semibold)).tracking(1.5)
                .foregroundStyle(Theme.gold)
                .frame(width: 24, alignment: .leading)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(e.title).font(.display(22, .medium)).tracking(-0.4)
                Text(e.line).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: progress.passed(e) ? "checkmark" : "arrow.up.right")
                .font(Theme.ui(style: .footnote, .semibold))
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
    @State private var policy = false

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
                    .rise(1)
                Spacer(minLength: 0)
                Text(Brand.name)
                    .font(Theme.ui(52, .bold)).tracking(-1.6)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .rise(2)
                VStack(spacing: 12) {
                    Button(L("Увійти").s) { signIn = true }
                        .buttonStyle(WhitePill())
                    VStack(spacing: 4) {
                        Text(L("Токен TAX - навчальна одиниця, а не гроші.").s)
                            .font(Theme.ui(style: .caption1)).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                        Button(PrivacyPolicy.heading) { policy = true }
                            .font(Theme.ui(style: .caption1, .semibold)).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 30).padding(.bottom, model.expert ? 78 : 8) // у режимі Expert знизу плаваюча панель вкладок
                .rise(3)
            }
            .padding(.horizontal, Theme.gutter)
        }
        .fullScreenCover(isPresented: $signIn) { AuthView(onClose: { signIn = false }) }
        .sheet(isPresented: $policy) { PrivacyPolicyView() }
    }

    /// Колода рівно, як на головній: чорна картка спереду, за нею графіт і золото визирають зверху.
    private var fan: some View {
        ZStack {
            GateCard(look: CardLook(material: .metal, color: .gold, pattern: .guilloche), phase: 0.0)
                .padding(.horizontal, 28).offset(y: -40).brightness(-0.22)
            GateCard(look: CardLook(material: .metal, color: .graphite, pattern: .lines), phase: 0.33)
                .padding(.horizontal, 14).offset(y: -20).brightness(-0.1)
            GateCard(look: CardLook(material: .metal, color: .black, pattern: .guilloche, emblem: .seal), phase: 0.66, glow: true)
                .shadow(color: .black.opacity(0.55), radius: 24, y: 16)
        }
        .padding(.top, 40)
        .background {
            SoftOrb(color: Theme.accent.opacity(0.30), radius: 130, blur: 60).scaleEffect(y: 0.3).offset(y: 130)
                .allowsHitTesting(false)
        }
    }
}

/// Тло входу: та сама ніч, що в застосунку - золото зверху-ліворуч, глибокий синій праворуч, низ темніє під кнопки.
struct GateBackdrop: View {
    var body: some View {
        ZStack {
            Theme.bg
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                SoftOrb(color: Theme.auraGold.opacity(0.42), radius: w * 0.55, blur: 120).position(x: w * 0.12, y: h * 0.16)
                SoftOrb(color: Theme.auraCool.opacity(0.60), radius: w * 0.55, blur: 130).position(x: w * 0.98, y: h * 0.40)
                SoftOrb(color: Theme.auraBronze.opacity(0.20), radius: w * 0.35, blur: 100).position(x: w * 0.40, y: h * 0.52)
                Canvas { ctx, size in
                    var r = ctx; r.opacity = 0.16
                    Engraving.rings(in: &r, center: CGPoint(x: size.width * 0.5, y: size.height * 0.36),
                                    from: size.width * 0.3, to: size.width * 1.1, count: 18, color: Theme.auraGold)
                }
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.45), .init(color: Theme.bg, location: 0.78)],
                           startPoint: .top, endPoint: .bottom)
        }
        .drawingGroup()
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
        VirtualCardView(number: "•••• •••• •••• 2026", expiry: "10/30", holder: "TAXTECH", look: look)
            .overlay {
                // щокадру оновлюється лише смуга відблиску, сама картка з її канвасами малюється один раз
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduce)) { tl in
                    let period = 5.0
                    let u = reduce ? 0.5 : ((tl.date.timeIntervalSinceReferenceDate / period + phase).truncatingRemainder(dividingBy: 1))
                    // відблиск займає лише частину циклу, решту часу картка спокійна
                    let k = min(max((u - 0.15) / 0.5, 0), 1)
                    GeometryReader { g in
                        LinearGradient(colors: [.clear, Color(red: 1, green: 0.88, blue: 0.6).opacity(glow ? 0.5 : 0.34), .clear],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: g.size.width * 0.4, height: g.size.height * 2.4)
                            .rotationEffect(.degrees(18))
                            .position(x: -g.size.width * 0.4 + k * g.size.width * 1.8, y: g.size.height / 2)
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

/// Головна кнопка на темному вході: біла капсула з чорним текстом, як у Revolut.
struct WhitePill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.ui(17, .bold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(.white, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, new in new }
    }
}
