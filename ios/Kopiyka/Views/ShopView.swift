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
    @State private var categoryCounts: [String: Int] = [:]
    @State private var orders: [API.Order] = []
    @State private var invoices: [API.Invoice] = []
    @State private var cart: [API.CartLine: Int] = [:]
    @State private var showCart = false
    @State private var detail: API.Product?
    @State private var loading = false
    @State private var detailSource = ""
    @Namespace private var zoom

    enum Tab: Hashable, CaseIterable {
        case catalog, orders, invoices
        var title: String {
            switch self { case .catalog: L("Каталог").s; case .orders: L("Замовлення").s; case .invoices: L("Інвойси").s }
        }
    }

    private var cartCount: Int { cart.values.reduce(0, +) }
    private var cartTotal: Double { cart.reduce(0) { $0 + $1.key.product.price * Double($1.value) } }
    private var browsing: Bool { search.isEmpty && category == .all && sort == .popular }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 9) {
                                ShopWordmark()
                                Text(L("Магазин · оплата TAX").s).font(ShopStyle.caps(10)).tracking(2).textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { showCart = true } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bag").font(.system(size: 23, weight: .light))
                                        .foregroundStyle(Theme.ink)
                                        .frame(width: 44, height: 44)
                                        .symbolEffect(.bounce, value: cartCount)
                                    if cartCount > 0 {
                                        Text("\(cartCount)").font(.system(size: 10, weight: .bold)).monospacedDigit()
                                            .contentTransition(.numericText(value: Double(cartCount)))
                                            .frame(minWidth: 17, minHeight: 17)
                                            .background(Theme.accent, in: .circle).foregroundStyle(Theme.onAccent)
                                            .offset(x: -2, y: 4)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L("Кошик, товарів: \(cartCount)").s)
                        }
                        .padding(.top, 10)
                        ShopTabBar(items: Tab.allCases.map { ($0, $0.title) }, selection: $tab)
                        switch tab {
                        case .catalog: catalog(proxy)
                        case .orders: ordersList
                        case .invoices: invoicesList
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, cartCount > 0 ? 96 : 32)
                }
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
                ProductView(product: p, inCart: { size in cart[API.CartLine(product: p, size: size)] ?? 0 }) { size, qty in
                    cart[API.CartLine(product: p, size: size), default: 0] += qty
                } buyNow: { size, qty in
                    cart[API.CartLine(product: p, size: size), default: 0] += qty
                    showCart = true
                }
                .navigationTransition(.zoom(sourceID: detailSource, in: zoom))
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

    private func inCart(_ p: API.Product) -> Int { cart.filter { $0.key.product.id == p.id }.values.reduce(0, +) }

    private func openDetail(_ p: API.Product) { detailSource = "p\(p.id)"; detail = p }

    // MARK: Каталог

    private func scrollToGrid(_ proxy: ScrollViewProxy) {
        withAnimation(.smooth(duration: 0.5)) { proxy.scrollTo("shop-grid", anchor: .top) }
    }

    @ViewBuilder private func catalog(_ proxy: ScrollViewProxy) -> some View {
        if browsing {
            ShopHero { scrollToGrid(proxy) }
            ShopTrust()
            ShopHeading(title: L("Колекції").s, sub: L("Оригінальні бренди з Європи").s)
            ShopCollections { c in
                withAnimation(.snappy) { category = c }
                Task { try? await Task.sleep(for: .milliseconds(120)); scrollToGrid(proxy) }
            }
        }

        ShopHeading(title: category == .all ? L("Добірка").s : category.title, sub: browsing ? L("Обране цього тижня").s : nil)
            .padding(.top, browsing ? 10 : 0)
            .id("shop-grid")

        ShopTabBar(items: ShopCategory.allCases
            .filter { $0 == .all || categoryCounts.isEmpty || categoryCounts[$0.rawValue] != nil }
            .map { ($0, $0.title) }, selection: $category, gap: 22)

        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .light)).foregroundStyle(.secondary)
            TextField(L("Пошук товарів…").s, text: $search).autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1).offset(y: 8) }
        .padding(.bottom, 4)

        HStack(alignment: .firstTextBaseline) {
            Text(L("\(total) товарів").s).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            Spacer()
            Menu {
                Picker(L("Сортування").s, selection: $sort) {
                    ForEach(ShopSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sort.title).textCase(.uppercase).tracking(1.2)
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
                }
                .font(ShopStyle.caps(10.5, .semibold))
                .foregroundStyle(Theme.ink)
            }
        }

        if items.isEmpty && !loading { BrandEmpty(title: L("Нічого не знайдено").s) }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 26) {
            ForEach(items) { p in
                // Швидке «додати» відкриває картку: розмір треба обрати до кошика.
                ShopCard(product: p, inCart: inCart(p),
                         open: { openDetail(p) }, add: { openDetail(p) })
                    .matchedTransitionSource(id: "p\(p.id)", in: zoom)
                    .onAppear { if p.id == items.last?.id { Task { await more() } } }
            }
        }
        if loading { ProgressView().frame(maxWidth: .infinity).padding() }
    }

    private var cartBar: some View {
        Button { showCart = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("\(cartCount) у кошику").s).font(.caption).foregroundStyle(Theme.onAccent.opacity(0.7))
                    Text(Format.money(cartTotal)).font(.headline).monospacedDigit()
                }
                Spacer()
                Text(L("Оформити").s).font(.headline)
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
            BrandEmpty(title: L("Замовлень ще немає").s, action: L("До каталогу").s) { tab = .catalog }
        }
        ForEach(orders) { o in OrderRow(order: o) }
    }

    @ViewBuilder private var invoicesList: some View {
        if invoices.isEmpty {
            BrandEmpty(title: L("Інвойсів ще немає").s)
        } else {
            HeroPanel {
                HeroCaption(L("Оплачено інвойсів").s)
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
    case all, women, men, shoes, bags, accessories, phones, laptops, audio, gaming, appliances, home, wearables, tablets, gadgets
    var id: String { rawValue }
    var key: String? { self == .all ? nil : rawValue }

    var title: String {
        switch self {
        case .all: L("Усе").s
        case .phones: L("Смартфони").s
        case .laptops: L("Ноутбуки").s
        case .audio: L("Аудіо").s
        case .gaming: L("Ігри").s
        case .appliances: L("Техніка").s
        case .home: L("Для дому").s
        case .wearables: L("Годинники").s
        case .tablets: L("Планшети").s
        case .gadgets: L("Гаджети").s
        case .women: L("Жінкам").s
        case .men: L("Чоловікам").s
        case .shoes: L("Взуття").s
        case .bags: L("Сумки").s
        case .accessories: L("Аксесуари").s
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
        case .women: "figure.dress.line.vertical.figure"
        case .men: "tshirt"
        case .shoes: "shoeprints.fill"
        case .bags: "handbag"
        case .accessories: "eyeglasses"
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
        case .popular: L("Популярні").s
        case .cheap: L("Дешевші").s
        case .expensive: L("Дорожчі").s
        case .newest: L("Нові").s
        case .name: L("За назвою").s
        }
    }
}

enum ShopText {
    static func status(_ s: String) -> String {
        ["paid": L("Оплачено").s, "awaiting_payment": L("Очікує оплати").s, "issued": L("Виставлено").s, "expired": L("Прострочено").s,
         "cancelled": L("Скасовано").s, "shipped": L("Відправлено").s, "delivered": L("Доставлено").s, "processing": L("Обробляється").s][s] ?? s
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
        if let n = p.stock, n > 0, n <= 5 { return L("Лишилось \(n)").s }
        return nil
    }

    /// Серверні мітки латиницею показуємо звичайним українським словом.
    static func badgeTitle(_ raw: String) -> String {
        switch raw.uppercased() {
        case "HOT": L("Хіт").s
        case "NEW": L("Новинка").s
        case "TOP": L("Топ").s
        case "DEAL": L("Вигідно").s
        case "SALE": L("Знижка").s
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
    /// У світлій темі тло застосунку саме кремове, тож картка біла; у темній - кремовий «папір».
    static let card = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 244 / 255, green: 241 / 255, blue: 234 / 255, alpha: 1) : .white })
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

struct ProductView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let product: API.Product
    /// Скільки цього товару в розмірі `size` уже в кошику.
    let inCart: (String) -> Int
    let add: (String, Int) -> Void
    let buyNow: (String, Int) -> Void
    @State private var qty = 1
    @State private var sizes: [API.ProductSize] = []
    @State private var sizesLoaded = false
    @State private var size = ""

    private static let freeFrom = 3000.0

    private var needsSize: Bool { !sizes.isEmpty }
    private var chosen: API.ProductSize? { sizes.first { $0.size == size } }
    private var soldOut: Bool { needsSize ? sizes.allSatisfy { $0.available <= 0 } : (product.stock ?? 1) <= 0 }
    /// Скільки можна взяти: залишок обраного розміру (або товару без розмірів), не більше 10.
    private var maxQty: Int {
        let stock = needsSize ? (chosen?.available ?? 10) : (product.stock ?? 10)
        return max(1, min(stock, 10))
    }
    private var needsPick: Bool { needsSize && chosen == nil }
    private var canBuy: Bool { sizesLoaded && !soldOut && !needsPick }
    private var subtotal: Double { product.price * Double(qty) }

    /// Відправка протягом 1–2 робочих днів: дата без вихідних.
    private var dispatchBy: String {
        let cal = Calendar(identifier: .gregorian)
        var day = Date()
        var left = 2
        while left > 0 {
            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
            if !cal.isDateInWeekend(day) { left -= 1 }
        }
        return day.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "uk_UA")))
    }

    private func perk(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon).font(.system(size: 18, weight: .light)).frame(width: 24)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.ink.opacity(0.85))
    }

    private var shippingText: String {
        let left = Self.freeFrom - subtotal
        return left > 0
            ? L("Нова пошта · безкоштовно від 3 000 TAX, ще \(Format.money(left)) до безкоштовної").s
            : L("Нова пошта · доставка безкоштовна").s
    }

    private func chip(_ s: API.ProductSize) -> some View {
        let out = s.available <= 0
        let picked = s.size == size
        return Button { size = s.size } label: {
            Text(s.size).font(.subheadline.weight(.semibold)).monospacedDigit()
                .strikethrough(out)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(picked ? Theme.onInk : Theme.ink.opacity(out ? 0.3 : 1))
                .background(picked ? Theme.ink : Color.clear, in: .rect(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.ink.opacity(picked ? 0 : out ? 0.08 : 0.2), lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if !out && s.available <= 2 {
                        Circle().fill(Color.orange).frame(width: 7, height: 7).padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(out)
        .accessibilityLabel(out ? L("Розмір \(s.size), немає").s : L("Розмір \(s.size)").s)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        ShopPhoto(product: product, radius: 26, ratio: 0.9)
                            .overlay(alignment: .topLeading) {
                                if let tag = product.tag { ShopTag(text: tag).padding(14) }
                            }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        if !product.brand.isEmpty {
                            Text(product.brand).font(ShopStyle.caps(12, .semibold)).tracking(2.2).textCase(.uppercase)
                                .foregroundStyle(.secondary)
                        }
                        Text(product.shortName).font(.system(size: 28, weight: .medium).width(.expanded)).tracking(0.3)
                            .foregroundStyle(Theme.ink)
                        if let code = product.code { Text(code).font(.footnote).foregroundStyle(.tertiary) }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(product.price.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "uk_UA"))))
                                .font(.system(size: 34, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.accent)
                            Text("TAX").font(.system(size: 14, weight: .medium)).tracking(0.8).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(soldOut ? L("Немає в наявності").s : L("В наявності").s)
                            .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Rule()
                    if needsSize {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L("Розмір").s).font(.headline)
                                Spacer()
                                if needsPick { Text(L("Оберіть розмір").s).font(.footnote).foregroundStyle(.secondary) }
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                                ForEach(sizes, id: \.size) { chip($0) }
                            }
                            if let c = chosen, c.available <= 2 {
                                HStack(spacing: 6) {
                                    Circle().fill(Color.orange).frame(width: 7, height: 7)
                                    Text(c.available == 1 ? L("Остання одиниця в розмірі \(c.size)").s : L("Лишилось \(c.available) шт. у розмірі \(c.size)").s)
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    HStack {
                        Text(L("Кількість").s).font(.headline)
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
                    let already = inCart(size)
                    if already > 0 {
                        Text(L("Уже в кошику: \(already)").s).font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 10) {
                        Button(soldOut ? L("Немає в наявності").s : needsPick ? L("Оберіть розмір").s : L("Купити зараз · \(Format.money(subtotal))").s) {
                            dismiss()
                            buyNow(size, qty)
                        }
                        .buttonStyle(InkButton())
                        .disabled(!canBuy)
                        Button(L("Додати в кошик").s) { add(size, qty); dismiss() }
                            .buttonStyle(LineButton())
                            .disabled(!canBuy)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        perk("shippingbox", shippingText)
                        perk("clock", L("Відправка за 1–2 робочі дні, до \(dispatchBy)").s)
                        perk("arrow.2.squarepath", L("Обмін і повернення 14 днів").s)
                        perk("checkmark.shield", L("Лише оригінал, з гарантією").s)
                    }
                    .padding(.top, 8)
                }
                .padding(Theme.gutter)
            }
            .screenBackground()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Готово").s) { dismiss() } } }
            .task {
                sizes = await model.api.sizes(for: product.id)
                sizesLoaded = true
            }
            .onChange(of: size) { qty = min(qty, maxQty) }
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

    private static var steps: [String] { [L("Оплачено").s, L("Обробка").s, L("Відправлено").s, L("Доставлено").s] }

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L("Замовлення #\(order.id)").s).font(.headline)
                        Text(L("\(order.itemsCount ?? 1) поз., \(BankText.date(order.createdAt))").s).font(.footnote).foregroundStyle(.secondary)
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
                        Button { preview = receipt } label: { Label(L("Чек").s, systemImage: "doc.richtext") }
                    } else {
                        Button {
                            busy = true
                            Task {
                                receipt = try? await model.api.document("marketplace/order/\(order.id)/receipt",
                                                                        name: L("Чек замовлення \(order.id).pdf").s)
                                preview = receipt
                                busy = false
                            }
                        } label: {
                            Label(busy ? L("Готую…").s : L("Чек").s, systemImage: "doc.text")
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
    @Binding var cart: [API.CartLine: Int]
    let done: () async -> Void
    @State private var name = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var tried = false
    @State private var challenge: API.Challenge?
    @State private var screen = Screen()
    @State private var bought: API.Purchase?

    private var total: Double { cart.reduce(0) { $0 + $1.key.product.price * Double($1.value) } }
    /// Рядки згруповано за товаром і розміром (ключ кошика), відсортовано за назвою.
    private var lines: [(line: API.CartLine, qty: Int)] {
        cart.map { ($0.key, $0.value) }.sorted { ($0.line.product.title, $0.line.size) < ($1.line.product.title, $1.line.size) }
    }

    // MARK: Перевірка доставки

    private var nameError: String? {
        let n = name.trimmingCharacters(in: .whitespaces)
        let ok = n.filter(\.isLetter).count >= 2 && n.allSatisfy { $0.isLetter || " '’ʼ-.".contains($0) }
        return ok ? nil : L("Вкажіть ім'я та прізвище, лише літери").s
    }

    private var phoneError: String? {
        let p = phone.filter { !" ()-\u{00A0}".contains($0) }
        if p.isEmpty { return L("Вкажіть номер телефону").s }
        guard p.range(of: #"^\+?\d{9,15}$"#, options: .regularExpression) != nil,
              !(p.hasPrefix("0") && p.count != 10)
        else { return L("Невірний номер, приклад: +380 50 123 45 67").s }
        return nil
    }

    private var addressError: String? {
        address.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8
            ? nil : L("Вкажіть адресу: місто, вулиця або відділення (від 8 символів)").s
    }

    private func pay() {
        tried = true
        guard nameError == nil, phoneError == nil, addressError == nil else { return }
        Task { await screen.run { challenge = try await model.api.challenge(amount: total, recipient: "munister") } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let bought {
                        VStack(alignment: .leading, spacing: 10) {
                            PaidMark()
                            Text(L("Оплачено").s).font(.display(34)).tracking(-0.8).rise(1)
                            Text(L("Замовлення #\(bought.orderId)\(bought.invoiceNumber.map { ", \($0)" } ?? "")").s)
                                .foregroundStyle(.secondary)
                            if let b = bought.newBalance { Text(L("Залишок \(Format.money(b))").s).foregroundStyle(.secondary) }
                        }
                        .padding(.top, 40)
                    } else if cart.isEmpty {
                        BrandEmpty(title: L("Кошик порожній").s)
                    } else {
                        Text(L("Кошик").s).font(.display(28)).tracking(-0.8)
                        VStack(spacing: 0) {
                            ForEach(lines, id: \.line) { cartLine($0.line, $0.qty) }
                        }
                        HStack(alignment: .firstTextBaseline) {
                            Text(L("Разом").s).font(.headline).foregroundStyle(.secondary)
                            Spacer()
                            PriceText(value: total, size: 30, color: Theme.ink)
                        }
                        .padding(.top, 4)

                        Text(L("Доставка").s).font(.title3.weight(.bold)).padding(.top, 6)
                        Surface {
                            VStack(spacing: 0) {
                                field(L("Ім'я та прізвище").s, text: $name, content: .name, error: nameError)
                                Rule()
                                field(L("Телефон").s, text: $phone, content: .telephoneNumber, keyboard: .phonePad, error: phoneError)
                                Rule()
                                field(L("Адреса").s, text: $address, content: .fullStreetAddress, axis: .vertical, error: addressError)
                            }
                        }
                        if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.red) }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                if bought == nil && !cart.isEmpty {
                    Button(L("Оплатити \(Format.money(total))").s, action: pay)
                        .buttonStyle(InkButton())
                        .disabled(screen.busy)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(bought == nil ? L("Закрити").s : L("Готово").s) { dismiss() } } }
            .task {
                if name.isEmpty, let me = try? await model.api.me() {
                    name = me.fullName
                    if let p = me.phone, !p.hasPrefix("apple:") { phone = p }
                }
            }
            .sheet(item: $challenge) { c in
                ThreeDSView(challenge: c, amount: total, merchant: "munister") {
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

    private func cartLine(_ line: API.CartLine, _ qty: Int) -> some View {
        let p = line.product
        return HStack(spacing: 14) {
            ShopPhoto(product: p, radius: 10).frame(width: 58)
            VStack(alignment: .leading, spacing: 4) {
                if !p.brand.isEmpty {
                    Text(p.brand).font(ShopStyle.caps(10.5, .semibold)).tracking(1.3).textCase(.uppercase).lineLimit(1)
                }
                Text(p.shortName).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                if !line.size.isEmpty {
                    Text(L("Розмір \(line.size)").s).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink.opacity(0.7))
                }
                PriceText(value: p.price * Double(qty), size: 16, color: Theme.accent)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                Button {
                    let q = qty - 1
                    cart[line] = q > 0 ? q : nil
                } label: { Image(systemName: qty == 1 ? "trash" : "minus").frame(width: 34, height: 36) }
                Text("\(qty)").font(.subheadline.weight(.bold)).monospacedDigit().frame(minWidth: 18)
                Button { cart[line, default: 0] += 1 } label: { Image(systemName: "plus").frame(width: 34, height: 36) }
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.ink)
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType,
                       keyboard: UIKeyboardType = .default, axis: Axis = .horizontal, error: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(title, text: text, axis: axis)
                .textContentType(content)
                .keyboardType(keyboard)
            if tried, let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
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
                Text(L("Підтвердження оплати").s).font(.title2.weight(.semibold))
                Surface {
                    Line2(L("Отримувач").s, merchant)
                    Rule()
                    Line2(L("Сума").s, Format.money(amount))
                }
                Text(L("Код надіслано на \(challenge.maskedPhone ?? L("ваш телефон").s).").s)
                    .font(.footnote).foregroundStyle(.secondary)
                if let demo = challenge.demoOtp {
                    Text(L("Навчальний банк: ваш код \(demo)").s).font(.footnote.monospaced())
                }
                TextField("000000", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .font(.system(size: 34, weight: .semibold).monospaced())
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 12)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                    .onChange(of: code) { code = String(code.filter(\.isNumber).prefix(6)) }
                Text(left > 0 ? String(format: L("Код дійсний ще %d:%02d").s, left / 60, left % 60) : L("Час вийшов - почніть оплату знову").s)
                    .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                if let e = screen.error { Text(e).font(.footnote).foregroundStyle(.secondary) }
                Spacer()
                Button(L("Підтвердити").s) {
                    Task {
                        if await screen.run({ try await model.api.verify(challenge, code: code) }) {
                            await verified()
                            dismiss()
                        }
                    }
                }
                .buttonStyle(InkButton())
                .disabled(code.count != 6 || left <= 0 || screen.busy)
                Text(L("3-D Secure · навчальний банк TaxTech").s).font(.caption).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
            }
            .padding(24)
            .screenBackground()
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Скасувати").s) { dismiss() } } }
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

/// Велика галочка після оплати: коло наливається жовтим, позначка домальовується, телефон відгукується.
struct PaidMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var filled = false
    @State private var drawn = false

    var body: some View {
        ZStack {
            Circle().fill(Theme.accent)
                .scaleEffect(filled ? 1 : 0.3)
                .opacity(filled ? 1 : 0)
            Path { p in
                p.move(to: CGPoint(x: 26, y: 46))
                p.addLine(to: CGPoint(x: 40, y: 60))
                p.addLine(to: CGPoint(x: 66, y: 32))
            }
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(Theme.onAccent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 92, height: 92)
        .sensoryFeedback(.success, trigger: drawn)
        .task {
            if reduce { filled = true; drawn = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { filled = true }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeOut(duration: 0.35)) { drawn = true }
        }
    }
}
