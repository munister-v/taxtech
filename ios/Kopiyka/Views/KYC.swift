import PhotosUI
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
                .font(.caption.weight(.bold))
            Text(verified ? Tx("Особу підтверджено", "Identity verified", "Личность подтверждена")
                          : Tx("Особу не підтверджено", "Not verified", "Личность не подтверждена"))
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10).frame(height: 26)
        .foregroundStyle(verified ? Theme.onAccent : Theme.ink)
        .background(verified ? AnyShapeStyle(Theme.goldFill) : AnyShapeStyle(Theme.ink.opacity(0.1)), in: .capsule)
    }
}

/// Перевірка особи (KYC) у три кроки: дані, документ, обличчя. Навчальна: нічого не надсилається,
/// фото відкидаються одразу після «перевірки», зберігається лише результат і останні 4 цифри номера.
struct KYCView: View {
    @Environment(\.dismiss) private var dismiss
    var prefill = ""
    @State private var state = KYCState.load()
    @State private var step = 0
    @State private var docPick: PhotosPickerItem?
    @State private var facePick: PhotosPickerItem?
    @State private var docImage: UIImage?
    @State private var faceImage: UIImage?
    @State private var checking = false
    @State private var progress = 0
    @State private var docNumber = ""

    private var checks: [String] {
        [Tx("Читаємо документ", "Reading the document", "Читаем документ"),
         Tx("Звіряємо обличчя", "Matching the face", "Сверяем лицо"),
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
            .onChange(of: docPick) { _, item in load(item) { docImage = $0; docPick = nil } }
            .onChange(of: facePick) { _, item in load(item) { faceImage = $0; facePick = nil } }
            .sensoryFeedback(.success, trigger: state.level)
        }
    }

    // MARK: Кроки

    private var ribbon: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i <= step ? Theme.accent : Theme.line).frame(height: 4)
            }
        }
        .padding(.top, 8)
    }

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.display(30, .medium)).tracking(-0.6)
            Text(sub).font(.subheadline).foregroundStyle(.secondary)
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
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var age: Int { Calendar.current.dateComponents([.year], from: state.birth, to: .now).year ?? 0 }

    private var document: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Tx("Документ", "Document", "Документ"),
                    Tx("Фото розвороту з даними. Воно не зберігається.", "A photo of the data page. It is not stored.", "Фото разворота с данными. Оно не сохраняется."))
            Picker("", selection: $state.docType) {
                Text(Tx("Паспорт", "Passport", "Паспорт")).tag("passport")
                Text(Tx("ID-картка", "ID card", "ID-карта")).tag("id")
                Text(Tx("Права", "Licence", "Права")).tag("licence")
            }
            .pickerStyle(.segmented)
            field(Tx("Номер документа", "Document number", "Номер документа")) {
                TextField("", text: $docNumber).textInputAutocapitalization(.characters).autocorrectionDisabled()
            }
            capture(image: docImage, symbol: "doc.text.viewfinder", title: Tx("Додати фото документа", "Add a document photo", "Добавить фото документа"),
                    pick: $docPick)
            HStack(spacing: 10) {
                Button(L("Назад").s) { step = 0 }.buttonStyle(LineButton()).frame(width: 110)
                Button(Tx("Далі", "Continue", "Далее")) { step = 2 }
                    .buttonStyle(InkButton())
                    .disabled(docImage == nil || docNumber.trimmingCharacters(in: .whitespaces).count < 5)
            }
        }
    }

    private var face: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(Tx("Обличчя", "Your face", "Лицо"),
                    Tx("Селфі при хорошому світлі, без окулярів і капюшона.", "A selfie in good light, without glasses or a hood.", "Селфи при хорошем свете, без очков и капюшона."))
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
                capture(image: faceImage, symbol: "person.crop.circle.badge.checkmark", title: Tx("Додати селфі", "Add a selfie", "Добавить селфи"), pick: $facePick)
                HStack(spacing: 10) {
                    Button(L("Назад").s) { step = 1 }.buttonStyle(LineButton()).frame(width: 110)
                    Button(Tx("Підтвердити", "Verify", "Подтвердить")) { Task { await run() } }
                        .buttonStyle(InkButton()).disabled(faceImage == nil)
                }
            }
        }
    }

    private var done: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(Theme.goldFill)
                .padding(.top, 36)
            Text(Tx("Особу підтверджено", "Identity verified", "Личность подтверждена")).font(.display(30, .medium))
            VStack(spacing: 0) {
                Line2(Tx("Імʼя", "Name", "Имя"), state.fullName)
                Rule()
                Line2(Tx("Документ", "Document", "Документ"), "•••• " + state.docLast4)
                Rule()
                Line2(Tx("Перевірено", "Verified on", "Проверено"),
                      (state.verifiedAt ?? .now).formatted(.dateTime.day().month(.abbreviated).year().locale(Lang.current.locale)))
            }
            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
            Button(Tx("Скинути підтвердження", "Reset verification", "Сбросить подтверждение")) {
                KYCState.erase(); state = KYCState(); step = 0; docNumber = ""; docImage = nil; faceImage = nil
            }
            .font(.subheadline).foregroundStyle(.secondary)
            notice
        }
    }

    private var notice: some View {
        Label(Tx("Навчальна імітація KYC: нічого не надсилається на сервер, фото відкидаються одразу після перевірки.",
                 "A training simulation of KYC: nothing is sent to a server and photos are discarded right after the check.",
                 "Учебная имитация KYC: ничего не отправляется на сервер, фото отбрасываются сразу после проверки."),
              systemImage: "lock.shield")
            .font(.footnote).foregroundStyle(.secondary)
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

    private func capture(image: UIImage?, symbol: String, title: String, pick: Binding<PhotosPickerItem?>) -> some View {
        PhotosPicker(selection: pick, matching: .images) {
            ZStack {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 190).clipped()
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Theme.accent).padding(10)
                        }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: symbol).font(.system(size: 34, weight: .light)).foregroundStyle(Theme.accent)
                        Text(title).font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 190)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: image == nil ? [6, 6] : [])))
            .foregroundStyle(Theme.ink)
        }
    }

    private func load(_ item: PhotosPickerItem?, _ set: @escaping (UIImage?) -> Void) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            set(data.flatMap { UIImage(data: $0) })
        }
    }

    /// «Перевірка»: три етапи з паузами. Фото відкидаються, лишається результат і 4 цифри номера.
    private func run() async {
        checking = true
        progress = 0
        for i in 0..<3 {
            try? await Task.sleep(for: .milliseconds(900))
            progress = i + 1
        }
        try? await Task.sleep(for: .milliseconds(350))
        state.docLast4 = String(docNumber.filter { !$0.isWhitespace }.suffix(4))
        state.level = .verified
        state.verifiedAt = .now
        state.save()
        docImage = nil
        faceImage = nil
        docNumber = ""
        checking = false
    }
}
