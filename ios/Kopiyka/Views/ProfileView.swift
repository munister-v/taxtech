import PhotosUI
import SwiftUI

/// Фото профілю: лежить у пам'яті телефону, центральний квадрат 320 пт. Лічильник `rev` оновлює всі аватари.
enum ProfilePhoto {
    static let revKey = "profilePhotoRev"
    private static var url: URL { URL.applicationSupportDirectory.appending(path: "profile.jpg") }

    static func load() -> UIImage? { UIImage(contentsOfFile: url.path) }

    static func save(_ data: Data) -> Bool {
        guard let src = UIImage(data: data) else { return false }
        let side = min(src.size.width, src.size.height)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 320), format: fmt).image { _ in
            let k = 320 / side
            src.draw(in: CGRect(x: -(src.size.width - side) / 2 * k, y: -(src.size.height - side) / 2 * k,
                                width: src.size.width * k, height: src.size.height * k))
        }
        guard let jpeg = img.jpegData(compressionQuality: 0.88) else { return false }
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        guard (try? jpeg.write(to: url, options: .atomic)) != nil else { return false }
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: revKey) + 1, forKey: revKey)
        return true
    }

    static func remove() {
        try? FileManager.default.removeItem(at: url)
        UserDefaults.standard.set(UserDefaults.standard.integer(forKey: revKey) + 1, forKey: revKey)
    }
}

/// Профіль: жовта картка власника, розділи банку, безпека, особистий облік і лабораторія, запрошення, вихід.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var me: API.Me?
    @State private var achievements: API.AchievementList?
    @State private var personal: Personal?
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var choosingAvatar = false
    @State private var kycVerified = KYCState.load().level == .verified
    @State private var showKYC = false
    @AppStorage(ProfilePhoto.revKey) private var photoRev = 0

    enum Personal: String, Identifiable {
        case money, receipt, assistant, lab
        var id: String { rawValue }
    }

    private var inviteCode: String { "TT" + String((me?.phone ?? "").filter(\.isNumber).suffix(6)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ScreenTitle(L("Профіль").s)
                    header
                    RowGroup(title: L("Гроші").s) {
                        nav(L("Депозити").s, "banknote") { DepositsView() }
                        nav(L("Кредити").s, "percent") { CreditsView() }
                        nav(L("Цілі").s, "target") { GoalsView() }
                        nav(L("Донати").s, "heart") { DonationsView() }
                        nav(L("Виплати").s, "arrow.down") { PayoutsView() }
                        nav(L("Борги").s, "person.2") { DebtsView() }
                    }
                    RowGroup(title: L("Платежі").s) {
                        nav(L("Контакти й шаблони").s, "person.crop.rectangle.stack") { ContactsView() }
                        nav(L("Ліміти й регулярні платежі").s, "calendar") { LimitsView() }
                        nav(L("Виписки").s, "doc.text") { StatementsView() }
                        nav(L("Аналітика").s, "chart.bar") { AnalyticsView() }
                    }
                    RowGroup(title: L("Безпека").s) {
                        nav(Biometrics.kind == .none ? L("PIN, пароль і пристрої").s : L("PIN, \(Biometrics.title), пароль").s, "lock") { SecurityView() }
                        nav(L("Сповіщення").s, "bell") { NoticesView() }
                        nav(Tx("Дані та приватність", "Data & privacy", "Данные и приватность"), "hand.raised") { DataControlsView() }
                        NavigationLink { AchievementsView() } label: {
                            IconRow(title: L("Досягнення").s, symbol: "trophy",
                                    detail: achievements.map { L("\($0.done) з \($0.total)").s })
                        }
                        .buttonStyle(.plain)
                    }
                    RowGroup(title: L("На телефоні").s) {
                        sheet(L("Облік витрат").s, "list.bullet.rectangle", .money)
                        sheet(L("Розпізнати чек").s, "doc.text.viewfinder", .receipt)
                        sheet(L("Помічник").s, "text.bubble", .assistant)
                        if model.expert { sheet(L("Журнал рішень").s, "arrow.triangle.branch", .lab) }
                    }
                    RowGroup(title: L("Мова").s) {
                        ForEach(Lang.allCases) { l in
                            Button { Lang.set(l) } label: {
                                IconRow(title: l.title, symbol: Lang.current == l ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    invite
                    VStack(spacing: 10) {
                        Button(L("Вийти").s) { model.signOut() }.buttonStyle(LineButton())
                        Button(L("Видалити акаунт").s) { confirmDelete = true }
                            .font(Theme.ui(style: .subheadline))
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        MarkView(height: 18, color: .secondary)
                        Text(Brand.lab).font(Theme.ui(style: .caption1)).foregroundStyle(.secondary).expertOnly()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                async let m = model.api.me()
                async let a = model.api.achievements()
                me = try? await m
                achievements = try? await a
            }
            .sheet(isPresented: $choosingAvatar) { AvatarPicker(initials: initials) }
            .sheet(isPresented: $showKYC, onDismiss: { kycVerified = KYCState.load().level == .verified }) { KYCView(prefill: me?.fullName ?? "") }
            .sheet(item: $personal) { p in
                Group {
                    switch p {
                    case .money: MoneyView()
                    case .receipt: ReceiptView(closable: true)
                    case .assistant: AssistantView()
                    case .lab: LabView()
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(L("Видалити акаунт назавжди?").s, isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(L("Видалити акаунт і всі дані").s, role: .destructive) {
                    Task {
                        do { try await model.deleteAccount() } catch { deleteError = error.localizedDescription }
                    }
                }
            } message: {
                Text(L("Рахунок, картки, депозити, кредити й історія операцій зникнуть. Облік витрат на телефоні залишиться.").s)
            }
            .alert(L("Не вдалося видалити").s, isPresented: .init(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button(L("Гаразд").s) {}
            } message: { Text(deleteError ?? "") }
        }
    }

    // MARK: Картка власника

    private var header: some View {
        HeroPanel {
            HStack(alignment: .center, spacing: 16) {
                Button { choosingAvatar = true } label: {
                    AvatarView(initials: initials, size: 76)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil").font(Theme.ui(11, .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 26, height: 26)
                                .background(Theme.accent, in: .circle)
                                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2.5))
                                .offset(x: 2, y: 2)
                        }
                }
                .buttonStyle(PressScale())
                .accessibilityLabel(L("Змінити фото").s)
                VStack(alignment: .leading, spacing: 3) {
                    Text(DisplayName.of(me?.fullName).isEmpty ? " " : DisplayName.of(me?.fullName)).font(Theme.ui(24, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    if let e = me?.email, !e.isEmpty {
                        Text(e).font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Button { showKYC = true } label: { KYCBadge(verified: kycVerified) }
                        .buttonStyle(.plain).padding(.top, 4)
                }
            }
            if let me {
                HStack(spacing: 10) {
                    if let p = me.phone, !p.isEmpty, !p.hasPrefix("apple:") {
                        fact(p, L("Телефон").s, "phone")
                    }
                }
                .padding(.top, 18)
            }
        }
        .padding(.top, 8)
    }

    private var initials: String {
        let s = DisplayName.initials(me?.fullName)
        return s.isEmpty ? "TT" : s
    }

    private func fact(_ value: String, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(Theme.ui(style: .subheadline, .bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(Theme.ui(style: .caption1, .medium)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: symbol).font(Theme.ui(style: .caption1, .bold))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.bg, in: .rect(cornerRadius: 14, style: .continuous))
    }

    // MARK: Запрошення

    private var invite: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Запросити друга").s).font(Theme.ui(style: .headline))
                Text(inviteCode).font(Theme.mono(style: .title3, .bold))
            }
            Spacer()
            ShareLink(item: URL(string: "https://bank.munister.com.ua/?ref=\(inviteCode)")!,
                      message: Text(L("TaxTech: картки, депозити й перекази на токенах TAX").s)) {
                Image(systemName: "square.and.arrow.up")
                    .font(Theme.ui(17, .semibold))
                    .frame(width: 48, height: 48)
                    .background(Theme.ink, in: .circle)
                    .foregroundStyle(Theme.onInk)
            }
            .buttonStyle(PressScale())
            .accessibilityLabel(L("Поділитися").s)
        }
        .padding(16)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func nav<D: View>(_ title: String, _ symbol: String, @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: { IconRow(title: title, symbol: symbol) }
            .buttonStyle(.plain)
    }

    private func sheet(_ title: String, _ symbol: String, _ p: Personal) -> some View {
        Button { personal = p } label: { IconRow(title: title, symbol: symbol) }
            .buttonStyle(.plain)
    }
}
