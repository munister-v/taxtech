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
    @State private var categoryCounts: [String: Int] = [:]
    @State private var orders: [API.Order] = []
    @State private var invoices: [API.Invoice] = []
    @State private var cart: [API.Product: Int] = [:]
    @State private var showCart = false
    @State private var detail: API.Product?
    @State private var loading = false

    enum Tab: Hashable, CaseIterable {
        case catalog, orders, invoices
        var title: String {
            switch self { case .catalog: "Каталог"; case .orders: "Замовлення"; case .invoices: "Інвойси" }
        }
    }

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
                    ShopTabs(selection: $tab)
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
        if let counts = c.categories, category == .all, search.isEmpty { categoryCounts = counts }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(Capsule().stroke(Theme.ink.opacity(0.14), lineWidth: 1))

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ShopCategory.allCases.filter { $0 == .all || categoryCounts.isEmpty || categoryCounts[$0.rawValue] != nil }) { c in
                    let on = category == c
                    Button { withAnimation(.snappy) { category = c } } label: {
                        HStack(spacing: 5) {
                            Text(c.title).font(.subheadline.weight(on ? .semibold : .regular))
                            if let n = c == .all ? categoryCounts.values.reduce(0, +) : categoryCounts[c.rawValue], n > 0 {
                                Text("\(n)").font(.caption.weight(.medium)).monospacedDigit().opacity(0.55)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(on ? Theme.ink : Color.clear, in: .capsule)
                        .overlay(Capsule().stroke(Theme.ink.opacity(on ? 0 : 0.14), lineWidth: 1))
                        .foregroundStyle(on ? Theme.onInk : Theme.ink)
                    }
                    .buttonStyle(PressScale())
                }
            }
        }
        .scrollClipDisabled()

        if browsing, !hits.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(hits.prefix(4)) { hero in
                        HeroProduct(product: hero, inCart: cart[hero] ?? 0, open: { detail = hero }, add: { add(hero) })
                            .containerRelativeFrame(.horizontal) { w, _ in hits.count > 1 ? w * 0.92 : w }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
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
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<2, id: \.self) { col in
                LazyVStack(spacing: 12) {
                    ForEach(Array(items.enumerated()).filter { $0.offset % 2 == col }, id: \.element.id) { i, p in
                        ProductTile(product: p, tall: (i / 2 + col) % 2 == 0, inCart: cart[p] ?? 0,
                                    open: { detail = p }, add: { add(p) }, remove: { remove(p) })
                            .onAppear { if p.id == items.last?.id { Task { await more() } } }
                    }
                }
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

/// Вкладки магазину.
struct ShopTabs: View {
    @Binding var selection: ShopView.Tab

    var body: some View {
        TextTabs(items: ShopView.Tab.allCases.map { ($0, $0.title) }, selection: $selection)
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
    @Environment(AppModel.self) private var model
    let product: API.Product
    var size: CGFloat = 46
    var height: CGFloat = 110
    var showsLabel = true

    /// Справжнє фото, якщо воно є; інакше показуємо знак-емодзі.
    private var photoURL: URL? {
        guard let raw = product.imageUrl, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        return URL(string: raw, relativeTo: model.serverURL)?.absoluteURL
    }

    @ViewBuilder private var picture: some View {
        if let url = photoURL {
            // фото на світлій плитці: студійні знімки зазвичай на білому тлі
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFit().padding(10).blendMode(.multiply)
                case .failure:
                    emoji
                default:
                    Rectangle().fill(.clear).overlay(ProgressView().controlSize(.small))
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(Paper.card, in: .rect(cornerRadius: 14, style: .continuous))
        } else {
            emoji
        }
    }

    private var emoji: some View {
        Text(product.imageEmoji ?? "🛍️")
            .font(.system(size: size))
            .grayscale(1)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.bg, in: .rect(cornerRadius: 14, style: .continuous))
    }

    /// Мітка в куті: серверна або застереження про малий залишок.
    static func label(_ p: API.Product) -> String? {
        if let b = p.badge, !b.isEmpty { return badgeTitle(b) }
        if let n = p.stock, n > 0, n <= 5 { return "Лишилось \(n)" }
        return nil
    }

    /// Серверні мітки латиницею показуємо звичайним українським словом.
    static func badgeTitle(_ raw: String) -> String {
        switch raw.uppercased() {
        case "HOT": "Хіт"
        case "NEW": "Новинка"
        case "TOP": "Топ"
        case "DEAL": "Вигідно"
        case "SALE": "Знижка"
        case "PRO": "Pro"
        default: raw
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            picture
            if showsLabel, let l = Self.label(product) {
                Text(l)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Paper.ink.opacity(0.55))
                    .padding(10)
            }
        }
    }
}

/// Колір «паперу»: фото на білому тлі зливаються з карткою через multiply.
enum Paper {
    static let card = Color(red: 244 / 255, green: 241 / 255, blue: 234 / 255)
    static let ink = Color(red: 14 / 255, green: 14 / 255, blue: 12 / 255)
}

/// Ціна: число жирним, «TAX» дрібніше; копійки лише якщо вони є.
struct PriceText: View {
    let value: Double
    var size: CGFloat = 17
    var color: Color = Paper.ink

    var body: some View {
        (Text(value.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "uk_UA"))))
            .font(.system(size: size, weight: .bold)).monospacedDigit()
         + Text(" TAX").font(.system(size: size * 0.62, weight: .semibold)).foregroundColor(color.opacity(0.5)))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

/// Картка в мозаїці: фото на папері, назва, ціна й кругла кнопка; висота фото чергується.
struct ProductTile: View {
    let product: API.Product
    let tall: Bool
    let inCart: Int
    let open: () -> Void
    let add: () -> Void
    let remove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 8) {
                    ProductArt(product: product, height: tall ? 190 : 140)
                    Text(product.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                        .multilineTextAlignment(.leading).foregroundStyle(Paper.ink)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            HStack(spacing: 8) {
                PriceText(value: product.price)
                Spacer(minLength: 0)
                if inCart > 0 {
                    HStack(spacing: 0) {
                        Button(action: remove) { Image(systemName: "minus").frame(width: 30, height: 34) }
                        Text("\(inCart)").font(.subheadline.weight(.bold)).monospacedDigit()
                            .contentTransition(.numericText()).frame(minWidth: 14)
                        Button(action: add) { Image(systemName: "plus").frame(width: 30, height: 34) }
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.onAccent)
                    .background(Theme.accent, in: .capsule)
                    .buttonStyle(.plain)
                } else {
                    Button(action: add) {
                        Image(systemName: "plus").font(.subheadline.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(Paper.ink, in: .circle)
                            .foregroundStyle(Paper.card)
                    }
                    .buttonStyle(PressScale())
                    .accessibilityLabel("У кошик")
                }
            }
        }
        .padding(12)
        .background(Paper.card, in: .rect(cornerRadius: 24, style: .continuous))
        .animation(.snappy(duration: 0.2), value: inCart)
    }
}

/// Великий вибір дня над мозаїкою: фото праворуч, назва, ціна й жовта дія.
struct HeroProduct: View {
    @Environment(AppModel.self) private var model
    let product: API.Product
    let inCart: Int
    let open: () -> Void
    let add: () -> Void

    private var photoURL: URL? {
        guard let raw = product.imageUrl, !raw.isEmpty else { return nil }
        return raw.hasPrefix("http") ? URL(string: raw) : URL(string: raw, relativeTo: model.serverURL)?.absoluteURL
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = photoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFit().blendMode(.multiply) }
                }
                .frame(width: 175, height: 220)
            }
            VStack(alignment: .leading, spacing: 10) {
                if let l = ProductArt.label(product) {
                    Text(l).font(.caption.weight(.semibold)).foregroundStyle(Paper.ink.opacity(0.55))
                }
                Text(product.title).font(.system(size: 22, weight: .bold)).tracking(-0.4)
                    .foregroundStyle(Paper.ink).lineLimit(3)
                    .frame(maxWidth: 150, alignment: .leading)
                Spacer(minLength: 0)
                PriceText(value: product.price, size: 22)
                Button(action: add) {
                    Text(inCart > 0 ? "У кошику · \(inCart)" : "Додати").font(.subheadline.weight(.bold))
                        .padding(.horizontal, 20).frame(height: 40)
                        .background(Theme.accent, in: .capsule)
                        .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(PressScale())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(18)
        .frame(height: 270)
        .background(Paper.card, in: .rect(cornerRadius: 28, style: .continuous))
        .contentShape(.rect(cornerRadius: 28))
        .onTapGesture(perform: open)
    }
}

struct ProductView: View {
    @Environment(\.dismiss) private var dismiss
    let product: API.Product
    let inCart: Int
    let add: (Int) -> Void
    let buyNow: (Int) -> Void
    @State private var qty = 1

    private var maxQty: Int { max(1, min(product.stock ?? 10, 10)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            Paper.card
                            ProductArt(product: product, size: 110, height: 330)
                        }
                        .clipShape(.rect(cornerRadius: 28, style: .continuous))
                        if let credit = product.imageCredit {
                            Text(credit).font(.caption2).foregroundStyle(.tertiary).padding(.leading, 4)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text(product.title).font(.system(size: 28, weight: .bold)).tracking(-0.5)
                        if let d = product.description { Text(d).font(.body).foregroundStyle(.secondary) }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        PriceText(value: product.price, size: 34, color: Theme.ink)
                        Spacer()
                        let n = product.stock ?? 0
                        Text(n > 0 ? "В наявності: \(n)" : "Немає в наявності")
                            .font(.subheadline.weight(.medium)).foregroundStyle(n > 0 && n <= 5 ? Theme.ink : Color.secondary)
                    }
                    Rule()
                    HStack {
                        Text("Кількість").font(.headline)
                        Spacer()
                        HStack(spacing: 0) {
                            Button { qty = max(1, qty - 1) } label: { Image(systemName: "minus").frame(width: 44, height: 40) }
                            Text("\(qty)").font(.headline).monospacedDigit().frame(minWidth: 28)
                                .contentTransition(.numericText())
                            Button { qty = min(maxQty, qty + 1) } label: { Image(systemName: "plus").frame(width: 44, height: 40) }
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .overlay(Capsule().stroke(Theme.ink.opacity(0.14), lineWidth: 1))
                        .buttonStyle(.plain)
                        .animation(.snappy(duration: 0.2), value: qty)
                    }
                    if inCart > 0 {
                        Text("Уже в кошику: \(inCart)").font(.subheadline).foregroundStyle(.secondary)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let bought {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Оплачено").font(.system(size: 34, weight: .bold)).tracking(-0.6)
                            Text("Замовлення #\(bought.orderId)\(bought.invoiceNumber.map { ", \($0)" } ?? "")")
                                .foregroundStyle(.secondary)
                            if let b = bought.newBalance { Text("Залишок \(Format.money(b))").foregroundStyle(.secondary) }
                        }
                        .padding(.top, 40)
                    } else if cart.isEmpty {
                        BrandEmpty(title: "Кошик порожній")
                    } else {
                        Text("Кошик").font(.system(size: 28, weight: .bold)).tracking(-0.5)
                        VStack(spacing: 10) {
                            ForEach(lines, id: \.product.id) { line in cartLine(line.product, line.qty) }
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text("Разом").font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            PriceText(value: total, size: 30, color: Theme.ink)
                        }
                        .padding(.top, 4)

                        Text("Доставка").font(.title3.weight(.bold)).padding(.top, 6)
                        Surface {
                            VStack(spacing: 0) {
                                field("Ім'я та прізвище", text: $name, content: .name)
                                Rule()
                                field("Телефон", text: $phone, content: .telephoneNumber, keyboard: .phonePad)
                                Rule()
                                field("Адреса", text: $address, content: .fullStreetAddress, axis: .vertical)
                            }
                        }
                        if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                if bought == nil && !cart.isEmpty {
                    Button("Оплатити \(Format.money(total))") {
                        Task { await screen.run { challenge = try await model.api.challenge(amount: total, recipient: "Магазин TaxTech") } }
                    }
                    .buttonStyle(InkButton())
                    .disabled(name.count < 2 || address.count < 8 || screen.busy)
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 8)
                }
            }
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

    private func cartLine(_ p: API.Product, _ qty: Int) -> some View {
        HStack(spacing: 12) {
            ProductArt(product: p, size: 30, height: 76, showsLabel: false).frame(width: 76)
            VStack(alignment: .leading, spacing: 6) {
                Text(p.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                PriceText(value: p.price * Double(qty), size: 16, color: Theme.ink)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Button {
                    let q = qty - 1
                    cart[p] = q > 0 ? q : nil
                } label: { Image(systemName: qty == 1 ? "trash" : "minus").frame(width: 34, height: 36) }
                Text("\(qty)").font(.subheadline.weight(.bold)).monospacedDigit().frame(minWidth: 18)
                Button { cart[p, default: 0] += 1 } label: { Image(systemName: "plus").frame(width: 34, height: 36) }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.ink)
            .overlay(Capsule().stroke(Theme.ink.opacity(0.14), lineWidth: 1))
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Theme.surface, in: .rect(cornerRadius: 22, style: .continuous))
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType,
                       keyboard: UIKeyboardType = .default, axis: Axis = .horizontal) -> some View {
        TextField(title, text: text, axis: axis)
            .textContentType(content)
            .keyboardType(keyboard)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
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
