import LocalAuthentication
import SwiftUI

/// Стан перевірки особи. Лежить лише на телефоні: сервер його не бачить, фото документа не зберігаються.
struct KYCState: Codable, Equatable {
    enum Level: String, Codable { case none, verified }
    var level: Level = .none
    var fullName = ""
    var birth = Date(timeIntervalSince1970: 631_152_000)
    var country = "UA"
    var docType = "passport"
    var docLast4 = ""
    var biometry = ""
    var pep = false
    var source = "salary"
    var turnover = "low"
    var risk = ""
    var riskNotes: [String] = []
    var verifiedAt: Date?

    private static let key = "kyc.v1"

    static func load() -> KYCState {
        guard let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(KYCState.self, from: d) else { return KYCState() }
        return s
    }

    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }

    static func erase() { UserDefaults.standard.removeObject(forKey: key) }

    static let countries: [(code: String, name: String)] = [
        ("UA", "Україна · Ukraine"), ("PL", "Polska"), ("DE", "Deutschland"), ("IT", "Italia"),
        ("GB", "United Kingdom"), ("US", "United States"), ("OTHER", "Other"),
    ]
}

/// Позначка статусу перевірки для шапки профілю.
struct KYCBadge: View {
    let verified: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: verified ? "checkmark.seal.fill" : "exclamationmark.shield")
                .font(Theme.ui(style: .caption1, .bold))
            Text(verified ? Tx("Особу підтверджено", "Identity verified", "Личность подтверждена")
                          : Tx("Особу не підтверджено", "Not verified", "Личность не подтверждена"))
                .font(Theme.ui(style: .caption1, .semibold))
        }
        .padding(.horizontal, 10).frame(height: 26)
        .foregroundStyle(verified ? Theme.onAccent : Theme.ink)
        .background(verified ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.ink.opacity(0.1)), in: .capsule)
    }
}

/// Перевірка особи (KYC) у три кроки: дані, документ, біометрія (Face ID / Touch ID). Навчальна: без камери й фото,
/// нічого не надсилається, зберігається лише результат, тип біометрії і останні 4 цифри номера.
struct KYCView: View {
    @Environment(\.dismiss) private var dismiss
    var prefill = ""
    @State private var state = KYCState.load()
    @State private var step = 0
    @State private var bioOK = false
    @State private var bioError: String?
    @State private var bioKind = ""
    @State private var checking = false
    @State private var progress = 0
    @State private var docNumber = ""

    private var checks: [String] {
        [Tx("Перевіряємо формат документа", "Checking the document format", "Проверяем формат документа"),
         Tx("Привʼязуємо до біометрії пристрою", "Binding to device biometrics", "Привязываем к биометрии устройства"),
         Tx("Оцінка ризику AML", "AML risk scoring", "Оценка риска AML"),
         Tx("Перевірка за списками санкцій (імітація)", "Sanctions screening (simulated)", "Проверка по санкционным спискам (имитация)")]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if state.level == .verified && !checking { done } else {
                        ribbon
                        Group {
                            switch step {
                            case 0: personal
                            case 1: document
                            case 2: aml
                            default: face
                            }
                        }
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                        notice
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 28)
            }
            .screenBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Tx("Підтвердження особи", "Verify identity", "Подтверждение личности"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Закрити").s) { dismiss() } } }
            .animation(.smooth, value: step)
            .onAppear { if state.fullName.isEmpty { state.fullName = prefill } }
            .sensoryFeedback(.success, trigger: state.level)
        }
    }

    // MARK: Кроки

    /// Ступені перевірки як лінія метро: станції I, II, III, пройдені закриті галочкою.
    private var ribbon: some View {
        let names = [Tx("Дані", "Details", "Данные"), Tx("Документ", "Document", "Документ"), "AML", Tx("Біометрія", "Biometrics", "Биометрия")]
        let roman = ["I", "II", "III", "IV"]
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    ZStack {
                        Circle().fill(i <= step ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.surface))
                        Circle().strokeBorder(i <= step ? Color.clear : Theme.line, lineWidth: 2)
                        if i < step {
                            Image(systemName: "checkmark").font(Theme.ui(13, .bold)).foregroundStyle(Theme.onAccent)
                        } else {
                            Text(roman[i]).font(Theme.ui(13, .bold))
                                .foregroundStyle(i == step ? Theme.onAccent : Color.secondary)
                        }
                    }
                    .frame(width: 34, height: 34)
                    if i < 3 {
                        Capsule().fill(i < step ? Theme.accent : Theme.line).frame(height: 5).padding(.horizontal, 4)
                    }
                }
            }
            HStack {
                ForEach(0..<4, id: \.self) { i in
                    Text(names[i].uppercased()).font(Theme.ui(10, .semibold)).tracking(1.2)
                        .foregroundStyle(i == step ? Theme.ink : .secondary)
                        .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : i == 3 ? .trailing : .center)
                }
            }
        }
        .padding(.top, 8)
        .animation(.smooth, value: step)
    }

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.display(30, .medium)).tracking(-0.6)
            Text(sub).font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary)
        }
    }

    private var personal: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Tx("Ваші дані", "Your details", "Ваши данные"),
                    Tx("Так, як у документі.", "As written in your document.", "Так, как в документе."))
            field(Tx("Імʼя та прізвище", "Full name", "Имя и фамилия")) {
                TextField("", text: $state.fullName).textContentType(.name).autocorrectionDisabled()
            }
            field(Tx("Дата народження", "Date of birth", "Дата рождения")) {
                DatePicker("", selection: $state.birth, in: ...Date.now, displayedComponents: .date).labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            field(Tx("Країна", "Country", "Страна")) {
                Picker("", selection: $state.country) {
                    ForEach(KYCState.countries, id: \.code) { Text($0.name).tag($0.code) }
                }
                .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(Tx("Далі", "Continue", "Далее")) { step = 1 }
                .buttonStyle(InkButton())
                .disabled(state.fullName.trimmingCharacters(in: .whitespaces).count < 3 || age < 18)
            if age < 18 {
                Text(Tx("Підтвердження доступне з 18 років.", "Verification is available from age 18.", "Подтверждение доступно с 18 лет."))
                    .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
            }
        }
    }

    private var age: Int { Calendar.current.dateComponents([.year], from: state.birth, to: .now).year ?? 0 }

    private var docNumberOK: Bool {
        let n = docNumber.filter { !$0.isWhitespace }.uppercased()
        guard state.country == "UA" else { return (6...12).contains(n.count) && n.contains(where: \.isNumber) }
        switch state.docType {
        case "id": return n.count == 9 && n.allSatisfy(\.isNumber)
        case "passport": return n.range(of: "^[A-ZА-Я]{2}[0-9]{6}$", options: .regularExpression) != nil
        default: return (6...12).contains(n.count) && n.contains(where: \.isNumber)
        }
    }

    private var numberHint: String {
        guard state.country == "UA" else { return Tx("6-12 символів", "6-12 characters", "6-12 символов") }
        switch state.docType {
        case "id": return Tx("9 цифр, напр. 123456789", "9 digits, e.g. 123456789", "9 цифр, напр. 123456789")
        case "passport": return Tx("2 літери і 6 цифр, напр. AB123456", "2 letters and 6 digits, e.g. AB123456", "2 буквы и 6 цифр, напр. AB123456")
        default: return Tx("6-12 символів", "6-12 characters", "6-12 символов")
        }
    }

    private var document: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Tx("Документ", "Document", "Документ"),
                    Tx("Лише тип і номер. Фото не потрібне.", "Just the type and number. No photo needed.", "Только тип и номер. Фото не нужно."))
            Picker("", selection: $state.docType) {
                Text(Tx("Паспорт", "Passport", "Паспорт")).tag("passport")
                Text(Tx("ID-картка", "ID card", "ID-карта")).tag("id")
                Text(Tx("Права", "Licence", "Права")).tag("licence")
            }
            .pickerStyle(.segmented)
            field(Tx("Номер документа", "Document number", "Номер документа")) {
                TextField("", text: $docNumber).textInputAutocapitalization(.characters).autocorrectionDisabled()
            }
            Text(numberHint).font(Theme.ui(style: .footnote)).foregroundStyle(docNumber.isEmpty || docNumberOK ? Color.secondary : Theme.ink)
            HStack(spacing: 10) {
                Button(L("Назад").s) { step = 0 }.buttonStyle(LineButton()).frame(width: 110)
                Button(Tx("Далі", "Continue", "Далее")) { step = 2 }
                    .buttonStyle(InkButton()).disabled(!docNumberOK)
            }
        }
    }

    private var aml: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("AML", Tx("Кілька питань про гроші, як у реальному банку.", "A few questions about your money, as in a real bank.", "Несколько вопросов о деньгах, как в настоящем банке."))
            field(Tx("Джерело коштів", "Source of funds", "Источник средств")) {
                Picker("", selection: $state.source) {
                    Text(Tx("Зарплата", "Salary", "Зарплата")).tag("salary")
                    Text(Tx("Бізнес", "Business", "Бизнес")).tag("business")
                    Text(Tx("Заощадження", "Savings", "Сбережения")).tag("savings")
                    Text(Tx("Подарунок чи спадок", "Gift or inheritance", "Подарок или наследство")).tag("gift")
                    Text(Tx("Інше", "Other", "Другое")).tag("other")
                }
                .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            field(Tx("Обіг на місяць", "Expected monthly turnover", "Оборот в месяц")) {
                Picker("", selection: $state.turnover) {
                    Text("< 10 000").tag("low")
                    Text("10 000 – 100 000").tag("mid")
                    Text("> 100 000").tag("high")
                }
                .labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            Toggle(isOn: $state.pep) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Tx("Публічний діяч (PEP)", "Politically exposed person (PEP)", "Публичное лицо (PEP)")).font(Theme.ui(style: .body, .medium))
                    Text(Tx("Ви або близькі родичі обіймаєте чи обіймали публічну посаду.", "You or a close relative holds or held a public office.", "Вы или близкие родственники занимаете или занимали публичную должность."))
                        .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accent)
            .padding(14).background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
            HStack(spacing: 10) {
                Button(L("Назад").s) { step = 1 }.buttonStyle(LineButton()).frame(width: 110)
                Button(Tx("Далі", "Continue", "Далее")) { step = 3 }.buttonStyle(InkButton())
            }
        }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Tx("Біометрія", "Biometrics", "Биометрия"),
                    Tx("Підтвердьте себе Face ID або відбитком пальця. Дані біометрії лишаються в iPhone.",
                       "Confirm with Face ID or your fingerprint. Biometric data never leaves the iPhone.",
                       "Подтвердите себя Face ID или отпечатком пальца. Данные биометрии остаются в iPhone."))
            if checking {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { i, t in
                        HStack(spacing: 12) {
                            if progress > i { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                            else if progress == i { ProgressView() }
                            else { Image(systemName: "circle").foregroundStyle(Theme.line) }
                            Text(t).foregroundStyle(progress >= i ? Theme.ink : .secondary)
                        }
                        .animation(.snappy, value: progress)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: bioOK ? "checkmark.circle.fill" : "touchid").font(Theme.ui(56, .light))
                        .foregroundStyle(Theme.accent).contentTransition(.symbolEffect(.replace))
                    Text(bioOK ? Tx("Біометрію підтверджено", "Biometrics confirmed", "Биометрия подтверждена")
                               : Tx("Торкніться, щоб підтвердити", "Tap to confirm", "Нажмите, чтобы подтвердить"))
                        .font(Theme.ui(style: .subheadline, .semibold))
                    if let bioError { Text(bioError).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                }
                .frame(maxWidth: .infinity, minHeight: 190)
                .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
                .onTapGesture { if !bioOK { Task { await authenticate() } } }
                HStack(spacing: 10) {
                    Button(L("Назад").s) { step = 2 }.buttonStyle(LineButton()).frame(width: 110)
                    if bioOK {
                        Button(Tx("Підтвердити", "Verify", "Подтвердить")) { Task { await run() } }.buttonStyle(InkButton())
                    } else {
                        Button(Tx("Face ID / відбиток", "Face ID / fingerprint", "Face ID / отпечаток")) { Task { await authenticate() } }.buttonStyle(InkButton())
                    }
                }
            }
        }
    }

    private var done: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(Theme.ui(64)).foregroundStyle(Theme.goldFill)
                .padding(.top, 36)
            Text(Tx("Особу підтверджено", "Identity verified", "Личность подтверждена")).font(.display(30, .medium))
            VStack(spacing: 0) {
                Line2(Tx("Імʼя", "Name", "Имя"), state.fullName)
                Rule()
                Line2(Tx("Документ", "Document", "Документ"), "•••• " + state.docLast4)
                Rule()
                Line2(Tx("Біометрія", "Biometrics", "Биометрия"), state.biometry.isEmpty ? "—" : state.biometry)
                Rule()
                Line2(Tx("Ризик AML", "AML risk", "Риск AML"), AML.title(state.risk))
                Rule()
                Line2(Tx("Ліміт на переказ", "Transfer limit", "Лимит на перевод"), Format.money(KYCLimits.transfer))
                Rule()
                Line2(Tx("Перевірено", "Verified on", "Проверено"),
                      (state.verifiedAt ?? .now).formatted(.dateTime.day().month(.abbreviated).year().locale(Lang.current.locale)))
            }
            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
            if !state.riskNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(state.riskNotes, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(Theme.ui(style: .footnote)).foregroundStyle(.secondary) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button(Tx("Скинути підтвердження", "Reset verification", "Сбросить подтверждение")) {
                KYCState.erase(); state = KYCState(); step = 0; docNumber = ""; bioOK = false; bioError = nil
            }
            .font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary)
            notice
        }
    }

    private var notice: some View {
        Label(Tx("Навчальна імітація KYC: без камери й фото, нічого не надсилається на сервер. Біометрія підтверджує, що телефон у ваших руках, а не особу.",
                 "A training simulation of KYC: no camera or photos, nothing is sent to a server. Biometrics show the phone is in your hands, not who you are.",
                 "Учебная имитация KYC: без камеры и фото, ничего не отправляется на сервер. Биометрия подтверждает, что телефон у вас в руках, а не личность."),
              systemImage: "lock.shield")
            .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
    }

    // MARK: Деталі

    private func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).caption()
            content()
                .padding(.horizontal, 14).frame(minHeight: 50)
                .background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }

    private func authenticate() async {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &err) else {
            bioError = Tx("На цьому пристрої немає Face ID чи Touch ID, або вони не налаштовані.",
                          "Face ID or Touch ID is not available or not set up on this device.",
                          "На этом устройстве нет Face ID или Touch ID, либо они не настроены.")
            return
        }
        bioKind = ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
        do {
            bioOK = try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                 localizedReason: Tx("Підтвердження особи в TaxTech", "Identity check in TaxTech", "Подтверждение личности в TaxTech"))
            bioError = nil
        } catch {
            bioOK = false
            bioError = Tx("Не вдалося підтвердити. Спробуйте ще раз.", "Could not confirm. Try again.", "Не удалось подтвердить. Попробуйте ещё раз.")
        }
    }

    /// «Перевірка»: етапи з паузами. Лишається результат, тип біометрії і 4 цифри номера.
    private func run() async {
        checking = true
        progress = 0
        for i in 0..<checks.count {
            try? await Task.sleep(for: .milliseconds(700))
            progress = i + 1
        }
        try? await Task.sleep(for: .milliseconds(300))
        if AML.sanctionsHit(state.fullName) {
            checking = false
            bioError = Tx("Збіг зі списком санкцій (навчальним). Перевірку не завершено: в реальному банку це передали б комплаєнсу.",
                          "Match on the (training) sanctions list. The check was not completed: a real bank would escalate this to compliance.",
                          "Совпадение с (учебным) санкционным списком. Проверка не завершена: в реальном банке это передали бы комплаенсу.")
            return
        }
        state.docLast4 = String(docNumber.filter { !$0.isWhitespace }.suffix(4))
        state.biometry = bioKind
        let r = AML.assess(state)
        state.risk = r.level
        state.riskNotes = r.notes
        state.level = .verified
        state.verifiedAt = .now
        state.save()
        docNumber = ""
        checking = false
    }
}

/// Ліміти за рівнем перевірки: без підтвердження менший ліміт на один переказ. Застосовує застосунок, сервер їх не знає.
enum KYCLimits {
    static let basic = 10_000.0
    static let verified = 100_000.0
    static let enhanced = 30_000.0
    static var transfer: Double {
        let s = KYCState.load()
        guard s.level == .verified else { return basic }
        return s.risk == "high" ? enhanced : verified
    }
}

/// AML: оцінка ризику клієнта та перевірка за навчальним списком санкцій. Усе рахується на телефоні.
enum AML {
    struct Result { let level: String; let notes: [String] }

    static let watchlist = ["lukashenko", "лукашенко", "putin", "путин", "путін", "kim jong", "assad", "асад"]

    static func title(_ level: String) -> String {
        switch level {
        case "high": Tx("Високий", "High", "Высокий")
        case "medium": Tx("Середній", "Medium", "Средний")
        case "low": Tx("Низький", "Low", "Низкий")
        default: "—"
        }
    }

    static func sanctionsHit(_ name: String) -> Bool {
        let n = name.lowercased()
        return watchlist.contains { n.contains($0) }
    }

    static func assess(_ s: KYCState) -> Result {
        var score = 0
        var notes: [String] = []
        if s.country == "OTHER" { score += 2; notes.append(Tx("Країна поза переліком низького ризику", "Country outside the low-risk list", "Страна вне списка низкого риска")) }
        if s.pep { score += 3; notes.append(Tx("Публічний діяч: посилена перевірка", "Politically exposed person: enhanced due diligence", "Публичное лицо: усиленная проверка")) }
        if s.turnover == "high" { score += 2; notes.append(Tx("Великий очікуваний обіг", "High expected turnover", "Большой ожидаемый оборот")) }
        else if s.turnover == "mid" { score += 1 }
        if s.source == "other" { score += 2; notes.append(Tx("Джерело коштів не уточнено", "Source of funds not specified", "Источник средств не уточнён")) }
        else if s.source == "gift" { score += 1 }
        return Result(level: score >= 4 ? "high" : score >= 2 ? "medium" : "low", notes: notes)
    }
}
