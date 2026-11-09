import SwiftUI

/// Політика обробки персональних даних. Українською, англійською й російською; італійська й німецька показують англійську.
enum PrivacyPolicy {
    static let updated = "09.11.2026"
    static let version = "1.0"

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    static var sections: [Section] {
        switch Lang.current {
        case .uk: uk
        case .ru: ru
        default: en
        }
    }

    static var heading: String { Tx("Політика конфіденційності", "Privacy Policy", "Политика конфиденциальности") }

    private static let uk: [Section] = [
        .init(title: "1. Хто обробляє дані", body: "Володілець даних - розробник застосунку TaxTech (Munister). TaxTech - навчальна лабораторія цифрових фінансів: токен TAX є навчальною одиницею, а не грішми чи електронними грошима, а застосунок не є банком і не надає фінансових послуг. Питання й запити щодо даних: tilandiya@gmail.com."),
        .init(title: "2. Які дані ми обробляємо", body: "Обліковий запис: імʼя, пошта або телефон, а при вході через Apple - ідентифікатор Apple й за вашою згодою прихована пошта. Навчальний рахунок: баланс, картки, перекази, депозити, кредити, цілі, історія операцій у токенах TAX. Технічні дані: пристрій і IP-адреса сесії, час входу - для безпеки акаунта. Лише на телефоні: фото профілю, облік витрат, результат перевірки особи (KYC) і останні 4 цифри номера документа, налаштування. Ми не збираємо геолокацію, контакти, рекламні ідентифікатори й не підключаємо рекламні чи аналітичні SDK."),
        .init(title: "3. Навіщо і на якій підставі", body: "Щоб створити акаунт і працювати застосунку (виконання угоди, ст. 6(1)(b) GDPR). Щоб захищати акаунт від шахрайства та зловживань (законний інтерес, ст. 6(1)(f)). Щоб надсилати текст чека чи питання мовній моделі помічника - лише за вашою згодою (ст. 6(1)(a)), яку можна відкликати в будь-який момент у розділі «Дані та приватність»."),
        .init(title: "4. Мовна модель і розпізнавання", body: "Фото чека розпізнається на телефоні й нікуди не надсилається. Якщо ви дозволили сервер, текст чека або ваше питання до помічника йде до мовної моделі Anthropic, але перед цим телефон прибирає номери карток і рахунків, телефони, пошту, ІПН і паспорт. Без згоди все працює лише на телефоні."),
        .init(title: "5. Перевірка особи (KYC)", body: "Перевірка в застосунку є навчальною імітацією. Імʼя, дата народження, країна й тип документа лишаються на телефоні. Фото документа й селфі не зберігаються і не надсилаються: вони відкидаються одразу після «перевірки». Зберігаються лише результат, дата й останні 4 цифри номера. Скинути результат можна на екрані перевірки або видалити всі локальні дані."),
        .init(title: "6. Кому передаємо дані", body: "Дані акаунта й навчального рахунку зберігаються на сервері розробника (bank.munister.com.ua). Постачальник мовної моделі (Anthropic) отримує дані лише за вашою згодою, як описано в п. 4. Вхід через Apple обробляє Apple за власною політикою. Ми не продаємо дані й не передаємо їх рекламодавцям. Мовна модель Anthropic працює за межами України та ЄС, тому дані, які ви дозволили їй надсилати, можуть опрацьовуватися там."),
        .init(title: "7. Скільки зберігаємо", body: "Дані акаунта - поки акаунт існує. Після видалення акаунта (Профіль - «Видалити акаунт») рахунок, картки, депозити, кредити, сесії й історія операцій видаляються з сервера одразу. Записи журналу безпеки при цьому лишаються без привʼязки до вас. Локальні дані лишаються на телефоні, поки ви їх не видалите або не видалите застосунок."),
        .init(title: "8. Ваші права", body: "Ви можете отримати копію своїх даних (розділ «Дані та приватність» - «Експорт»), виправити їх, видалити акаунт і всі дані, відкликати згоду, обмежити обробку чи заперечити проти неї та подати скаргу до наглядового органу (в Україні - Уповноважений Верховної Ради з прав людини)."),
        .init(title: "9. Безпека", body: "Звʼязок із сервером іде через HTTPS. Токен входу лежить у Keychain, вхід захищає PIN і біометрія. Паролі зберігаються лише у вигляді хешів. Жодна система не безпечна абсолютно, тому не використовуйте тут паролі від інших сервісів."),
        .init(title: "10. Діти", body: "Застосунок не призначений для дітей до 13 років і свідомо не збирає їхніх даних, а перевірка особи доступна з 18. Якщо ви дізналися, що дитина надала дані, напишіть нам, і ми їх видалимо."),
        .init(title: "11. Зміни політики", body: "Коли політика зміниться, ми оновимо дату нижче й покажемо повідомлення в застосунку. Чинна версія: \(version) від \(updated)."),
    ]

    private static let en: [Section] = [
        .init(title: "1. Who processes your data", body: "The data controller is the developer of the TaxTech app (Munister). TaxTech is a training lab for digital finance: the TAX token is a learning unit, not money or e-money, and the app is not a bank and provides no financial services. Questions and data requests: tilandiya@gmail.com."),
        .init(title: "2. What we process", body: "Account: name, email or phone and, with Sign in with Apple, the Apple identifier and, if you allow it, a private relay email. Training account: balance, cards, transfers, deposits, credits, goals and transaction history in TAX tokens. Technical data: device and IP address of a session and sign-in time, to protect the account. On your phone only: profile photo, expense log, the identity check (KYC) result with the last 4 digits of the document number, and settings. We collect no location, contacts or advertising identifiers and include no advertising or analytics SDKs."),
        .init(title: "3. Why and on what basis", body: "To create an account and run the app (performance of a contract, GDPR Art. 6(1)(b)). To protect accounts from fraud and abuse (legitimate interest, Art. 6(1)(f)). To send receipt text or a question to the assistant's language model, only with your consent (Art. 6(1)(a)), which you can withdraw at any time under Data & privacy."),
        .init(title: "4. Language model and recognition", body: "A receipt photo is recognised on the phone and never leaves it. If you allow the server, receipt text or your question to the assistant goes to Anthropic's language model, but the phone first removes card and account numbers, phone numbers, email, tax IDs and passport numbers. Without consent everything runs on the phone."),
        .init(title: "5. Identity check (KYC)", body: "The check in the app is a training simulation. Name, date of birth, country and document type stay on the phone. The document photo and selfie are neither stored nor sent: they are discarded right after the check. Only the result, the date and the last 4 digits of the number are kept. You can reset the result on the check screen or delete all local data."),
        .init(title: "6. Who receives data", body: "Account and training-account data is stored on the developer's server (bank.munister.com.ua). The language model provider (Anthropic) receives data only with your consent, as in section 4. Sign in with Apple is processed by Apple under its own policy. We do not sell data or share it with advertisers. Anthropic's language model runs outside Ukraine and the EU, so data you allow it to receive may be processed there."),
        .init(title: "7. How long we keep it", body: "Account data - while the account exists. When you delete the account (Profile - Delete account), the account, cards, deposits, credits, sessions and transaction history are removed from the server at once. Security log entries remain, no longer linked to you. Local data stays on the phone until you delete it or remove the app."),
        .init(title: "8. Your rights", body: "You can get a copy of your data (Data & privacy - Export), correct it, delete your account and all data, withdraw consent, restrict or object to processing, and complain to a supervisory authority (in Ukraine, the Parliament Commissioner for Human Rights; in the EU, your national data protection authority)."),
        .init(title: "9. Security", body: "Traffic to the server uses HTTPS. The sign-in token is kept in the Keychain, and PIN and biometrics protect access. Passwords are stored only as hashes. No system is perfectly secure, so do not reuse passwords from other services here."),
        .init(title: "10. Children", body: "The app is not intended for children under 13 and does not knowingly collect their data, and the identity check is available from 18. If you learn that a child has provided data, write to us and we will delete it."),
        .init(title: "11. Changes", body: "When this policy changes we update the date below and show a notice in the app. Current version: \(version) of \(updated)."),
    ]

    private static let ru: [Section] = [
        .init(title: "1. Кто обрабатывает данные", body: "Оператор данных - разработчик приложения TaxTech (Munister). TaxTech - учебная лаборатория цифровых финансов: токен TAX является учебной единицей, а не деньгами или электронными деньгами, приложение не является банком и не оказывает финансовых услуг. Вопросы и запросы по данным: tilandiya@gmail.com."),
        .init(title: "2. Какие данные мы обрабатываем", body: "Аккаунт: имя, почта или телефон, а при входе через Apple - идентификатор Apple и, если вы разрешили, скрытая почта. Учебный счёт: баланс, карты, переводы, депозиты, кредиты, цели, история операций в токенах TAX. Технические данные: устройство и IP-адрес сессии, время входа - для безопасности аккаунта. Только на телефоне: фото профиля, учёт расходов, результат проверки личности (KYC) и последние 4 цифры номера документа, настройки. Мы не собираем геолокацию, контакты и рекламные идентификаторы и не подключаем рекламные или аналитические SDK."),
        .init(title: "3. Зачем и на каком основании", body: "Чтобы создать аккаунт и обеспечить работу приложения (исполнение договора, ст. 6(1)(b) GDPR). Чтобы защищать аккаунты от мошенничества и злоупотреблений (законный интерес, ст. 6(1)(f)). Чтобы отправлять текст чека или вопрос языковой модели помощника - только с вашего согласия (ст. 6(1)(a)), которое можно отозвать в любой момент в разделе «Данные и приватность»."),
        .init(title: "4. Языковая модель и распознавание", body: "Фото чека распознаётся на телефоне и никуда не уходит. Если вы разрешили сервер, текст чека или ваш вопрос помощнику уходит в языковую модель Anthropic, но перед этим телефон убирает номера карт и счетов, телефоны, почту, ИНН и паспорт. Без согласия всё работает только на телефоне."),
        .init(title: "5. Проверка личности (KYC)", body: "Проверка в приложении - учебная имитация. Имя, дата рождения, страна и тип документа остаются на телефоне. Фото документа и селфи не сохраняются и не отправляются: они отбрасываются сразу после проверки. Хранятся только результат, дата и последние 4 цифры номера. Сбросить результат можно на экране проверки или удалить все локальные данные."),
        .init(title: "6. Кому передаём данные", body: "Данные аккаунта и учебного счёта хранятся на сервере разработчика (bank.munister.com.ua). Поставщик языковой модели (Anthropic) получает данные только с вашего согласия, как описано в п. 4. Вход через Apple обрабатывает Apple по собственной политике. Мы не продаём данные и не передаём их рекламодателям. Языковая модель Anthropic работает за пределами Украины и ЕС, поэтому данные, которые вы разрешили ей отправлять, могут обрабатываться там."),
        .init(title: "7. Сколько храним", body: "Данные аккаунта - пока существует аккаунт. После удаления аккаунта (Профиль - «Удалить аккаунт») счёт, карты, депозиты, кредиты, сессии и история операций удаляются с сервера сразу. Записи журнала безопасности остаются без привязки к вам. Локальные данные остаются на телефоне, пока вы их не удалите или не удалите приложение."),
        .init(title: "8. Ваши права", body: "Вы можете получить копию своих данных (раздел «Данные и приватность» - «Экспорт»), исправить их, удалить аккаунт и все данные, отозвать согласие, ограничить обработку или возразить против неё и подать жалобу в надзорный орган."),
        .init(title: "9. Безопасность", body: "Связь с сервером идёт по HTTPS. Токен входа лежит в Keychain, доступ защищают PIN и биометрия. Пароли хранятся только в виде хешей. Ни одна система не безопасна абсолютно, поэтому не используйте здесь пароли от других сервисов."),
        .init(title: "10. Дети", body: "Приложение не предназначено для детей до 13 лет и сознательно не собирает их данных, а проверка личности доступна с 18. Если вы узнали, что ребёнок предоставил данные, напишите нам, и мы их удалим."),
        .init(title: "11. Изменения", body: "Когда политика изменится, мы обновим дату ниже и покажем уведомление в приложении. Действующая версия: \(version) от \(updated)."),
    ]
}

/// Повний текст політики. Відкривається без входу.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(PrivacyPolicy.heading).font(.display(32, .medium)).tracking(-0.8)
                    Text(Tx("Версія \(PrivacyPolicy.version), оновлено \(PrivacyPolicy.updated)",
                            "Version \(PrivacyPolicy.version), updated \(PrivacyPolicy.updated)",
                            "Версия \(PrivacyPolicy.version), обновлено \(PrivacyPolicy.updated)"))
                        .font(.footnote).foregroundStyle(.secondary)
                    ForEach(PrivacyPolicy.sections) { s in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.title).font(.headline)
                            Text(s.body).font(.subheadline).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Готово").s) { dismiss() } } }
        }
    }
}

/// Дані та приватність: політика, згода на сервер, експорт, локальні дані, видалення акаунта.
struct DataControlsView: View {
    @Environment(AppModel.self) private var model
    @State private var policy = false
    @State private var exportURL: URL?
    @State private var exporting = false
    @State private var confirmLocal = false
    @State private var note: String?

    var body: some View {
        @Bindable var m = model
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ScreenTitle(Tx("Дані та приватність", "Data & privacy", "Данные и приватность"))
                RowGroup(title: Tx("Згода", "Consent", "Согласие")) {
                    Toggle(isOn: $m.cloudAIAllowed) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Tx("Мовна модель на сервері", "Language model on the server", "Языковая модель на сервере")).font(.body.weight(.medium))
                            Text(Tx("Текст чека й питання помічнику, без номерів і паспорта.", "Receipt text and assistant questions, with numbers and passport removed.", "Текст чека и вопросы помощнику, без номеров и паспорта."))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .tint(Theme.accent)
                    .padding(16)
                }
                RowGroup(title: Tx("Документи", "Documents", "Документы")) {
                    Button { policy = true } label: {
                        IconRow(title: PrivacyPolicy.heading, symbol: "hand.raised")
                    }
                    .buttonStyle(.plain)
                    NavigationLink { KYCView() } label: {
                        IconRow(title: Tx("Підтвердження особи", "Identity verification", "Подтверждение личности"), symbol: "person.badge.shield.checkmark")
                    }
                    .buttonStyle(.plain)
                }
                RowGroup(title: Tx("Ваші дані", "Your data", "Ваши данные")) {
                    Button { Task { await export() } } label: {
                        IconRow(title: exporting ? Tx("Готуємо…", "Preparing…", "Готовим…") : Tx("Експорт моїх даних", "Export my data", "Экспорт моих данных"),
                                symbol: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain).disabled(exporting)
                    Button { confirmLocal = true } label: {
                        IconRow(title: Tx("Видалити дані на телефоні", "Delete data on this phone", "Удалить данные на телефоне"), symbol: "iphone.slash")
                    }
                    .buttonStyle(.plain)
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label(Tx("Поділитися файлом", "Share the file", "Поделиться файлом"), systemImage: "doc.badge.arrow.up")
                            .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.goldFill, in: .capsule).foregroundStyle(Theme.onAccent)
                    }
                }
                if let note { Text(note).font(.footnote).foregroundStyle(.secondary) }
                Text(Tx("Видалення акаунта з усіма даними на сервері - у профілі, внизу.", "Deleting the account and all server data is at the bottom of the profile.", "Удаление аккаунта со всеми данными на сервере - в профиле, внизу."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 32)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $policy) { PrivacyPolicyView() }
        .confirmationDialog(Tx("Видалити дані на телефоні?", "Delete data on this phone?", "Удалить данные на телефоне?"), isPresented: $confirmLocal, titleVisibility: .visible) {
            Button(Tx("Видалити", "Delete", "Удалить"), role: .destructive) { wipeLocal() }
        } message: {
            Text(Tx("Фото профілю, вибір аватара й результат перевірки особи. Акаунт на сервері не зміниться.",
                    "Profile photo, avatar choice and the identity check result. The server account is unchanged.",
                    "Фото профиля, выбор аватара и результат проверки личности. Аккаунт на сервере не изменится."))
        }
    }

    private func wipeLocal() {
        ProfilePhoto.remove()
        UserDefaults.standard.removeObject(forKey: AvatarStyle.key)
        KYCState.erase()
        exportURL = nil
        note = Tx("Локальні дані видалено.", "Local data deleted.", "Локальные данные удалены.")
    }

    /// Збирає профіль, рахунок і історію в один JSON-файл; фото й KYC лишаються на телефоні й не входять.
    private func export() async {
        exporting = true
        defer { exporting = false }
        let me = try? await model.api.me()
        let account = try? await model.api.account()
        let history = (try? await model.api.history()) ?? []
        let iso = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "exportedAt": iso.string(from: .now),
            "policyVersion": PrivacyPolicy.version,
            "profile": ["fullName": me?.fullName ?? "", "email": me?.email ?? "", "phone": me?.phone ?? ""],
            "account": ["number": account?.accountNumber ?? "", "balanceTAX": account?.balance ?? 0],
            "transactions": history.map { tx -> [String: Any] in
                ["id": tx.id, "date": iso.string(from: tx.date), "type": tx.txType, "amountTAX": tx.isIncome ? tx.amount : -tx.amount,
                 "description": tx.description ?? ""]
            },
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            note = Tx("Не вдалося підготувати файл.", "Could not prepare the file.", "Не удалось подготовить файл.")
            return
        }
        let url = URL.temporaryDirectory.appending(path: "taxtech-my-data.json")
        do {
            try data.write(to: url, options: .atomic)
            exportURL = url
            note = nil
        } catch {
            note = error.localizedDescription
        }
    }
}
