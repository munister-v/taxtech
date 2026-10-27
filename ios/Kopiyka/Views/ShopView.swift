import QuickLook
import SwiftUI

/// Магазин: банер, категорії, хіти, каталог із сортуванням і підвантаженням, кошик унизу екрана,
/// замовлення зі статусами кроками й чеком, інвойси. Платимо токенами TAX через 3-D Secure.
struct ShopView: View {
    @Environment(AppModel.self) private var model
    @State private var tab = Tab.catalog
    @State private var search = ""
    @State private var category: ShopCategory = .all
    @State private var sort = ShopSort.popular
    @State private var items: [API.Product] = []
    @State private var page = 1
    @State private var pages = 1
    @State private var total = 0
    @State private var hits: [API.Product] = []
    @State private var orders: [API.Order] = []
    @State private var invoices: [API.Invoice] = []
    @State private var cart: [API.Product: Int] = [:]
    @State private var showCart = false
    @State private var detail: API.Product?
    @State private var loading = false

    enum Tab: Hashable { case catalog, orders, invoices }

    private var cartCount: Int { cart.values.reduce(0, +) }
    private var cartTotal: Double { cart.reduce(0) { $0 + $1.key.price * Double($1.value) } }
    private var browsing: Bool { search.isEmpty && category == .all && sort == .popular }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScreenTitle(title: "Магазин") {
                        Button { showCart = true } label: {
                            ZStack(alignment: .topTrailing) {
                                RoundGlyph(symbol: "bag")
                                if cartCount > 0 {
                                    Text("\(cartCount)").font(.caption2.weight(.bold)).monospacedDigit()
                                        .frame(minWidth: 18, minHeight: 18)
                                        .background(Theme.accent, in: .circle).foregroundStyle(Theme.onAccent)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Кошик, товарів: \(cartCount)")
                    }
                    SegmentBar(items: [(Tab.catalog, "Каталог"), (.orders, "Замовлення"), (.invoices, "Інвойси")], selection: $tab)
                    switch tab {
                    case .catalog: catalog
                    case .orders: ordersList
                    case .invoices: invoicesList
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, cartCount > 0 ? 96 : 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { if cartCount > 0 && !showCart { cartBar } }
            .task(id: "\(search)|\(category.rawValue)|\(sort.rawValue)") {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                await reload()
            }
            .task {
                hits = ((try? await model.api.catalog(search: "", page: 1, sort: "stock", perPage: 40))?.items ?? [])
                    .filter { ["HOT", "TOP", "NEW"].contains($0.badge ?? "") }
            }
            .task(id: tab) { await loadLists() }
            .refreshable {
                await reload()
                await loadLists()
            }
            .sheet(isPresented: $showCart) {
                CartView(cart: $cart) {
                    tab = .orders
                    await loadLists()
                }
            }
            .sheet(item: $detail) { p in
                ProductView(product: p, inCart: cart[p] ?? 0) { qty in cart[p, default: 0] += qty } buyNow: { qty in
                    cart[p, default: 0] += qty
                    showCart = true
                }
            }
            .sensoryFeedback(.increase, trigger: cartCount)
        }
    }

    private func reload() async {
        loading = true
        defer { loading = false }
        guard let c = try? await model.api.catalog(search: search, page: 1, category: category.key, sort: sort.key) else { return }
        items = c.items
        page = 1
        pages = c.pages
        total = c.total
    }

    private func more() async {
        guard page < pages, !loading else { return }
        loading = true
        defer { loading = false }
        guard let c = try? await model.api.catalog(search: search, page: page + 1, category: category.key, sort: sort.key) else { return }
        items += c.items.filter { p in !items.contains { $0.id == p.id } }
        page = c.page
    }

    private func loadLists() async {
        async let o = model.api.orders()
        async let i = model.api.invoices()
        orders = (try? await o) ?? []
        invoices = (try? await i) ?? []
    }

    private func add(_ p: API.Product) { cart[p, default: 0] += 1 }

    private func remove(_ p: API.Product) {
        let q = (cart[p] ?? 0) - 1
        cart[p] = q > 0 ? q : nil
    }

    // MARK: Каталог

    @ViewBuilder private var catalog: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Пошук товарів…", text: $search).autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ShopCategory.allCases) { c in
                    Button { withAnimation(.snappy) { category = c } } label: {
                        VStack(spacing: 8) {
                            Image(systemName: c.symbol)
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 58, height: 58)
                                .background(category == c ? Theme.accent : Theme.surface, in: .rect(cornerRadius: 18, style: .continuous))
                                .foregroundStyle(category == c ? Theme.onAccent : Theme.ink)
                            Text(c.title).font(.caption.weight(category == c ? .semibold : .regular))
                                .foregroundStyle(category == c ? Theme.ink : .secondary)
                        }
                        .frame(width: 70)
                    }
                    .buttonStyle(PressScale())
                }
            }
            .padding(.horizontal, 1)
        }
        .scrollClipDisabled()

        if browsing && !hits.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Хіти").font(.title3.weight(.bold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(hits.prefix(10)) { p in
                            HitCard(product: p, inCart: cart[p] ?? 0, open: { detail = p }) { add(p) }
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }

        HStack(alignment: .firstTextBaseline) {
            Text(category == .all ? "Усі товари" : category.title).font(.title3.weight(.bold))
            Text("\(total)").foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            Menu {
                Picker("Сортування", selection: $sort) {
                    ForEach(ShopSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label(sort.title, systemImage: "arrow.up.arrow.down")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.top, 4)

        if items.isEmpty && !loading { BrandEmpty(title: "Нічого не знайдено") }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(items) { p in
                ProductTile(product: p, inCart: cart[p] ?? 0, open: { detail = p }, add: { add(p) }, remove: { remove(p) })
                    .onAppear { if p.id == items.last?.id { Task { await more() } } }
            }
        }
        if loading { ProgressView().frame(maxWidth: .infinity).padding() }
    }

    private var cartBar: some View {
        Button { showCart = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(cartCount) у кошику").font(.caption).foregroundStyle(Theme.onAccent.opacity(0.7))
                    Text(Format.money(cartTotal)).font(.headline).monospacedDigit()
                }
                Spacer()
                Text("Оформити").font(.headline)
                Image(systemName: "arrow.right")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.onAccent)
            .background(Theme.accent, in: .rect(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 8)
        }
        .buttonStyle(PressScale())
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Замовлення й інвойси

    @ViewBuilder private var ordersList: some View {
        if orders.isEmpty {
            BrandEmpty(title: "Замовлень ще немає", action: "До каталогу") { tab = .catalog }
        }
        ForEach(orders) { o in OrderRow(order: o) }
    }

    @ViewBuilder private var invoicesList: some View {
        if invoices.isEmpty {
            BrandEmpty(title: "Інвойсів ще немає")
        } else {
            HeroPanel {
                HeroCaption("Оплачено інвойсів")
                BigAmount(value: invoices.filter { $0.status == "paid" }.reduce(0) { $0 + $1.amount }, size: 30)
                    .padding(.top, 6)
            }
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

enum ShopCategory: String, CaseIterable, Identifiable {
    case all, phones, laptops, audio, gaming, appliances, home, wearables, tablets, gadgets
    var id: String { rawValue }
    var key: String? { self == .all ? nil : rawValue }

    var title: String {
        switch self {
        case .all: "Усе"
        case .phones: "Смартфони"
        case .laptops: "Ноутбуки"
        case .audio: "Аудіо"
        case .gaming: "Ігри"
        case .appliances: "Техніка"
        case .home: "Для дому"
        case .wearables: "Годинники"
        case .tablets: "Планшети"
        case .gadgets: "Гаджети"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .phones: "iphone"
        case .laptops: "laptopcomputer"
        case .audio: "headphones"
        case .gaming: "gamecontroller"
        case .appliances: "tv"
        case .home: "house"
        case .wearables: "applewatch"
        case .tablets: "ipad"
        case .gadgets: "camera"
        }
    }
}

enum ShopSort: String, CaseIterable, Identifiable {
    case popular, cheap, expensive, newest, name
    var id: String { rawValue }
    var key: String? {
        switch self {
        case .popular: nil
        case .cheap: "price_asc"
        case .expensive: "price_desc"
        case .newest: "newest"
        case .name: "name_asc"
        }
    }
    var title: String {
        switch self {
        case .popular: "Популярні"
        case .cheap: "Дешевші"
        case .expensive: "Дорожчі"
        case .newest: "Нові"
        case .name: "За назвою"
        }
    }
}

enum ShopText {
    static func status(_ s: String) -> String {
        ["paid": "Оплачено", "awaiting_payment": "Очікує оплати", "issued": "Виставлено", "expired": "Прострочено",
         "cancelled": "Скасовано", "shipped": "Відправлено", "delivered": "Доставлено", "processing": "Обробляється"][s] ?? s
    }

    /// Крок замовлення: 0 - оплачено, 1 - обробляється, 2 - відправлено, 3 - доставлено.
    static func step(_ s: String) -> Int {
        ["paid": 0, "processing": 1, "shipped": 2, "delivered": 3][s] ?? 0
    }
}

/// Знак товару - емодзі в сірому на тлі.
struct ProductArt: View {
    let product: API.Product
    var size: CGFloat = 46
    var height: CGFloat = 110

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(product.imageEmoji ?? "🛍️")
                .font(.system(size: size))
                .grayscale(1)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Theme.bg, in: .rect(cornerRadius: 14, style: .continuous))
            if let b = product.badge, !b.isEmpty {
                Text(b)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Theme.ink, in: .rect(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(Theme.onInk)
                    .padding(8)
            }
        }
    }
}

/// Плитка товару: знак, назва, ціна; у кошику - лічильник «− 1 +».
struct ProductTile: View {
    let product: API.Product
    let inCart: Int
    let open: () -> Void
    let add: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 10) {
                    ProductArt(product: product)
                    Text(product.title).font(.subheadline.weight(.semibold)).lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    Text(Format.money(product.price)).font(.headline).monospacedDigit()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            if inCart > 0 {
                HStack {
                    Button(action: remove) { Image(systemName: "minus").frame(width: 36, height: 34) }
                    Spacer()
                    Text("\(inCart)").font(.headline).monospacedDigit().contentTransition(.numericText())
                    Spacer()
                    Button(action: add) { Image(systemName: "plus").frame(width: 36, height: 34) }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.onAccent)
                .background(Theme.accent, in: .rect(cornerRadius: 11, style: .continuous))
                .buttonStyle(.plain)
            } else {
                Button(action: add) {
                    Label("У кошик", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.ink, lineWidth: 1))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
        .animation(.snappy(duration: 0.2), value: inCart)
    }
}

/// Широка картка хіта для горизонтальної стрічки.
struct HitCard: View {
    let product: API.Product
    let inCart: Int
    let open: () -> Void
    let add: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    ProductArt(product: product, size: 40, height: 84).frame(width: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                        Text(Format.money(product.price)).font(.headline).monospacedDigit()
                    }
                    .frame(width: 130, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            Button(action: add) {
                Group { if inCart > 0 { Text("\(inCart)").monospacedDigit() } else { Image(systemName: "plus") } }
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(Theme.accent, in: .circle)
                    .foregroundStyle(Theme.onAccent)
            }
            .buttonStyle(PressScale())
        }
        .padding(10)
        .background(Theme.surface, in: .rect(cornerRadius: 20, style: .continuous))
    }
}

struct ProductView: View {
    @Environment(\.dismiss) private var dismiss
    let product: API.Product
    let inCart: Int
    let add: (Int) -> Void
    let buyNow: (Int) -> Void
    @State private var qty = 1

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProductArt(product: product, size: 110, height: 260)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.title).font(.system(size: 22, weight: .bold)).tracking(-0.3)
                        if let d = product.description { Text(d).foregroundStyle(.secondary) }
                    }
                    BigAmount(value: product.price, size: 30)
                    HStack(spacing: 16) {
                        Surface { Stat(value: "\(product.stock ?? 0) шт.", label: "в наявності").padding(14) }
                        Surface { Stat(value: inCart > 0 ? "\(inCart) шт." : "-", label: "уже в кошику").padding(14) }
                    }
                    HStack {
                        Text("Кількість").font(.headline)
                        Spacer()
                        Stepper("\(qty)", value: $qty, in: 1...max(1, min(product.stock ?? 10, 10)))
                            .labelsHidden()
                        Text("\(qty)").font(.title3.weight(.semibold)).monospacedDigit().frame(width: 30)
                    }
                    VStack(spacing: 10) {
                        Button("Купити зараз · \(Format.money(product.price * Double(qty)))") {
                            dismiss()
                            buyNow(qty)
                        }
                        .buttonStyle(InkButton())
                        Button("Додати в кошик") { add(qty); dismiss() }.buttonStyle(LineButton())
                    }
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

/// Замовлення: сума, статус кроками, інвойс і чек PDF.
struct OrderRow: View {
    @Environment(AppModel.self) private var model
    let order: API.Order
    @State private var receipt: URL?
    @State private var preview: URL?
    @State private var busy = false

    private static let steps = ["Оплачено", "Обробка", "Відправлено", "Доставлено"]

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Замовлення #\(order.id)").font(.headline)
                        Text("\(order.itemsCount ?? 1) поз., \(BankText.date(order.createdAt))").font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.money(order.totalAmount)).font(.headline).monospacedDigit()
                }
                if ["cancelled", "expired", "awaiting_payment"].contains(order.status) {
                    Text(ShopText.status(order.status)).font(.subheadline.weight(.semibold))
                } else {
                    let current = ShopText.step(order.status)
                    HStack(spacing: 4) {
                        ForEach(Self.steps.indices, id: \.self) { i in
                            VStack(alignment: .leading, spacing: 6) {
                                Rectangle().fill(i <= current ? Theme.ink : Theme.line).frame(height: 3)
                                Text(Self.steps[i]).font(.caption2.weight(i == current ? .semibold : .regular))
                                    .foregroundStyle(i <= current ? Theme.ink : .secondary)
                            }
                        }
                    }
                }
                HStack {
                    if let n = order.invoiceNumber {
                        Text(n).font(.caption.monospaced()).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    Spacer()
                    if receipt != nil {
                        Button { preview = receipt } label: { Label("Чек", systemImage: "doc.richtext") }
                    } else {
                        Button {
                            busy = true
                            Task {
                                receipt = try? await model.api.document("marketplace/order/\(order.id)/receipt",
                                                                        name: "Чек замовлення \(order.id).pdf")
                                preview = receipt
                                busy = false
                            }
                        } label: {
                            Label(busy ? "Готую…" : "Чек", systemImage: "doc.text")
                        }
                        .disabled(busy)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink)
            }
            .padding(16)
        }
        .quickLookPreview($preview)
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
