import SwiftUI

/// Вкладка «Ще»: усе, що не лізе на панель, у вигляді плиток замість стандартного списку iOS.
struct MoreHub: View {
    @Environment(AppModel.self) private var model
    @State private var profile = false
    @State private var shop = false
    @State private var lab = false
    @State private var terminal = false
    @State private var sheet: Sheet?
    @State private var kyc = KYCState.load()
    @State private var name = ""

    enum Sheet: String, Identifiable { case money, receipt, assistant; var id: String { rawValue } }

    /// Зовнішній перехід (наприклад, «в магазин» з іншої вкладки).
    @Binding var jump: Jump?
    enum Jump: Equatable { case shop, lab }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ScreenTitle(Tx("Ще", "More", "Ещё"))
                    profileCard
                    heroes
                    section(Tx("Гроші", "Money", "Деньги"), [
                        tile(L("Депозити").s, "banknote") { DepositsView() },
                        tile(L("Кредити").s, "percent") { CreditsView() },
                        tile(L("Цілі").s, "target") { GoalsView() },
                        tile(L("Донати").s, "heart") { DonationsView() },
                        tile(L("Виплати").s, "arrow.down") { PayoutsView() },
                        tile(L("Борги").s, "person.2") { DebtsView() },
                    ])
                    section(Tx("Платежі", "Payments", "Платежи"), [
                        tile(Tx("Контакти", "Contacts", "Контакты"), "person.crop.rectangle.stack") { ContactsView() },
                        tile(Tx("Ліміти", "Limits", "Лимиты"), "calendar") { LimitsView() },
                        tile(L("Виписки").s, "doc.text") { StatementsView() },
                        tile(L("Аналітика").s, "chart.bar") { AnalyticsView() },
                    ])
                    section(Tx("На телефоні", "On your phone", "На телефоне"), [
                        action(L("Облік витрат").s, "list.bullet.rectangle") { sheet = .money },
                        action(L("Розпізнати чек").s, "doc.text.viewfinder") { sheet = .receipt },
                        action(L("Помічник").s, "text.bubble") { sheet = .assistant },
                        tile(Tx("Приватність", "Privacy", "Приватность"), "hand.raised") { DataControlsView() },
                    ])
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 120)
            }
            .auroraBackground()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $profile, onDismiss: { kyc = KYCState.load() }) { ProfileView().presentationDragIndicator(.visible) }
            .sheet(item: $sheet) { s in
                Group {
                    switch s {
                    case .money: MoneyView()
                    case .receipt: ReceiptView(closable: true)
                    case .assistant: AssistantView()
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $terminal) { PosTerminalView() }
            .fullScreenCover(isPresented: $shop) { closable { ShopView() } }
            .fullScreenCover(isPresented: $lab) { closable { LabHome() } }
            .task { name = (try? await model.api.me())?.fullName ?? "" }
            .onAppear { kyc = KYCState.load(); consume() }
            .onChange(of: jump) { _, _ in consume() }
        }
    }

    private func consume() {
        guard let j = jump else { return }
        jump = nil
        switch j {
        case .shop: shop = true
        case .lab: lab = true
        }
    }

    private func closable<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ZStack(alignment: .topLeading) {
            content()
            Button { shop = false; lab = false } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40).glassCircle()
            }
            .buttonStyle(PressScale())
            .padding(.leading, 16).padding(.top, 6)
        }
    }

    // MARK: Профіль

    private var profileCard: some View {
        Button { profile = true } label: {
            HStack(spacing: 14) {
                AvatarView(initials: initials, size: 58)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name.isEmpty ? "TaxTech" : name).font(.title3.weight(.semibold)).lineLimit(1)
                    KYCBadge(verified: kyc.level == .verified)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
            }
            .padding(16)
            .background(Theme.surface, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.line, lineWidth: Theme.hairline))
            .foregroundStyle(Theme.ink)
        }
        .buttonStyle(PressScale())
    }

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(parts).uppercased()
    }

    // MARK: Великі плитки

    @ViewBuilder private var heroes: some View {
        VStack(spacing: 12) {
            if Build.shop {
                hero(title: "SAINT AGNES", sub: Tx("Магазин · оплата в TAX", "Shop · pay in TAX", "Магазин · оплата в TAX"), symbol: "bag.fill",
                     colors: [Color(red: 0.86, green: 0.07, blue: 0.17), Color(red: 0.30, green: 0.02, blue: 0.10)]) { shop = true }
            }
            HStack(spacing: 12) {
                hero(title: Tx("Термінал", "Terminal", "Терминал"), sub: "POS · 3-D Secure", symbol: "wave.3.right", compact: true,
                     colors: [Theme.goldLight, Theme.gold], dark: true) { terminal = true }
                if model.expert {
                    hero(title: "Studio", sub: Tx("Лабораторія", "Lab", "Лаборатория"), symbol: "flask.fill", compact: true,
                         colors: [Color(white: 0.28), Color(white: 0.08)]) { lab = true }
                }
            }
        }
    }

    private func hero(title: String, sub: String, symbol: String, compact: Bool = false, colors: [Color], dark: Bool = false,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: symbol)
                    .font(.system(size: compact ? 54 : 84, weight: .ultraLight))
                    .foregroundStyle((dark ? Color.black : Color.white).opacity(0.22))
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(compact ? .headline : .system(size: 26, weight: .semibold)).tracking(compact ? 0 : 3)
                    Text(sub).font(.footnote.weight(.medium)).opacity(0.75)
                }
                .foregroundStyle(dark ? Theme.onAccent : Color.white)
                .padding(18)
            }
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 112 : 150)
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .shadow(color: colors[0].opacity(0.25), radius: 18, y: 10)
        }
        .buttonStyle(PressScale())
    }

    // MARK: Сітка

    private func section(_ title: String, _ tiles: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.weight(.semibold)).tracking(-0.3)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { $1 }
            }
        }
    }

    private static let hues: [Color] = [
        Color(red: 0.86, green: 0.18, blue: 0.28), Color(red: 0.95, green: 0.62, blue: 0.20), Color(red: 0.12, green: 0.62, blue: 0.50),
        Color(red: 0.35, green: 0.40, blue: 0.92), Color(red: 0.16, green: 0.62, blue: 0.82), Color(red: 0.62, green: 0.30, blue: 0.80),
    ]

    private func tileBody(_ title: String, _ symbol: String) -> some View {
        let hue = Self.hues[Int(symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) } % Self.hues.count)]
        return VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(LinearGradient(colors: [hue.opacity(0.95), hue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)
                .shadow(color: hue.opacity(0.5), radius: 8, y: 4)
            Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(16)
        .background(LinearGradient(colors: [hue.opacity(0.34), hue.opacity(0.08), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: .rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(hue.opacity(0.25), lineWidth: 1))
        .foregroundStyle(Theme.ink)
    }

    private func tile<D: View>(_ title: String, _ symbol: String, @ViewBuilder _ destination: @escaping () -> D) -> AnyView {
        AnyView(NavigationLink { destination() } label: { tileBody(title, symbol) }.buttonStyle(PressScale()))
    }

    private func action(_ title: String, _ symbol: String, _ run: @escaping () -> Void) -> AnyView {
        AnyView(Button(action: run) { tileBody(title, symbol) }.buttonStyle(PressScale()))
    }
}
