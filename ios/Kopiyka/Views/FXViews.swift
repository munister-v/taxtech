import SwiftUI

private func code(_ c: String) -> String { c }

/// Знак валюти для великих цифр.
private func symbol(_ c: String) -> String {
    ["USD": "$", "EUR": "€", "GBP": "£", "PLN": "zł", "CHF": "Fr", "TAX": "T"][c] ?? c
}

private func amount(_ v: Double, _ cur: String) -> String { Format.amount(v) + " " + cur }

// MARK: Рахунки

/// Основний рахунок TAX і валютні гаманці з IBAN, курси та обмін.
struct AccountsView: View {
    @Environment(AppModel.self) private var model
    @State private var data: API.FXAccounts?
    @State private var rates: API.FXRates?
    @State private var exchange = false
    @State private var screen = Screen()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenTitle(Tx("Рахунки", "Accounts", "Счета"))
                if let data {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Tx("Усього в еквіваленті", "Total in TAX", "Всего в эквиваленте")).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(Digits.tight(Format.amount(data.totalTax), size: 40)).font(Theme.mono(40, .bold)).minimumScaleFactor(0.5).lineLimit(1)
                            Text("TAX").font(Theme.mono(16, .bold)).foregroundStyle(Theme.accent)
                        }
                    }
                    HStack(spacing: 10) {
                        Button { exchange = true } label: { Label(Tx("Обмін", "Exchange", "Обмен"), systemImage: "arrow.left.arrow.right") }
                            .buttonStyle(InkButton())
                        NavigationLink { CertificatesView(accounts: data.accounts) } label: {
                            Label(Tx("Довідки", "Certificates", "Справки"), systemImage: "doc.badge.gearshape")
                        }
                        .buttonStyle(LineButton())
                    }
                    VStack(spacing: 12) {
                        ForEach(data.accounts) { a in
                            NavigationLink { WalletView(account: a, accounts: data.accounts) } label: { AccountCard(account: a) }
                                .buttonStyle(PressScale())
                        }
                    }
                    if !data.available.isEmpty {
                        BlockTitle(Tx("Відкрити рахунок", "Open an account", "Открыть счёт"))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(data.available, id: \.self) { c in
                                    Button { Task { await open(c) } } label: {
                                        HStack(spacing: 8) {
                                            Text(symbol(c)).font(Theme.mono(15, .bold)).foregroundStyle(Theme.accent)
                                            Text(c).font(Theme.ui(style: .subheadline, .semibold))
                                            Image(systemName: "plus").font(Theme.ui(style: .caption1, .bold)).foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 16).frame(height: 44)
                                        .background(Theme.surface, in: .capsule)
                                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
                                    }
                                    .buttonStyle(PressScale())
                                }
                            }
                        }
                    }
                }
                if let rates {
                    BlockTitle(Tx("Курси", "Rates", "Курсы"), trailing: rates.updatedAt)
                    Surface {
                        HStack {
                            Text("").frame(width: 56, alignment: .leading)
                            Spacer()
                            Text(Tx("Продаж", "Sell", "Продажа")).frame(width: 84, alignment: .trailing)
                            Text(Tx("Купівля", "Buy", "Покупка")).frame(width: 84, alignment: .trailing)
                        }
                        .font(Theme.ui(style: .caption1)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 12)
                        ForEach(rates.rates) { r in
                            Rule()
                            HStack {
                                Text(r.currency).font(Theme.mono(15, .bold)).frame(width: 56, alignment: .leading)
                                Spacer()
                                Text(String(format: "%.2f", r.bid)).frame(width: 84, alignment: .trailing)
                                Text(String(format: "%.2f", r.ask)).frame(width: 84, alignment: .trailing)
                            }
                            .font(Theme.mono(15)).padding(.horizontal, 16).padding(.vertical, 13)
                        }
                    }
                    Text(Tx("Курс за 1 одиницю в TAX. Різниця між купівлею і продажем (\(String(format: "%.1f", rates.spread * 100))% з кожного боку) і є ціна обміну.",
                            "Rate per 1 unit in TAX. The gap between buy and sell (\(String(format: "%.1f", rates.spread * 100))% each way) is the cost of exchange.",
                            "Курс за 1 единицу в TAX. Разница между покупкой и продажей (\(String(format: "%.1f", rates.spread * 100))% с каждой стороны) и есть цена обмена."))
                        .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                }
                ErrorSection(error: screen.error)
            }
            .padding(.horizontal, Theme.gutter).padding(.bottom, 40)
        }
        .screenBackground(.orbit)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $exchange, onDismiss: { Task { await load() } }) {
            if let data { ExchangeView(accounts: data.accounts, rates: rates?.rates ?? []).presentationDragIndicator(.visible) }
        }
    }

    private func load() async {
        await screen.run {
            async let a = model.api.fxAccounts()
            async let r = model.api.fxRates()
            data = try await a
            rates = try await r
        }
    }

    private func open(_ c: String) async {
        if await screen.run({ _ = try await model.api.fxOpen(c) }) { await load() }
    }
}

/// Рахунок як картка з гільйошем: валюта, залишок, IBAN.
struct AccountCard: View {
    let account: API.FXAccount
    var large = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(red: 0.14, green: 0.13, blue: 0.11), Color(red: 0.06, green: 0.06, blue: 0.05)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { ctx, size in
                var c = ctx
                Engraving.rosette(in: &c, center: CGPoint(x: size.width * 0.9, y: size.height * 0.2), radius: size.height * 0.7,
                                  curves: 10, lobes: 8, color: Theme.gold.opacity(0.28))
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(account.currency).font(Theme.mono(14, .bold)).foregroundStyle(Theme.accent)
                    Text(account.name).font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                    Spacer()
                    Text(symbol(account.currency)).font(Theme.mono(22, .bold)).foregroundStyle(Theme.gold.opacity(0.9))
                }
                Spacer(minLength: 14)
                Text(Digits.tight(Format.amount(account.balance), size: 30)).font(Theme.mono(30, .bold)).minimumScaleFactor(0.6).lineLimit(1)
                if large {
                    let g = account.ibanPretty.split(separator: " ").map(String.init)
                    let half = (g.count + 1) / 2
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.prefix(half).joined(separator: " "))
                        Text(g.dropFirst(half).joined(separator: " "))
                    }
                    .font(Theme.mono(14, .semibold)).foregroundStyle(Theme.ink.opacity(0.8)).padding(.top, 8)
                } else {
                    Text(account.ibanPretty).font(Theme.mono(11)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 6)
                }
            }
            .padding(18)
        }
        .frame(height: large ? 214 : 148)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.gold.opacity(0.3), lineWidth: 1))
        .foregroundStyle(Theme.ink)
    }
}

// MARK: Гаманець

struct WalletView: View {
    @Environment(AppModel.self) private var model
    let account: API.FXAccount
    let accounts: [API.FXAccount]
    @State private var txs: [API.FXTx] = []
    @State private var current: API.FXAccount
    @State private var topup = false
    @State private var transfer = false
    @State private var exchange = false
    @State private var copied = false
    @State private var screen = Screen()

    init(account: API.FXAccount, accounts: [API.FXAccount]) {
        self.account = account
        self.accounts = accounts
        _current = State(initialValue: account)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AccountCard(account: current, large: true)
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = current.iban
                        copied = true
                        Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
                    } label: {
                        Label(copied ? Tx("Скопійовано", "Copied", "Скопировано") : Tx("Копіювати IBAN", "Copy IBAN", "Копировать IBAN"), systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(Theme.ui(style: .footnote, .semibold)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14).frame(height: 36).glassCapsule()
                    }
                    ShareLink(item: "\(current.ibanPretty)\n\(Brand.name) · \(current.currency)") {
                        Label(Tx("Поділитися", "Share", "Поделиться"), systemImage: "square.and.arrow.up")
                            .font(Theme.ui(style: .footnote, .semibold)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, 14).frame(height: 36).glassCapsule()
                    }
                    Spacer()
                }
                .buttonStyle(PressScale())
                HStack(alignment: .top, spacing: 0) {
                    if current.id != 0 {
                        CircleAction(title: Tx("Поповнити", "Top up", "Пополнить"), symbol: "plus", primary: true) { topup = true }
                    }
                    CircleAction(title: Tx("Переказ", "Send", "Перевод"), symbol: "arrow.up.right", primary: current.id == 0) { transfer = true }
                    CircleAction(title: Tx("Обмін", "Exchange", "Обмен"), symbol: "arrow.left.arrow.right") { exchange = true }
                }
                .padding(.vertical, 14)
                .glass(30)
                if current.id != 0 {
                    BlockTitle(Tx("Рух коштів", "Activity", "Движение средств"))
                    if txs.isEmpty {
                        VStack(spacing: 12) {
                            GuillocheBadge(symbol: "tray", size: 52)
                            Text(Tx("Поки порожньо. Поповніть рахунок або зробіть обмін.", "Nothing yet. Top up or exchange.", "Пока пусто. Пополните счёт или сделайте обмен."))
                                .font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(24).glass(22)
                    } else {
                        Surface {
                            ForEach(Array(txs.enumerated()), id: \.element.id) { i, t in
                                if i > 0 { Rule() }
                                HStack(spacing: 12) {
                                    GuillocheBadge(symbol: t.isIncome ? "arrow.down.left" : "arrow.up.right", size: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.description).font(Theme.ui(style: .subheadline, .medium)).lineLimit(2)
                                        Text(BankText.date(String(t.createdAt.prefix(10)))).font(Theme.ui(style: .caption1)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text((t.isIncome ? "+" : "−") + Format.amount(t.amount)).font(Theme.mono(15, .bold))
                                        .foregroundStyle(t.isIncome ? Theme.accent : Theme.ink)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                        }
                    }
                } else {
                    Text(Tx("Операції основного рахунку - у вкладці «Активність».", "Main account activity is in the Activity tab.", "Операции основного счёта - во вкладке «Активность»."))
                        .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                }
                ErrorSection(error: screen.error)
            }
            .padding(.horizontal, Theme.gutter).padding(.bottom, 40)
        }
        .screenBackground(.orbit)
        .navigationTitle(current.currency)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $topup, onDismiss: { Task { await load() } }) { TopupView(account: current) { current = $0 }.presentationDetents([.medium]) }
        .sheet(isPresented: $transfer, onDismiss: { Task { await load(); await model.refresh() } }) { IbanTransferView(account: current).presentationDragIndicator(.visible) }
        .sheet(isPresented: $exchange, onDismiss: { Task { await load(); await model.refresh() } }) {
            ExchangeView(accounts: accounts, rates: [], from: current.currency).presentationDragIndicator(.visible)
        }
    }

    private func load() async {
        await screen.run {
            if let fresh = try await model.api.fxAccounts().accounts.first(where: { $0.id == account.id }) { current = fresh }
            if account.id != 0 { txs = try await model.api.fxTransactions(account.id) }
        }
    }
}

// MARK: Поповнення

private struct TopupView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let account: API.FXAccount
    var onDone: (API.FXAccount) -> Void
    @State private var value = 100.0
    @State private var screen = Screen()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Tx("Вхідний переказ", "Incoming transfer", "Входящий перевод")).font(Theme.mono(20, .bold))
            Text(Tx("Навчальне зарахування, ніби прийшов \(account.currency == "EUR" ? "SEPA" : "SWIFT")-переказ на ваш IBAN.",
                    "A training credit, as if a \(account.currency == "EUR" ? "SEPA" : "SWIFT") transfer arrived at your IBAN.",
                    "Учебное зачисление, будто пришёл \(account.currency == "EUR" ? "SEPA" : "SWIFT")-перевод на ваш IBAN."))
                .font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary)
            CurrencyField(title: Tx("Сума", "Amount", "Сумма"), value: $value, currency: account.currency)
            ErrorSection(error: screen.error)
            Button(Tx("Зарахувати", "Credit", "Зачислить")) {
                Task {
                    if await screen.run({ onDone(try await model.api.fxTopup(account.id, amount: value)) }) { dismiss() }
                }
            }
            .buttonStyle(InkButton()).disabled(value <= 0 || screen.busy)
            Spacer()
        }
        .padding(20)
        .screenBackground(.orbit)
    }
}

struct CurrencyField: View {
    let title: String
    @Binding var value: Double
    let currency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).caption()
            HStack {
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad).font(Theme.mono(26, .bold))
                Text(currency).font(Theme.mono(style: .title3, .bold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
        }
    }
}

// MARK: Обмін

struct ExchangeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let accounts: [API.FXAccount]
    let rates: [API.FXRate]
    var from = "TAX"
    @State private var source = "TAX"
    @State private var target = "USD"
    @State private var value = 1000.0
    @State private var quote: API.FXQuote?
    @State private var done: API.FXQuote?
    @State private var screen = Screen()

    private var all: [String] { ["TAX", "USD", "EUR", "GBP", "PLN", "CHF"] }
    private var owned: [String] { accounts.map(\.currency) }
    private var balance: Double { accounts.first { $0.currency == source }?.balance ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let done {
                        receipt(done)
                    } else {
                        pair
                        CurrencyField(title: Tx("Віддаєте", "You pay", "Отдаёте"), value: $value, currency: source)
                        Text(Tx("Доступно \(amount(balance, source))", "Available \(amount(balance, source))", "Доступно \(amount(balance, source))"))
                            .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                        Surface {
                            line(Tx("Отримуєте", "You get", "Получаете"), quote.map { amount($0.toAmount, target) } ?? "—", big: true)
                            Rule()
                            line(Tx("Курс", "Rate", "Курс"), quote.map { rateText($0) } ?? "—")
                            Rule()
                            line(Tx("Ціна обміну (спред)", "Cost of exchange (spread)", "Цена обмена (спред)"), quote.map { "≈ " + amount($0.spreadTax, "TAX") } ?? "—")
                        }
                        ErrorSection(error: screen.error)
                        Button(Tx("Обміняти", "Exchange", "Обменять")) { Task { await submit() } }
                            .buttonStyle(InkButton()).disabled(quote == nil || value <= 0 || value > balance || screen.busy)
                        if value > balance {
                            Text(Tx("Недостатньо коштів на рахунку.", "Insufficient funds.", "Недостаточно средств.")).font(Theme.ui(style: .footnote)).foregroundStyle(Theme.alert)
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter).padding(.bottom, 30)
            }
            .screenBackground(.orbit)
            .navigationTitle(Tx("Обмін валют", "Currency exchange", "Обмен валют"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Закрити").s) { dismiss() } } }
            .onAppear { source = from; target = from == "TAX" ? (owned.first { $0 != "TAX" } ?? "USD") : "TAX" }
            .task(id: "\(source)|\(target)|\(value)") { await refreshQuote() }
        }
    }

    private var pair: some View {
        HStack(spacing: 10) {
            picker(Tx("З", "From", "Из"), $source, owned.isEmpty ? ["TAX"] : owned)
            Button {
                let s = source; source = target; target = s
            } label: { Image(systemName: "arrow.left.arrow.right").font(Theme.ui(16, .bold)).frame(width: 44, height: 44).background(Theme.surface, in: .circle) }
                .buttonStyle(PressScale())
            picker(Tx("У", "To", "В"), $target, all.filter { $0 != source })
        }
    }

    private func picker(_ title: String, _ sel: Binding<String>, _ options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).caption()
            Menu {
                ForEach(options, id: \.self) { c in Button(c) { sel.wrappedValue = c; if source == target { target = all.first { $0 != source } ?? "TAX" } } }
            } label: {
                HStack {
                    Text(sel.wrappedValue).font(Theme.mono(20, .bold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(Theme.ui(style: .caption1, .bold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).frame(height: 54)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func line(_ k: String, _ v: String, big: Bool = false) -> some View {
        HStack {
            Text(k).font(Theme.ui(style: .subheadline)).foregroundStyle(.secondary)
            Spacer()
            Text(v).font(Theme.mono(big ? 20 : 14, .bold)).foregroundStyle(big ? Theme.accent : Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func rateText(_ q: API.FXQuote) -> String {
        if q.from == "TAX" { return "1 \(q.to) = \(String(format: "%.2f", 1 / max(q.rate, 0.000001))) TAX" }
        if q.to == "TAX" { return "1 \(q.from) = \(String(format: "%.2f", q.rate)) TAX" }
        return "1 \(q.from) = \(String(format: "%.4f", q.rate)) \(q.to)"
    }

    private func receipt(_ q: API.FXQuote) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(Theme.ui(56)).foregroundStyle(Theme.goldFill).padding(.top, 30)
            Text(Tx("Обмін виконано", "Exchange completed", "Обмен выполнен")).font(Theme.mono(22, .bold))
            Surface {
                line(Tx("Списано", "Paid", "Списано"), amount(q.fromAmount, q.from))
                Rule()
                line(Tx("Зараховано", "Received", "Зачислено"), amount(q.toAmount, q.to), big: true)
                Rule()
                line("RRN", q.rrn ?? "—")
            }
            Button(Tx("Готово", "Done", "Готово")) { dismiss() }.buttonStyle(InkButton())
        }
    }

    private func refreshQuote() async {
        guard value > 0, source != target else { quote = nil; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        quote = try? await model.api.fxQuote(from: source, to: target, amount: value)
    }

    private func submit() async {
        await screen.run {
            done = try await model.api.fxExchange(from: source, to: target, amount: value)
            await model.refresh()
        }
    }
}

// MARK: Переказ на IBAN

struct IbanTransferView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let account: API.FXAccount
    @State private var iban = ""
    @State private var name = ""
    @State private var purpose = ""
    @State private var value = 100.0
    @State private var result: API.FXTransfer?
    @State private var screen = Screen()

    private var ok: Bool { IBAN.isValid(iban) }
    private var rail: String { account.currency == "EUR" ? "SEPA" : "SWIFT" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let result {
                        VStack(spacing: 16) {
                            Image(systemName: "paperplane.circle.fill").font(Theme.ui(56)).foregroundStyle(Theme.goldFill).padding(.top, 30)
                            Text(result.isInternal ? Tx("Зараховано одразу", "Credited instantly", "Зачислено сразу")
                                                   : Tx("Переказ \(result.rail) відправлено", "\(result.rail) transfer sent", "Перевод \(result.rail) отправлен"))
                                .font(Theme.mono(20, .bold)).multilineTextAlignment(.center)
                            Surface {
                                row(Tx("Сума", "Amount", "Сумма"), amount(result.amount, result.currency))
                                Rule()
                                row(Tx("Комісія", "Fee", "Комиссия"), amount(result.fee, result.currency))
                                Rule()
                                row(Tx("Разом", "Total", "Итого"), amount(result.total, result.currency))
                                Rule()
                                row("Ref", result.reference)
                            }
                            Button(Tx("Готово", "Done", "Готово")) { dismiss() }.buttonStyle(InkButton())
                        }
                    } else {
                        Text("\(account.currency) · \(Format.amount(account.balance))").font(Theme.mono(15, .bold)).foregroundStyle(.secondary)
                        field(Tx("IBAN одержувача", "Recipient IBAN", "IBAN получателя")) {
                            TextField("UA00 0000 0000 0000 0000 0000 0000 0", text: $iban)
                                .textInputAutocapitalization(.characters).autocorrectionDisabled().font(Theme.mono(14, .bold))
                        }
                        if !iban.isEmpty {
                            Label(ok ? Tx("Контрольні цифри збігаються", "Checksum is valid", "Контрольные цифры совпадают")
                                     : Tx("IBAN не пройшов перевірку: перевірте цифри", "IBAN failed the check: re-read the digits", "IBAN не прошёл проверку: проверьте цифры"),
                                  systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(Theme.ui(style: .footnote, .semibold)).foregroundStyle(ok ? Theme.accent : Theme.alert)
                        }
                        field(Tx("Одержувач", "Beneficiary", "Получатель")) { TextField("", text: $name).textContentType(.name) }
                        CurrencyField(title: Tx("Сума", "Amount", "Сумма"), value: $value, currency: account.currency)
                        field(Tx("Призначення", "Purpose", "Назначение")) { TextField("", text: $purpose) }
                        Text(Tx("Між IBAN TaxTech у тій самій валюті - без комісії. Назовні (\(rail)) комісія 0,5%, мінімум 1.",
                                "Between TaxTech IBANs in the same currency: free. Outbound (\(rail)): 0.5% fee, minimum 1.",
                                "Между IBAN TaxTech в той же валюте - без комиссии. Наружу (\(rail)) комиссия 0,5%, минимум 1."))
                            .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                        ErrorSection(error: screen.error)
                        Button(Tx("Надіслати", "Send", "Отправить")) {
                            Task { await screen.run { result = try await model.api.fxTransfer(currency: account.currency, iban: IBAN.clean(iban), amount: value, beneficiary: name, purpose: purpose) } }
                        }
                        .buttonStyle(InkButton())
                        .disabled(!ok || name.trimmingCharacters(in: .whitespaces).isEmpty || value <= 0 || screen.busy)
                    }
                }
                .padding(.horizontal, Theme.gutter).padding(.bottom, 30)
            }
            .screenBackground(.orbit)
            .navigationTitle(Tx("Переказ на IBAN", "Send to IBAN", "Перевод на IBAN"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Закрити").s) { dismiss() } } }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v).font(Theme.mono(14, .bold)) }
            .font(Theme.ui(style: .subheadline)).padding(.horizontal, 16).padding(.vertical, 13)
    }

    private func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).caption()
            content().padding(.horizontal, 14).frame(minHeight: 50)
                .background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: Довідки

struct CertificatesView: View {
    @Environment(AppModel.self) private var model
    let accounts: [API.FXAccount]
    @State private var type = "balance"
    @State private var currency = "TAX"
    @State private var span = Span.month
    @State private var issued: [API.DocumentRecord] = []
    @State private var selected: API.DocumentRecord?
    @State private var preview: URL?
    @State private var screen = Screen()

    enum Span: Hashable { case month, quarter, year }

    private var types: [(String, String, String)] {
        [("balance", Tx("Залишок", "Balance", "Остаток"), "scalemass"),
         ("turnover", Tx("Обороти", "Turnover", "Обороты"), "chart.bar"),
         ("income", Tx("Доходи", "Income", "Доходы"), "arrow.down.circle"),
         ("account", Tx("Рахунок", "Account", "Счёт"), "building.columns")]
    }

    private var needsPeriod: Bool { type == "turnover" || type == "income" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenTitle(Tx("Довідки", "Certificates", "Справки"))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(types, id: \.0) { t in
                        Button { type = t.0 } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                GuillocheBadge(symbol: t.2, size: 46)
                                Text(t.1).font(Theme.ui(style: .subheadline, .semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading).padding(14)
                            .glass(18)
                            .background(type == t.0 ? Theme.accent.opacity(0.16) : .clear, in: .rect(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(type == t.0 ? Theme.accent : .clear, lineWidth: 1.5))
                            .foregroundStyle(Theme.ink)
                        }
                        .buttonStyle(PressScale())
                    }
                }
                Text(Tx("Валюта", "Currency", "Валюта")).caption()
                SegmentBar(items: accounts.map { ($0.currency, $0.currency) }, selection: $currency)
                if needsPeriod {
                    Text(Tx("Період", "Period", "Период")).caption()
                    SegmentBar(items: [(Span.month, Tx("Місяць", "Month", "Месяц")), (.quarter, Tx("3 місяці", "3 months", "3 месяца")), (.year, Tx("Рік", "Year", "Год"))], selection: $span)
                }
                ErrorSection(error: screen.error)
                Button { Task { await issue() } } label: { Label(Tx("Отримати довідку", "Get certificate", "Получить справку"), systemImage: "doc.badge.plus") }
                    .buttonStyle(InkButton()).disabled(screen.busy)
                if !issued.isEmpty {
                    BlockTitle(Tx("Видані", "Issued", "Выданные"), trailing: "\(issued.count)")
                    Surface {
                        ForEach(Array(issued.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Rule() }
                            Button { selected = d } label: { DocumentRow(doc: d) }.buttonStyle(.plain)
                        }
                    }
                }
                Text(Tx("Кожна довідка має код і QR: сторінка перевірки показує, що запис не змінено, без повного імені й IBAN.",
                        "Each certificate has a code and QR: the verification page shows the record is intact, without the full name or IBAN.",
                        "Каждая справка имеет код и QR: страница проверки показывает, что запись не изменена, без полного имени и IBAN."))
                    .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, Theme.gutter).padding(.bottom, 40)
        }
        .screenBackground(.orbit)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadIssued() }
        .sheet(item: $selected) { DocumentDetailView(doc: $0) }
        .quickLookPreview($preview)
    }

    private func loadIssued() async {
        issued = (try? await model.api.documents(kind: "certificate")) ?? []
    }

    private func issue() async {
        let cal = Calendar.current
        let to = Date.now
        let from: Date = switch span {
        case .month: cal.dateInterval(of: .month, for: to)?.start ?? to
        case .quarter: cal.date(byAdding: .month, value: -3, to: to) ?? to
        case .year: cal.date(byAdding: .year, value: -1, to: to) ?? to
        }
        await screen.run {
            let doc = try await model.api.fxCertificate(type: type, currency: currency,
                                                        from: needsPeriod ? BankText.isoDay(from) : nil, to: needsPeriod ? BankText.isoDay(to) : nil)
            await loadIssued()
            preview = try await model.api.document(doc.pdfPath, name: doc.fileName)
        }
    }
}
