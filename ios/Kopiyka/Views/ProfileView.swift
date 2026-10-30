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

/// Круглий аватар: фото, а без нього - ініціали.
struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40
    @AppStorage(ProfilePhoto.revKey) private var rev = 0

    var body: some View {
        Group {
            if let img = ProfilePhoto.load() {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Text(initials).font(.custom("Futura-Medium", size: size * 0.38))
                    .foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.goldFill)
            }
        }
        .id(rev)
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().strokeBorder(Theme.edge, lineWidth: 1))
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
    @State private var pick: PhotosPickerItem?
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
                    ScreenTitle("Профіль")
                    header
                    RowGroup(title: "Гроші") {
                        nav("Депозити", "banknote") { DepositsView() }
                        nav("Кредити", "percent") { CreditsView() }
                        nav("Цілі", "target") { GoalsView() }
                        nav("Донати", "heart") { DonationsView() }
                        nav("Виплати", "arrow.down") { PayoutsView() }
                        nav("Борги", "person.2") { DebtsView() }
                    }
                    RowGroup(title: "Платежі") {
                        nav("Контакти й шаблони", "person.crop.rectangle.stack") { ContactsView() }
                        nav("Ліміти й регулярні платежі", "calendar") { LimitsView() }
                        nav("Виписки", "doc.text") { StatementsView() }
                        nav("Аналітика", "chart.bar") { AnalyticsView() }
                    }
                    RowGroup(title: "Безпека") {
                        nav(Biometrics.kind == .none ? "PIN, пароль і пристрої" : "PIN, \(Biometrics.title), пароль", "lock") { SecurityView() }
                        nav("Сповіщення", "bell") { NoticesView() }
                        NavigationLink { AchievementsView() } label: {
                            IconRow(title: "Досягнення", symbol: "trophy",
                                    detail: achievements.map { "\($0.done) з \($0.total)" })
                        }
                        .buttonStyle(.plain)
                    }
                    RowGroup(title: "На телефоні") {
                        sheet("Облік витрат", "list.bullet.rectangle", .money)
                        sheet("Розпізнати чек", "doc.text.viewfinder", .receipt)
                        sheet("Помічник", "text.bubble", .assistant)
                        sheet("Лабораторія", "flask", .lab)
                    }
                    invite
                    VStack(spacing: 10) {
                        Button("Вийти") { model.signOut() }.buttonStyle(LineButton())
                        Button("Видалити акаунт") { confirmDelete = true }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        MarkView(height: 18, color: .secondary)
                        Text(Brand.lab).font(.caption).foregroundStyle(.secondary)
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
            .confirmationDialog("Видалити акаунт назавжди?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Видалити акаунт і всі дані", role: .destructive) {
                    Task {
                        do { try await model.deleteAccount() } catch { deleteError = error.localizedDescription }
                    }
                }
            } message: {
                Text("Рахунок, картки, депозити, кредити й історія операцій зникнуть. Облік витрат на телефоні залишиться.")
            }
            .alert("Не вдалося видалити", isPresented: .init(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("Гаразд") {}
            } message: { Text(deleteError ?? "") }
        }
    }

    // MARK: Картка власника

    private var header: some View {
        HeroPanel {
            HStack(alignment: .center, spacing: 16) {
                PhotosPicker(selection: $pick, matching: .images) {
                    AvatarView(initials: initials, size: 76)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill").font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 26, height: 26)
                                .background(Theme.accent, in: .circle)
                                .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 2.5))
                                .offset(x: 2, y: 2)
                        }
                }
                .accessibilityLabel("Змінити фото")
                .contextMenu {
                    if ProfilePhoto.load() != nil {
                        Button("Видалити фото", systemImage: "trash", role: .destructive) { ProfilePhoto.remove() }
                    }
                }
                .onChange(of: pick) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) { _ = ProfilePhoto.save(data) }
                        pick = nil
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(me?.fullName ?? " ").font(.custom("Futura-Medium", size: 24)).lineLimit(1).minimumScaleFactor(0.7)
                    if let e = me?.email, !e.isEmpty {
                        Text(e).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            if let me {
                HStack(spacing: 10) {
                    if let p = me.phone, !p.isEmpty, !p.hasPrefix("apple:") {
                        fact(p, "Телефон", "phone")
                    }
                }
                .padding(.top, 18)
            }
        }
        .padding(.top, 8)
    }

    private var initials: String {
        let s = (me?.fullName ?? "").split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        return s.isEmpty ? "TT" : s
    }

    private func fact(_ value: String, _ label: String, _ symbol: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.subheadline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.caption.weight(.bold))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.bg, in: .rect(cornerRadius: 14, style: .continuous))
    }

    // MARK: Запрошення

    private var invite: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Запросити друга").font(.headline)
                Text(inviteCode).font(.title3.monospaced().weight(.bold))
            }
            Spacer()
            ShareLink(item: URL(string: "https://bank.munister.com.ua/?ref=\(inviteCode)")!,
                      message: Text("TaxTech: картки, депозити й перекази на токенах TAX")) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(Theme.ink, in: .circle)
                    .foregroundStyle(Theme.onInk)
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Поділитися")
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
