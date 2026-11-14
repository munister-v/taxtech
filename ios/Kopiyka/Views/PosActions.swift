import SwiftUI

/// Назви й значки статусів платежу терміналу.
enum PosStatus {
    static func text(_ p: API.PosPayment) -> String {
        switch p.status {
        case "captured": p.dispute?.status == "won" ? L("Оплачено").s : ((p.refunded ?? 0) > 0 ? L("Частково повернено").s : L("Оплачено").s)
        case "refunded": L("Повернено").s
        case "authorized": L("Утримано").s
        case "voided": L("Скасовано").s
        case "disputed": L("Спір").s
        case "chargeback": L("Чарджбек").s
        default: L("Відхилено").s
        }
    }

    static func symbol(_ p: API.PosPayment) -> String {
        switch p.status {
        case "captured": "checkmark"
        case "refunded": "arrow.uturn.backward"
        case "authorized": "lock.fill"
        case "voided": "lock.open.fill"
        case "disputed": "exclamationmark.bubble.fill"
        case "chargeback": "arrow.uturn.left.circle.fill"
        default: "xmark"
        }
    }

    static func isBad(_ p: API.PosPayment) -> Bool { p.status == "declined" || p.status == "chargeback" }

    static func reason(_ key: String) -> String {
        switch key {
        case "not_recognized": L("Не впізнаю платіж").s
        case "not_received": L("Товар не отримано").s
        case "duplicate": L("Подвійне списання").s
        default: L("Не та сума").s
        }
    }

    static func verdict(_ key: String?) -> String {
        switch key {
        case "liability_shift": L("Перенесення відповідальності: 3-D Secure").s
        case "no_evidence": L("Доказів немає").s
        default: L("Спір прийнято").s
        }
    }

    static let reasons = ["not_recognized", "not_received", "duplicate", "wrong_amount"]
}

/// Захоплення утриманої суми: менше, рівно або з чайовими до +20%.
struct PosCaptureSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let payment: API.PosPayment
    let done: (API.PosPayment) -> Void

    @State private var text = ""
    @State private var error: String?
    @State private var busy = false

    private var held: Double { payment.authAmount ?? payment.amount ?? 0 }
    private var amount: Double { Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var limit: Double { (held * 1.2 * 100).rounded() / 100 }
    private var valid: Bool { amount > 0 && amount <= limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Захопити").s).font(.display(30, .medium)).tracking(-0.8).padding(.top, 28)
            Text("\(payment.merchant ?? "") · \(Format.short(held))").foregroundStyle(.secondary)
            Card {
                HStack {
                    Text(L("Сума захоплення").s).foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", text: $text).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        .font(Theme.ui(22, .semibold)).monospacedDigit()
                }
                .padding(.horizontal, 18).padding(.vertical, 14)
                Rule().padding(.leading, 18)
                HStack {
                    Text(L("Комісія еквайра").s).foregroundStyle(.secondary)
                    Spacer()
                    Text(Format.short((amount * 0.015 * 100).rounded() / 100)).monospacedDigit()
                }
                .font(Theme.ui(style: .subheadline)).padding(.horizontal, 18).padding(.vertical, 13)
            }
            HStack(spacing: 8) {
                chip(L("Усе").s, held)
                ForEach([10, 15, 20], id: \.self) { pct in
                    chip("+\(pct)%", ((held * (1 + Double(pct) / 100)) * 100).rounded() / 100, tip: true)
                }
            }
            Text(L("Максимум \(Format.short(limit))").s).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
            if let error { Text(error).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert) }
            Spacer()
            Button(L("Захопити").s) { Task { await capture() } }.buttonStyle(InkButton()).disabled(!valid || busy)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .screenBackground()
        .onAppear { text = held.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) }
    }

    private func chip(_ title: String, _ value: Double, tip: Bool = false) -> some View {
        Button { text = value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX"))) } label: {
            Text(tip ? "\(L("Чайові").s) \(title)" : title).font(Theme.ui(style: .footnote, .medium))
                .padding(.horizontal, 12).frame(height: 34)
                .background(abs(amount - value) < 0.005 ? AnyShapeStyle(Theme.accent.opacity(0.22)) : AnyShapeStyle(Theme.frost), in: .capsule)
        }
        .buttonStyle(PressScale())
    }

    private func capture() async {
        guard let id = payment.id else { return }
        busy = true; error = nil
        do {
            let r = try await model.api.posCapture(id, amount: amount)
            done(r)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        busy = false
    }
}

/// Квитанція платежу з терміналу: повернення, часткове повернення, спір і відповідь магазину.
struct PosReceipt: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var payment: API.PosPayment
    let changed: () -> Void

    @State private var partialAsk = false
    @State private var partialText = ""
    @State private var disputeAsk = false
    @State private var capturing = false
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(payment.merchant ?? "").font(.display(30, .medium)).tracking(-0.8).padding(.top, 28)
                Text(Format.short(payment.amount ?? 0)).font(Theme.mono(style: .title2).monospacedDigit()).foregroundStyle(Theme.accent)
                Card {
                    row(L("Статус").s, PosStatus.text(payment))
                    if payment.isHeld {
                        Rule().padding(.leading, 18); row(L("Утримано").s, Format.short(payment.authAmount ?? payment.amount ?? 0))
                    } else {
                        Rule().padding(.leading, 18); row(L("Комісія еквайра").s, Format.short(payment.fee ?? 0))
                    }
                    if (payment.refunded ?? 0) > 0 {
                        Rule().padding(.leading, 18); row(L("Повернено").s, Format.short(payment.refunded ?? 0))
                    }
                    if let d = payment.dispute {
                        Rule().padding(.leading, 18); row(L("Спір").s, PosStatus.reason(d.reason))
                        if d.verdict != nil { Rule().padding(.leading, 18); row(L("Рішення").s, PosStatus.verdict(d.verdict)) }
                    }
                    if model.expert {
                        Rule().padding(.leading, 18); row(L("Код відповіді").s, "\(payment.responseCode) · \(payment.message)")
                    }
                }
                if payment.isDisputed {
                    Text(L("Кардхолдер уже отримав тимчасовий кредит. Магазин приймає спір або заперечує.").s)
                        .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                }
                if model.expert { PosBreakdown(payment: payment) }
                if let error { Text(error).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert) }
                actions
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .sheet(isPresented: $capturing) {
            PosCaptureSheet(payment: payment) { payment = $0; changed() }.presentationDetents([.large])
        }
        .alert(L("Часткове повернення").s, isPresented: $partialAsk) {
            TextField(L("Сума повернення").s, text: $partialText).keyboardType(.decimalPad)
            Button(L("Повернути").s) { Task { await refund(Double(partialText.replacingOccurrences(of: ",", with: "."))) } }
            Button(L("Скасувати").s, role: .cancel) {}
        } message: {
            Text(L("Залишилось \(Format.short(payment.refundable)). Комісія еквайра не повертається.").s)
        }
        .confirmationDialog(L("Оскаржити платіж").s, isPresented: $disputeAsk, titleVisibility: .visible) {
            ForEach(PosStatus.reasons, id: \.self) { r in
                Button(PosStatus.reason(r)) { run { try await model.api.posDispute(payment.id ?? 0, reason: r) } }
            }
            Button(L("Скасувати").s, role: .cancel) {}
        }
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 10) {
            if payment.isHeld {
                Button(L("Захопити").s) { capturing = true }.buttonStyle(InkButton())
                Button(L("Скасувати утримання").s) { run { try await model.api.posVoid(payment.id ?? 0) } }.buttonStyle(LineButton())
            } else if payment.status == "captured", payment.id != nil {
                Button((payment.refunded ?? 0) > 0 ? L("Повернути залишок").s : L("Повернути платіж").s) {
                    run { try await model.api.posRefund(payment.id ?? 0) }
                }
                .buttonStyle(LineButton())
                Button(L("Часткове повернення").s) { partialText = ""; partialAsk = true }.buttonStyle(LineButton())
                if (payment.refunded ?? 0) == 0 && payment.dispute == nil {
                    Button(L("Оскаржити платіж").s) { disputeAsk = true }.buttonStyle(LineButton())
                }
            } else if payment.isDisputed {
                Button(L("Заперечити").s) { run { try await model.api.posDisputeRespond(payment.id ?? 0, contest: true) } }.buttonStyle(InkButton())
                Button(L("Прийняти спір").s) { run { try await model.api.posDisputeRespond(payment.id ?? 0, contest: false) } }.buttonStyle(LineButton())
            }
        }
        .disabled(busy)
    }

    private func refund(_ amount: Double?) async {
        guard let amount, amount > 0 else { return }
        run { try await model.api.posRefund(payment.id ?? 0, amount: amount) }
    }

    private func run(_ op: @escaping () async throws -> API.PosPayment) {
        busy = true; error = nil
        Task {
            do {
                payment = try await op()
                changed()
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func row(_ t: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(t).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(v).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(Theme.ui(style: .subheadline)).padding(.horizontal, 18).padding(.vertical, 13)
    }
}
