import SwiftUI

/// Профіль: дані акаунта, усі банківські розділи, безпека, особистий облік і лабораторія, запрошення, вихід.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @State private var me: API.Me?
    @State private var achievements: API.AchievementList?
    @State private var personal: Personal?
    @State private var confirmDelete = false
    @State private var deleteError: String?
    @State private var copied = false

    enum Personal: String, Identifiable {
        case money, receipt, assistant, lab
        var id: String { rawValue }
    }

    private var inviteCode: String { "TT" + String((me?.phone ?? "").filter(\.isNumber).suffix(6)) }

    var body: some View {
        NavigationStack {
            LabForm {
                header
                if let me {
                    Section {
                        Line("Ім'я", me.fullName)
                        if let p = me.phone, !p.isEmpty, !p.hasPrefix("apple:") { Line("Телефон", p) }
                        if let e = me.email, !e.isEmpty { Line("Пошта", e) }
                        if let a = me.bankAccountNumber {
                            Button { UIPasteboard.general.string = a; copied = true } label: {
                                LabeledContent("Рахунок") {
                                    Label(copied ? "Скопійовано" : a, systemImage: copied ? "checkmark" : "doc.on.doc")
                                        .labelStyle(TrailingIcon())
                                        .monospacedDigit()
                                }
                            }
                            .foregroundStyle(Theme.ink)
                        }
                    }
                }
                Section("Гроші") {
                    nav("Депозити", "banknote") { DepositsView() }
                    nav("Кредити", "percent") { CreditsView() }
                    nav("Цілі", "target") { GoalsView() }
                    nav("Донати", "heart") { DonationsView() }
                    nav("Виплати", "arrow.down.circle") { PayoutsView() }
                    nav("Борги", "person.2") { DebtsView() }
                }
                Section("Платежі") {
                    nav("Контакти й шаблони", "person.crop.rectangle.stack") { ContactsView() }
                    nav("Ліміти й регулярні платежі", "calendar") { LimitsView() }
                    nav("Виписки", "doc.text") { StatementsView() }
                    nav("Аналітика", "chart.bar") { AnalyticsView() }
                }
                Section("Безпека") {
                    nav("PIN, пароль і сесії", "lock") { SecurityView() }
                    nav("Сповіщення", "bell") { NoticesView() }
                }
                Section {
                    NavigationLink { AchievementsView() } label: {
                        HStack {
                            Label("Досягнення", systemImage: "trophy")
                            Spacer()
                            if let a = achievements {
                                Text("\(a.done) з \(a.total)").foregroundStyle(.secondary).monospacedDigit()
                            }
                        }
                    }
                }
                Section {
                    sheet("Особистий облік витрат", "list.bullet.rectangle", .money)
                    sheet("Розпізнати чек", "doc.text.viewfinder", .receipt)
                    sheet("Помічник", "text.bubble", .assistant)
                    sheet("Лабораторія", "flask", .lab)
                } header: {
                    Text("На телефоні")
                } footer: {
                    Text("Облік витрат лежить лише на телефоні. Лабораторія показує, де застосунок рахує кожну задачу - на телефоні чи на сервері.")
                }
                invite
                Section {
                    Button("Вийти") { model.signOut() }
                    Button("Видалити акаунт") { confirmDelete = true }
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("TaxTech · \(Brand.lab). Навчальний банк: гроші віртуальні.")
                }
            }
            .labForm()
            .navigationTitle("Профіль")
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
                Text("Рахунок, картки, депозити, кредити й історія віртуальних операцій зникнуть. Витрати в обліку на телефоні залишаться.")
            }
            .alert("Не вдалося видалити", isPresented: .init(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("Гаразд") {}
            } message: { Text(deleteError ?? "") }
        }
    }

    private var header: some View {
        Section {
            VStack(spacing: 10) {
                Initials(name: me?.fullName ?? "", size: 84)
                Text(me?.fullName ?? " ").font(.title2.weight(.semibold))
                Text("Навчальний акаунт").font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        }
    }

    private var invite: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Запросити друга").font(.headline)
                Text("Поділіться TaxTech з одногрупниками").font(.footnote).foregroundStyle(.secondary)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ваш код").caption()
                        Text(inviteCode).font(.title3.monospaced().weight(.semibold))
                    }
                    Spacer()
                    ShareLink(item: URL(string: "https://bank.munister.com.ua/?ref=\(inviteCode)")!,
                              message: Text("Навчальний банк TaxTech: картки, депозити й перекази на віртуальних гривнях")) {
                        Text("Поділитися").font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Theme.ink, in: .rect(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(Theme.onInk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func nav<D: View>(_ title: String, _ symbol: String, @ViewBuilder _ destination: @escaping () -> D) -> some View {
        NavigationLink { destination() } label: { Label(title, systemImage: symbol) }
    }

    private func sheet(_ title: String, _ symbol: String, _ p: Personal) -> some View {
        Button { personal = p } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "chevron.up").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(Theme.ink)
    }
}
