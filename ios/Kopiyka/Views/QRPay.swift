import SwiftUI
import VisionKit

// Pay by QR: scan a Roma Live code (or open its link), see the place and the amount, confirm with Face ID, 3-D Secure
// from 1000 TAX, get the receipt. The scanner falls back to typing or pasting the code when there is no camera or no
// permission (the simulator too); a payment the app cannot make can always be finished in the browser.

/// The scanner and its fallback. Calls `found` with the invoice code.
struct QRScanView: View {
    @Environment(\.dismiss) private var dismiss
    let found: (String) -> Void
    @State private var manual = ""
    @State private var typing = false
    @State private var wrong = false
    @State private var camera = DataScannerViewController.isSupported && DataScannerViewController.isAvailable

    var body: some View {
        NavigationStack {
            ZStack {
                if camera && !typing {
                    QRCamera { raw in
                        if let c = PayLink.code(from: raw) { found(c) } else { wrong = true }
                    }
                    .ignoresSafeArea()
                    frame
                } else {
                    fallback
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(L("Закрити").s) { dismiss() } }
                if camera {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(typing ? Tx("Камера", "Camera", "Камера") : Tx("Ввести код", "Enter code", "Ввести код")) { withAnimation(.smooth) { typing.toggle() } }
                    }
                }
            }
            .sensoryFeedback(.error, trigger: wrong)
        }
    }

    /// A quiet viewfinder: four corners and one line of text.
    private var frame: some View {
        VStack(spacing: 18) {
            Spacer()
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.85), style: StrokeStyle(lineWidth: 3, dash: [44, 160], dashPhase: 22))
                .frame(width: 250, height: 250)
            Text(wrong ? Tx("Це не код TaxTech", "Not a TaxTech code", "Это не код TaxTech") : Tx("Наведіть на QR-код", "Point at the QR code", "Наведите на QR-код"))
                .font(Theme.ui(17, .semibold))
                .padding(.horizontal, 16).frame(height: 40)
                .glassCapsule()
            Spacer()
            Spacer()
        }
        .allowsHitTesting(false)
    }

    /// No camera (or no permission): the code or the whole link by hand, or from the clipboard.
    private var fallback: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Tx("Код оплати", "Payment code", "Код оплаты")).font(.display(32, .medium)).tracking(-0.8).padding(.top, 12)
            Text(camera ? Tx("Код під QR або посилання /pay/…", "The code under the QR or the /pay/… link", "Код под QR или ссылка /pay/…")
                        : Tx("Камера недоступна. Вставте посилання /pay/… або код під QR.", "No camera here. Paste the /pay/… link or the code under the QR.", "Камера недоступна. Вставьте ссылку /pay/… или код под QR."))
                .foregroundStyle(.secondary)
            TextField("bank.munister.com.ua/pay/…", text: $manual)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                .font(Theme.mono(17, .regular))
                .padding(16).background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
                .onSubmit(submit)
            HStack(spacing: 10) {
                // the system paste button reads the clipboard without the "Allow paste?" prompt
                PasteButton(payloadType: String.self) { items in
                    guard let s = items.first else { return }
                    Task { @MainActor in manual = s; submit() }
                }
                .buttonBorderShape(.capsule).labelStyle(.titleAndIcon).tint(Theme.gold).controlSize(.large)
                Button(Tx("Далі", "Next", "Далее"), action: submit)
                    .buttonStyle(InkButton()).disabled(PayLink.code(from: manual) == nil)
            }
            if wrong { Text(Tx("Не схоже на код оплати.", "That does not look like a payment code.", "Не похоже на код оплаты.")).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert) }
            Spacer()
        }
        .padding(.horizontal, 20)
        .screenBackground()
    }

    private func submit() {
        if let c = PayLink.code(from: manual) { found(c) } else { wrong.toggle() }
    }
}

/// VisionKit's live scanner, QR only, reporting the first payload it recognises.
private struct QRCamera: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
                                           recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
                                           isPinchToZoomEnabled: true, isGuidanceEnabled: false, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ vc: DataScannerViewController, coordinator: Coordinator) { vc.stopScanning() }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var last = ""
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for case let .barcode(b) in items {
                guard let v = b.payloadStringValue, v != last else { continue }
                last = v
                onCode(v)
                return
            }
        }
    }
}

/// One invoice: review, confirm, 3-D Secure, receipt. `done` runs after a payment so the screens behind refresh.
struct QRPayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let code: String
    var done: () async -> Void = {}

    enum Step: Equatable { case loading, review, paying, result, closed, failed(String) }
    @State private var step: Step = .loading
    @State private var inv: API.QRInvoice?
    @State private var me: API.CityMe?
    @State private var challenge: API.Challenge?
    @State private var otp = ""
    @State private var error: String?
    @State private var left = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    switch step {
                    case .loading: ProgressView().padding(.top, 120)
                    case .failed(let msg): failed(msg)
                    default: if let inv { card(inv) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(L("Закрити").s) { dismiss() } } }
            .task { await load() }
            .onReceive(tick) { _ in
                guard step == .review, left > 0 else { return }
                left -= 1
                if left == 0 { step = .closed }
            }
            .sheet(item: $challenge) { c in otpSheet(c) }
            .sensoryFeedback(.success, trigger: inv?.status == "paid")
            .sensoryFeedback(.error, trigger: inv?.status == "declined")
        }
    }

    // MARK: Screens

    private func card(_ q: API.QRInvoice) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(category(q.cat))\(q.rione.isEmpty ? "" : " · \(q.rione)") · Roma".uppercased())
                .font(Theme.ui(style: .caption1, .semibold)).tracking(1.2).foregroundStyle(.secondary)
                .padding(.top, 28)
            Text(q.name).font(.display(30, .medium)).tracking(-0.6).padding(.top, 6)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.amount(q.amount)).font(Theme.mono(46, .bold)).monospacedDigit()
                Text("TAX").font(Theme.ui(style: .subheadline, .semibold)).foregroundStyle(.secondary)
            }
            .padding(.vertical, 18)
            Divider().overlay(.white.opacity(0.08))

            switch step {
            case .result: receipt(q)
            case .closed: closed(q)
            default: confirm(q)
            }
        }
    }

    @ViewBuilder private func confirm(_ q: API.QRInvoice) -> some View {
        if !model.signedIn {
            VStack(spacing: 12) {
                Text(Tx("Увійдіть у банк, щоб оплатити.", "Sign in to the bank to pay.", "Войдите в банк, чтобы оплатить.")).foregroundStyle(.secondary)
                webButton
            }
            .padding(.top, 20)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Tx("З рахунку", "From", "Со счёта")).font(Theme.ui(style: .caption1)).foregroundStyle(.secondary)
                        Text(me.map { $0.cardLast4.map { "•••• \($0)" } ?? $0.who } ?? "…").font(Theme.ui(17, .semibold))
                    }
                    Spacer()
                    if let me { Text(Format.short(me.balance)).font(Theme.mono(17, .bold)).monospacedDigit().foregroundStyle(Theme.accent) }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 18, style: .continuous))
                if let me, me.balance < q.amount {
                    Text(Tx("Бракує коштів на рахунку.", "Not enough on the account.", "Недостаточно средств.")).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert)
                }
                Button { Task { await pay(tds: nil) } } label: {
                    HStack(spacing: 8) {
                        if step == .paying { ProgressView().tint(Theme.onAccent) } else if model.biometricsEnabled { Image(systemName: Biometrics.symbol) }
                        Text(step == .paying ? Tx("Авторизація…", "Authorising…", "Авторизация…") : "\(L("Підтвердити").s) · \(Format.short(q.amount))")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(InkButton())
                .disabled(step == .paying)
                if let error { Text(error).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert) }
                HStack {
                    if q.sca { Label("3-D Secure", systemImage: "lock.shield").font(Theme.ui(style: .caption1)).foregroundStyle(.secondary) }
                    Spacer()
                    Text(Tx("Дійсний", "Valid for", "Действует")+" \(left / 60):\(String(format: "%02d", left % 60))")
                        .font(Theme.mono(style: .caption1)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .padding(.top, 20)
        }
    }

    private func receipt(_ q: API.QRInvoice) -> some View {
        let ok = q.status == "paid"
        return VStack(spacing: 14) {
            Image(systemName: ok ? "checkmark" : "xmark")
                .font(Theme.ui(36, .bold)).foregroundStyle(ok ? Theme.onAccent : Theme.ink)
                .frame(width: 84, height: 84)
                .background(ok ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.alert), in: .circle)
                .symbolEffect(.bounce, value: q.status)
                .padding(.top, 24)
            Text(ok ? L("Оплачено").s : L("Відхилено").s).font(.display(28, .medium))
            VStack(spacing: 8) {
                if let a = q.authCode { row(Tx("Код авторизації", "Auth code", "Код авторизации"), a) }
                if let r = q.rrn { row("RRN", r) }
                if let c = q.responseCode { row(Tx("Відповідь", "Response", "Ответ"), c + (q.message.map { " · \($0)" } ?? "")) }
                if q.threeDs == true { row("SCA", "3-D Secure") }
                if ok, let f = q.fee { row("MDR", Format.short(f)) }
                if let b = q.newBalance ?? me?.balance { row(Tx("Баланс", "Balance", "Баланс"), Format.short(b)) }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 18, style: .continuous))
            Button(Tx("Готово", "Done", "Готово")) { dismiss() }.buttonStyle(InkButton())
        }
        .frame(maxWidth: .infinity)
    }

    private func closed(_ q: API.QRInvoice) -> some View {
        VStack(spacing: 10) {
            Text(q.status == "cancelled" ? Tx("Скасовано", "Cancelled", "Отменено") : q.status == "paid" ? L("Оплачено").s : Tx("Час вийшов", "Expired", "Истёк"))
                .font(.display(26, .medium)).padding(.top, 24)
            Text(Tx("Попросіть новий код.", "Ask for a new code.", "Попросите новый код.")).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func failed(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(Theme.ui(36, .semibold)).foregroundStyle(.secondary).padding(.top, 100)
            Text(msg).multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button(Tx("Ще раз", "Try again", "Ещё раз")) { Task { await load() } }.buttonStyle(InkButton())
            webButton
        }
    }

    /// The fallback: the same invoice on the web page.
    private var webButton: some View {
        Button { openURL(PayLink.web(code, base: model.serverURL)) } label: {
            Label(Tx("Відкрити в браузері", "Open in the browser", "Открыть в браузере"), systemImage: "safari").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered).controlSize(.large)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).font(Theme.mono(15, .regular)).monospacedDigit() }
            .font(Theme.ui(style: .subheadline))
    }

    private func otpSheet(_ c: API.Challenge) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("3-D Secure").font(.display(32, .medium)).tracking(-0.8).padding(.top, 24)
            Text(L("Код для підтвердження платежу").s).foregroundStyle(.secondary)
            if let demo = c.demoOtp {
                Button { otp = demo } label: {
                    HStack { Image(systemName: "message.fill"); Text(demo).font(Theme.mono(22, .bold)).monospacedDigit(); Spacer(); Text(L("Підставити").s).font(Theme.ui(style: .footnote)) }
                        .padding(16).background(Theme.accent.opacity(0.14), in: .rect(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            TextField("000000", text: $otp).keyboardType(.numberPad).textContentType(.oneTimeCode).font(Theme.mono(32, .bold)).monospacedDigit()
                .padding(16).background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
            if let error { Text(error).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert) }
            Button(L("Підтвердити").s) {
                Task {
                    do {
                        let token = try await model.api.verifyForPayment(c, code: otp)
                        challenge = nil; otp = ""
                        await pay(tds: token, skipBiometrics: true)
                    } catch { self.error = error.localizedDescription }
                }
            }
            .buttonStyle(InkButton()).disabled(otp.count < 6)
            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .screenBackground()
    }

    // MARK: Work

    private func load() async {
        step = .loading
        do {
            let q = try await model.api.qrInvoice(code)
            inv = q
            left = q.expiresIn
            step = q.status == "pending" ? .review : (q.status == "paid" || q.status == "declined") ? .result : .closed
            if model.signedIn { me = try? await model.api.cityMe() }
        } catch let e as API.Failure where e.message.lowercased().contains("not found") {
            step = .failed(Tx("Код не знайдено.", "Code not found.", "Код не найден."))
        } catch {
            step = .failed(Tx("Немає зв'язку з банком.", "No connection to the bank.", "Нет связи с банком."))
        }
    }

    private func pay(tds: String?, skipBiometrics: Bool = false) async {
        guard let q = inv else { return }
        error = nil
        // Face ID before money leaves, when the client turned it on for the bank
        if model.biometricsEnabled && !skipBiometrics && Biometrics.kind != .none {
            guard await Biometrics.unlock(reason: "\(L("Підтвердити").s) · \(Format.short(q.amount)) · \(q.name)") else { return }
        }
        step = .paying
        do {
            let r = try await model.api.qrConfirm(code, cardId: me?.cardId, tds: tds)
            if r.outcome == "sca_required" {
                challenge = try await model.api.challenge(amount: q.amount, recipient: "Roma · \(q.name)")
                step = .review
                return
            }
            inv = r
            step = r.status == "paid" || r.status == "declined" ? .result : .closed
            await done()
        } catch {
            self.error = error.localizedDescription
            step = .review
        }
    }

    private func category(_ c: String) -> String {
        switch c {
        case "cafe": Tx("Кава", "Coffee", "Кофе")
        case "food": Tx("Ресторан", "Restaurant", "Ресторан")
        case "bar": Tx("Бар", "Bar", "Бар")
        case "shop": Tx("Крамниця", "Shop", "Магазин")
        case "stay": Tx("Готель", "Hotel", "Отель")
        case "culture": Tx("Культура", "Culture", "Культура")
        case "money": Tx("Банк", "Bank", "Банк")
        case "health": Tx("Аптека", "Pharmacy", "Аптека")
        default: Tx("Місце", "Place", "Место")
        }
    }
}
