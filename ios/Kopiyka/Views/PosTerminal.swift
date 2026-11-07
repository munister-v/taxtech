import SwiftUI

/// Віртуальний POS-термінал: сума, картка, 3-D Secure, авторизація, capture і повернення.
struct PosTerminalView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    struct Merchant: Identifiable, Hashable {
        let name: String, symbol: String, category: String
        var id: String { name }
        static let all = [
            Merchant(name: "Café Roma", symbol: "cup.and.saucer.fill", category: "cafe"),
            Merchant(name: "Metro Taxi", symbol: "car.fill", category: "transport"),
            Merchant(name: "Libreria Aurea", symbol: "book.fill", category: "books"),
            Merchant(name: "Atelier Via Condotti", symbol: "bag.fill", category: "fashion"),
            Merchant(name: "Hotel Forum", symbol: "bed.double.fill", category: "travel"),
        ]
    }

    enum Phase: Equatable { case entry, waiting, processing, result }

    @State private var merchant = Merchant.all[0]
    @State private var digits = ""
    @State private var phase = Phase.entry
    @State private var cards: [API.Card] = []
    @State private var cardIndex = 0
    @State private var history: [API.PosPayment] = []
    @State private var result: API.PosPayment?
    @State private var stagesShown = 0
    @State private var challenge: API.Challenge?
    @State private var otp = ""
    @State private var error: String?
    @State private var detail: API.PosPayment?

    private var amount: Double { Double(digits) ?? 0 }
    private var card: API.Card? { cards.indices.contains(cardIndex) ? cards[cardIndex] : nil }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            AuroraField().frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea().opacity(0.6)
            VStack(spacing: 0) {
                topBar
                switch phase {
                case .entry: entry
                case .waiting: waiting
                case .processing: processing
                case .result: resultView
                }
            }
            .padding(.horizontal, Theme.gutter)
        }
        .task { await load() }
        .sheet(item: $challenge) { c in otpSheet(c) }
        .sheet(item: $detail) { p in PosReceipt(payment: p) { Task { await load() } }.presentationDetents([.medium, .large]) }
    }

    // MARK: Шапка

    private var topBar: some View {
        HStack {
            Button { if phase == .entry || phase == .result { dismiss() } else { withAnimation(.smooth) { phase = .entry } } } label: {
                Image(systemName: phase == .entry || phase == .result ? "xmark" : "chevron.left")
                    .font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40).glassCircle()
            }
            .buttonStyle(PressScale())
            Spacer()
            Text(L("Термінал").s).font(.headline)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 8)
    }

    // MARK: Сума

    private var entry: some View {
        ScrollView {
            VStack(spacing: 22) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Merchant.all) { m in
                            Button { withAnimation(.snappy) { merchant = m } } label: {
                                Label(m.name, systemImage: m.symbol).font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14).frame(height: 38)
                                    .foregroundStyle(merchant == m ? Theme.onAccent : Theme.ink)
                                    .background(merchant == m ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.ultraThinMaterial), in: .capsule)
                            }
                            .buttonStyle(PressScale())
                        }
                    }
                }
                .padding(.top, 14)
                VStack(spacing: 6) {
                    Text(merchant.name).font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(digits.isEmpty ? "0" : digits).font(.system(size: 64, weight: .semibold)).tracking(-1.5).monospacedDigit()
                            .foregroundStyle(digits.isEmpty ? Color.secondary : Theme.ink)
                            .contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text("TAX").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.accent)
                    }
                    if amount >= 1000 {
                        Label("3-D Secure", systemImage: "lock.shield").font(.footnote.weight(.medium)).foregroundStyle(Theme.accent)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                keypad
                Button(amount > 0 ? L("Списати \(OverviewView.compact(amount))").s : L("Введіть суму").s) {
                    withAnimation(.smooth) { phase = .waiting }
                }
                .buttonStyle(InkButton()).disabled(amount <= 0)
                if !history.isEmpty { batch }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(keys, id: \.self) { k in
                Button { tap(k) } label: {
                    Group {
                        if k == "⌫" { Image(systemName: "delete.left") } else { Text(k) }
                    }
                    .font(.system(size: 26, weight: .medium)).frame(maxWidth: .infinity).frame(height: 58)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressScale())
                .sensoryFeedback(.selection, trigger: digits)
            }
        }
    }

    private func tap(_ k: String) {
        withAnimation(.snappy(duration: 0.15)) {
            switch k {
            case "⌫": if !digits.isEmpty { digits.removeLast() }
            case ".":
                if !digits.contains(".") { digits += digits.isEmpty ? "0." : "." }
            default:
                if let dot = digits.firstIndex(of: "."), digits.distance(from: dot, to: digits.endIndex) > 2 { return }
                if digits.count < 8 { digits += k }
            }
        }
    }

    // MARK: Історія пачки

    private var batch: some View {
        let ok = history.filter { $0.status == "captured" }
        let gross = ok.reduce(0) { $0 + ($1.amount ?? 0) }, fee = ok.reduce(0) { $0 + ($1.fee ?? 0) }
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Пачка").s).caption()
            Card {
                HStack {
                    stat(L("Оборот").s, Format.short(gross))
                    stat(L("Комісія").s, Format.short(fee))
                    stat(L("Платежів").s, "\(ok.count)")
                }
                .padding(18)
                ForEach(history.prefix(6)) { p in
                    Rule().padding(.leading, 18)
                    Button { detail = p } label: { posRow(p) }.buttonStyle(.plain)
                }
            }
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 18, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(t).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func posRow(_ p: API.PosPayment) -> some View {
        HStack(spacing: 12) {
            Image(systemName: p.isApproved ? "checkmark" : (p.isRefunded ? "arrow.uturn.backward" : "xmark"))
                .font(.system(size: 14, weight: .bold)).frame(width: 34, height: 34)
                .foregroundStyle(p.status == "declined" ? Theme.alert : Theme.accent)
                .background((p.status == "declined" ? Theme.alert : Theme.accent).opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.merchant ?? "").font(.body.weight(.medium)).lineLimit(1)
                Text(statusText(p)).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(Format.short(p.amount ?? 0)).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                .strikethrough(p.isRefunded).foregroundStyle(p.status == "declined" ? Color.secondary : Theme.ink)
        }
        .padding(.horizontal, 18).padding(.vertical, 10).contentShape(.rect)
    }

    private func statusText(_ p: API.PosPayment) -> String {
        switch p.status {
        case "captured": L("Оплачено").s
        case "refunded": L("Повернено").s
        default: L("Відхилено").s
        }
    }

    // MARK: Очікування картки

    private var waiting: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                Text(merchant.name).font(.subheadline).foregroundStyle(.secondary)
                Text(OverviewView.compact(amount)).font(.system(size: 44, weight: .semibold)).tracking(-1).monospacedDigit()
            }
            NfcRings().frame(height: 200)
            if cards.isEmpty {
                Text(L("Карток немає").s).foregroundStyle(.secondary)
            } else {
                TabView(selection: $cardIndex) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { i, c in
                        VirtualCardView(number: c.maskedNumber, expiry: c.expiryDisplay, holder: nil, look: c.look, frozen: c.isBlocked)
                            .frame(width: 250).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 176)
            }
            Spacer(minLength: 0)
            Button(L("Прикласти картку").s) { Task { await charge(tds: nil) } }
                .buttonStyle(InkButton()).disabled(cards.isEmpty)
                .padding(.bottom, 8)
        }
    }

    // MARK: Обробка

    private static var stageNames: [String: String] { ["terminal": L("Термінал").s, "acquirer": L("Еквайр").s, "network": L("Мережа").s, "issuer": L("Емітент").s] }
    private static let stageSymbols = ["terminal": "creditcard.and.123", "acquirer": "building.columns", "network": "point.3.connected.trianglepath.dotted", "issuer": "lock.shield"]

    private var processing: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            ProgressView().controlSize(.large).tint(Theme.accent).opacity(stagesShown < 4 ? 1 : 0)
            VStack(spacing: 0) {
                ForEach(Array(["terminal", "acquirer", "network", "issuer"].enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 14) {
                        Image(systemName: Self.stageSymbols[s] ?? "circle").font(.system(size: 17)).frame(width: 28)
                            .foregroundStyle(i < stagesShown ? Theme.accent : Color.secondary.opacity(0.5))
                        Text(Self.stageNames[s] ?? s).font(.body.weight(.medium))
                            .foregroundStyle(i < stagesShown ? Theme.ink : Color.secondary)
                        Spacer()
                        if i < stagesShown {
                            if let ms = result?.stages?.first(where: { $0.stage == s })?.ms, model.expert {
                                Text("\(ms) ms").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(Theme.accent)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 15)
                    if i < 3 { Rule().padding(.leading, 60) }
                }
            }
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 24, style: .continuous))
            Spacer(minLength: 0)
        }
    }

    private func charge(tds: String?) async {
        error = nil; result = nil; stagesShown = 0
        withAnimation(.smooth) { phase = .processing }
        do {
            let r = try await model.api.posPay(merchant: merchant.name, category: merchant.category, amount: amount, cardId: card?.id, tds: tds)
            result = r
            for i in 1...(r.needs3Ds == true ? 3 : 4) {
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.snappy) { stagesShown = i }
            }
            if r.needs3Ds == true {
                challenge = try await model.api.challenge(amount: amount, recipient: merchant.name)
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.smooth) { phase = .result }
            await load()
        } catch {
            self.error = error.localizedDescription
            withAnimation(.smooth) { phase = .waiting }
        }
    }

    private func otpSheet(_ c: API.Challenge) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("3-D Secure").font(.display(32, .medium)).tracking(-0.8).padding(.top, 24)
            Text(L("Код для підтвердження платежу").s).foregroundStyle(.secondary)
            if let demo = c.demoOtp {
                Button { otp = demo } label: {
                    HStack { Image(systemName: "message.fill"); Text(demo).font(.system(size: 22, weight: .semibold)).monospacedDigit(); Spacer(); Text(L("Підставити").s).font(.footnote) }
                        .padding(16).background(Theme.accent.opacity(0.14), in: .rect(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            TextField("000000", text: $otp).keyboardType(.numberPad).font(.system(size: 32, weight: .semibold)).monospacedDigit()
                .padding(16).background(.ultraThinMaterial, in: .rect(cornerRadius: 16, style: .continuous))
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.alert) }
            Button(L("Підтвердити").s) {
                Task {
                    do {
                        let token = try await model.api.verifyForPayment(c, code: otp)
                        challenge = nil; otp = ""
                        await charge(tds: token)
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

    // MARK: Результат

    private var resultView: some View {
        let r = result
        let ok = r?.isApproved == true
        return VStack(spacing: 22) {
            Spacer(minLength: 0)
            Image(systemName: ok ? "checkmark" : "xmark")
                .font(.system(size: 44, weight: .bold)).foregroundStyle(ok ? Theme.onAccent : Theme.ink)
                .frame(width: 112, height: 112)
                .background(ok ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.alert), in: .circle)
                .shadow(color: (ok ? Theme.accent : Theme.alert).opacity(0.5), radius: 24, y: 8)
                .symbolEffect(.bounce, value: r?.id)
                .sensoryFeedback(ok ? .success : .error, trigger: r?.id)
            VStack(spacing: 6) {
                Text(ok ? L("Оплачено").s : L("Відхилено").s).font(.display(34, .medium)).tracking(-0.8)
                Text(OverviewView.compact(r?.amount ?? amount)).font(.title2.monospacedDigit()).foregroundStyle(Theme.accent)
                Text(ok ? merchant.name : (r?.message ?? "")).foregroundStyle(.secondary)
            }
            if ok, let r {
                Card {
                    line(L("Комісія еквайра").s, Format.short(r.fee ?? 0))
                    Rule().padding(.leading, 18)
                    line(L("Магазин отримає").s, Format.short(r.net ?? 0))
                    if model.expert {
                        Rule().padding(.leading, 18); line(L("Код авторизації").s, r.authCode ?? "")
                        Rule().padding(.leading, 18); line("RRN", r.rrn ?? "")
                        Rule().padding(.leading, 18); line(L("Код відповіді").s, r.responseCode)
                    }
                }
            } else if model.expert, let r {
                Card { line(L("Код відповіді").s, "\(r.responseCode) · \(r.message)") }
            }
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Button(L("Готово").s) { digits = ""; withAnimation(.smooth) { phase = .entry } }.buttonStyle(InkButton())
                if ok, let r, r.id != nil {
                    Button(L("Повернути платіж").s) { Task { await refund(r) } }.buttonStyle(LineButton())
                }
            }
            .padding(.bottom, 8)
        }
    }

    private func line(_ t: String, _ v: String) -> some View {
        HStack { Text(t).foregroundStyle(.secondary); Spacer(); Text(v).monospacedDigit().lineLimit(1) }
            .font(.subheadline).padding(.horizontal, 18).padding(.vertical, 13)
    }

    private func refund(_ p: API.PosPayment) async {
        guard let id = p.id, let r = try? await model.api.posRefund(id) else { return }
        withAnimation(.smooth) { result = r; digits = ""; phase = .entry }
        await load()
    }

    private func load() async {
        cards = ((try? await model.api.cards()) ?? []).filter { !$0.isClosed }.sorted { $0.isPrimary && !$1.isPrimary }
        history = (try? await model.api.posPayments()) ?? []
    }
}

/// Кільця NFC: розходяться від терміналу, поки чекає картку.
private struct NfcRings: View {
    @State private var on = false

    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Circle().strokeBorder(Theme.accent.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .scaleEffect(on ? 2.8 : 0.8).opacity(on ? 0 : 0.8)
                    .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(i) * 0.8), value: on)
            }
            Image(systemName: "wave.3.right").font(.system(size: 30, weight: .semibold)).foregroundStyle(Theme.accent)
                .frame(width: 70, height: 70).glassCircle()
        }
        .onAppear { on = true }
    }
}

/// Квитанція платежу з терміналу і повернення.
struct PosReceipt: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State var payment: API.PosPayment
    let changed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(payment.merchant ?? "").font(.display(30, .medium)).tracking(-0.8).padding(.top, 28)
            Text(OverviewView.compact(payment.amount ?? 0)).font(.title2.monospacedDigit()).foregroundStyle(Theme.accent)
            Card {
                row(L("Статус").s, payment.isRefunded ? L("Повернено").s : (payment.isApproved ? L("Оплачено").s : L("Відхилено").s))
                Rule().padding(.leading, 18); row(L("Комісія еквайра").s, Format.short(payment.fee ?? 0))
                if model.expert {
                    Rule().padding(.leading, 18); row(L("Код авторизації").s, payment.authCode ?? "-")
                    Rule().padding(.leading, 18); row("RRN", payment.rrn ?? "-")
                    Rule().padding(.leading, 18); row(L("Код відповіді").s, "\(payment.responseCode) · \(payment.message)")
                }
            }
            Spacer()
            if payment.status == "captured", let id = payment.id {
                Button(L("Повернути платіж").s) {
                    Task { if let r = try? await model.api.posRefund(id) { payment = r; changed() } }
                }
                .buttonStyle(LineButton())
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
        .screenBackground()
    }

    private func row(_ t: String, _ v: String) -> some View {
        HStack { Text(t).foregroundStyle(.secondary); Spacer(); Text(v).monospacedDigit().lineLimit(1) }
            .font(.subheadline).padding(.horizontal, 18).padding(.vertical, 13)
    }
}
