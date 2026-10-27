import SwiftUI

/// Магазин: каталог товарів за віртуальні гривні, кошик з оплатою через 3-D Secure, замовлення й інвойси.
struct ShopView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = Tab.catalog
    @State private var search = ""
    @State private var page = 1
    @State private var catalog: API.Catalog?
    @State private var orders: [API.Order] = []
    @State private var invoices: [API.Invoice] = []
    @State private var cart: [API.Product: Int] = [:]
    @State private var showCart = false
    @State private var detail: API.Product?

    enum Tab: String, CaseIterable { case catalog = "Каталог", orders = "Замовлення", invoices = "Інвойси" }

    private var cartCount: Int { cart.values.reduce(0, +) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Picker("Розділ", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case .catalog: catalogView
                    case .orders: ordersView
                    case .invoices: invoicesView
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: "\(search)|\(page)") {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                catalog = try? await model.api.catalog(search: search, page: page)
            }
            .task(id: tab) { await loadLists() }
            .refreshable {
                catalog = try? await model.api.catalog(search: search, page: page)
                await loadLists()
            }
            .onChange(of: search) { page = 1 }
            .sheet(isPresented: $showCart) {
                CartView(cart: $cart) {
                    tab = .orders
                    await loadLists()
                }
            }
            .sheet(item: $detail) { p in ProductView(product: p) { add(p) } }
        }
    }

    private func loadLists() async {
        async let o = model.api.orders()
        async let i = model.api.invoices()
        orders = (try? await o) ?? []
        invoices = (try? await i) ?? []
    }

    private func add(_ p: API.Product) { cart[p, default: 0] += 1 }

    private var header: some View {
        HStack {
            Text("Магазин").font(.system(size: 32, weight: .bold)).tracking(-0.6)
            Spacer()
            Button { showCart = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bag")
                    if cartCount > 0 { Text("\(cartCount)").monospacedDigit() }
                }
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 40, minHeight: 40)
                .padding(.horizontal, cartCount > 0 ? 10 : 0)
                .background(cartCount > 0 ? Theme.ink : Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
                .foregroundStyle(cartCount > 0 ? Theme.onInk : Theme.ink)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Кошик, товарів: \(cartCount)")
        }
        .padding(.top, 12)
    }

    // MARK: Каталог

    @ViewBuilder private var catalogView: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Пошук товарів…", text: $search).autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))

        if let catalog {
            if catalog.items.isEmpty {
                Text("Нічого не знайдено").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(catalog.items) { p in
                    ProductTile(product: p, inCart: cart[p] ?? 0, open: { detail = p }) { add(p) }
                }
            }
            if catalog.pages > 1 {
                HStack {
                    Button { page -= 1 } label: { RoundGlyph(symbol: "chevron.left") }
                        .buttonStyle(.plain).disabled(page <= 1).opacity(page <= 1 ? 0.3 : 1)
                    Spacer()
                    Text("\(page) з \(catalog.pages)").font(.subheadline).monospacedDigit()
                    Spacer()
                    Button { page += 1 } label: { RoundGlyph(symbol: "chevron.right") }
                        .buttonStyle(.plain).disabled(page >= catalog.pages).opacity(page >= catalog.pages ? 0.3 : 1)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        }
    }

    // MARK: Замовлення й інвойси

    @ViewBuilder private var ordersView: some View {
        if orders.isEmpty {
            Text("Замовлень ще немає").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
        }
        ForEach(orders) { o in OrderRow(order: o) }
    }

    @ViewBuilder private var invoicesView: some View {
        if invoices.isEmpty {
            Text("Інвойсів ще немає").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 24)
        }
        if !invoices.isEmpty {
            Surface {
                ForEach(Array(invoices.enumerated()), id: \.element.id) { i, inv in
                    if i > 0 { Rule() }
                    AmountRow(title: inv.invoiceNumber,
                              subtitle: "\(ShopText.status(inv.status)), \(BankText.date(inv.paidAt ?? inv.createdAt))",
                              amount: Format.money(inv.amount))
                }
            }
        }
    }
}

enum ShopText {
    static func status(_ s: String) -> String {
        ["paid": "Оплачено", "awaiting_payment": "Очікує оплати", "issued": "Виставлено", "expired": "Прострочено",
         "cancelled": "Скасовано", "shipped": "Відправлено", "delivered": "Доставлено", "processing": "Обробляється"][s] ?? s
    }
}

/// Плитка товару: знак товару в сірому, назва, ціна і кнопка «у кошик».
struct ProductTile: View {
    let product: API.Product
    let inCart: Int
    let open: () -> Void
    let add: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    preview
                    Text(product.title).font(.subheadline.weight(.semibold)).lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            HStack {
                Text(Format.money(product.price)).font(.subheadline).monospacedDigit()
                Spacer()
                Button(action: add) {
                    Group {
                        if inCart > 0 { Text("\(inCart)").monospacedDigit() } else { Image(systemName: "plus") }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(Theme.ink, in: .rect(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(Theme.onInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Додати в кошик")
            }
        }
        .padding(12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
    }

    private var preview: some View {
        ZStack(alignment: .topTrailing) {
            Text(product.imageEmoji ?? "🛍️")
                .font(.system(size: 44))
                .grayscale(1)
                .frame(maxWidth: .infinity, minHeight: 92)
                .background(Theme.bg, in: .rect(cornerRadius: 12, style: .continuous))
            if let b = product.badge, !b.isEmpty {
                Text(b).font(.caption2.weight(.semibold)).tracking(0.6).foregroundStyle(.secondary).padding(8)
            }
        }
    }
}

struct ProductView: View {
    @Environment(\.dismiss) private var dismiss
    let product: API.Product
    let add: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(product.imageEmoji ?? "🛍️")
                        .font(.system(size: 88))
                        .grayscale(1)
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                    Text(product.title).font(.title2.weight(.semibold))
                    if let d = product.description { Text(d).foregroundStyle(.secondary) }
                    BigAmount(value: product.price, size: 32)
                    if let s = product.stock { Text("В наявності: \(s) шт.").font(.footnote).foregroundStyle(.secondary) }
                    Button("Додати в кошик") { add(); dismiss() }.buttonStyle(InkButton())
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

struct OrderRow: View {
    @Environment(AppModel.self) private var model
    let order: API.Order
    @State private var receipt: URL?
    @State private var busy = false

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Замовлення #\(order.id)").font(.headline)
                    Spacer()
                    Text(Format.money(order.totalAmount)).font(.headline).monospacedDigit()
                }
                Text("\(ShopText.status(order.status)), \(order.itemsCount ?? 1) поз., \(BankText.date(order.createdAt))")
                    .font(.footnote).foregroundStyle(.secondary)
                if let n = order.invoiceNumber {
                    Text(n).font(.caption.monospaced()).foregroundStyle(.tertiary)
                }
                if let receipt {
                    ShareLink(item: receipt) { Label("Чек PDF", systemImage: "square.and.arrow.up") }
                        .font(.footnote.weight(.medium)).foregroundStyle(Theme.ink)
                } else {
                    Button(busy ? "Готую чек…" : "Чек") {
                        busy = true
                        Task {
                            receipt = try? await model.api.document("marketplace/order/\(order.id)/receipt",
                                                                    name: "Чек замовлення \(order.id).pdf")
                            busy = false
                        }
                    }
                    .font(.footnote.weight(.medium)).foregroundStyle(Theme.ink)
                    .disabled(busy)
                }
            }
            .padding(16)
        }
    }
}

// MARK: Кошик

struct CartView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var cart: [API.Product: Int]
    let done: () async -> Void
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var challenge: API.Challenge?
    @State private var screen = Screen()
    @State private var bought: API.Purchase?

    private var total: Double { cart.reduce(0) { $0 + $1.key.price * Double($1.value) } }
    private var lines: [(product: API.Product, qty: Int)] { cart.map { ($0.key, $0.value) }.sorted { $0.product.title < $1.product.title } }

    var body: some View {
        NavigationStack {
            LabForm {
                if let bought {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Оплачено").font(.title2.weight(.semibold))
                            Text("Замовлення #\(bought.orderId)\(bought.invoiceNumber.map { ", \($0)" } ?? "")")
                                .foregroundStyle(.secondary)
                            if let b = bought.newBalance { Text("Залишок \(Format.money(b))").foregroundStyle(.secondary) }
                        }
                        .listRowBackground(Color.clear)
                    }
                } else if cart.isEmpty {
                    Section { Text("Кошик порожній").foregroundStyle(.secondary) }
                } else {
                    Section {
                        ForEach(lines, id: \.product.id) { line in
                            Stepper {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.product.title).lineLimit(1)
                                    Text("\(line.qty) × \(Format.money(line.product.price))")
                                        .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                                }
                            } onIncrement: {
                                cart[line.product, default: 0] += 1
                            } onDecrement: {
                                let q = (cart[line.product] ?? 1) - 1
                                cart[line.product] = q > 0 ? q : nil
                            }
                        }
                        Line("Разом", Format.money(total))
                    }
                    Section("Доставка") {
                        TextField("Ім'я та прізвище", text: $name).textContentType(.name)
                        TextField("Телефон", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                        TextField("Адреса", text: $address, axis: .vertical).textContentType(.fullStreetAddress)
                    }
                    ErrorSection(error: screen.error)
                    FormAction(title: "Оплатити \(Format.money(total))",
                               disabled: name.count < 2 || address.count < 8 || screen.busy) {
                        Task { await screen.run { challenge = try await model.api.challenge(amount: total, recipient: "Магазин TaxTech") } }
                    }
                }
            }
            .labForm()
            .navigationTitle("Кошик")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(bought == nil ? "Закрити" : "Готово") { dismiss() } } }
            .task {
                if name.isEmpty, let me = try? await model.api.me() {
                    name = me.fullName
                    if let p = me.phone, !p.hasPrefix("apple:") { phone = p }
                }
            }
            .sheet(item: $challenge) { c in
                ThreeDSView(challenge: c, amount: total, merchant: "Магазин TaxTech") {
                    let paid = await screen.run {
                        bought = try await model.api.checkout(cart, name: name, phone: phone, address: address)
                    }
                    if paid {
                        cart = [:]
                        await done()
                    }
                }
            }
        }
    }
}

// MARK: 3-D Secure

/// Підтвердження оплати кодом. У навчальному банку SMS немає, тому код показано тут же.
struct ThreeDSView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let challenge: API.Challenge
    let amount: Double
    let merchant: String
    let verified: () async -> Void
    @State private var code = ""
    @State private var left = 0
    @State private var screen = Screen()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                MarkView(height: 32)
                Text("Підтвердження оплати").font(.title2.weight(.semibold))
                Surface {
                    Line2("Отримувач", merchant)
                    Rule()
                    Line2("Сума", Format.money(amount))
                }
                Text("Код надіслано на \(challenge.maskedPhone ?? "ваш телефон").")
                    .font(.footnote).foregroundStyle(.secondary)
                if let demo = challenge.demoOtp {
                    Text("Навчальний банк: ваш код \(demo)").font(.footnote.monospaced())
                }
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 34, weight: .semibold).monospaced())
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                    .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(6)) }
                Text(left > 0 ? String(format: "Код дійсний ще %d:%02d", left / 60, left % 60) : "Час вийшов - почніть оплату знову")
                    .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                Spacer()
                Button("Підтвердити") {
                    Task {
                        if await screen.run({ try await model.api.verify(challenge, code: code) }) {
                            await verified()
                            dismiss()
                        }
                    }
                }
                .buttonStyle(InkButton())
                .disabled(code.count != 6 || left <= 0 || screen.busy)
                Text("3-D Secure · навчальний банк TaxTech").font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
            }
            .padding(24)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } } }
            .task {
                left = challenge.expiresIn
                while left > 0 && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    left -= 1
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(screen.busy)
    }
}
