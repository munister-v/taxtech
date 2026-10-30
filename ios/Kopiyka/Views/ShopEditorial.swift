import SwiftUI

/// Редакційна мова магазину SAINT AGNES: широкі розряджені капітелі, велике фото, чисті картки без рамок.
enum ShopStyle {
    static let cream = Color(red: 247 / 255, green: 245 / 255, blue: 240 / 255)
    static let ink = Color(red: 23 / 255, green: 23 / 255, blue: 20 / 255)
    static let tan = Color(red: 220 / 255, green: 180 / 255, blue: 138 / 255)
    static let photoBack = Color(red: 236 / 255, green: 235 / 255, blue: 232 / 255)

    /// Широкий гротеск, як геометричний шрифт на сайті.
    static func caps(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }
}

extension API.Product {
    /// Бренд - перший сегмент опису («KOCCA · …»).
    var brand: String {
        (description ?? "").components(separatedBy: " · ").first?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    /// Коротка назва без артикула в дужках і без бренду на кінці.
    var shortName: String {
        var name = title
        if let r = name.range(of: #"\s*\([^)]*\)\s*$"#, options: .regularExpression) { name.removeSubrange(r) }
        name = name.trimmingCharacters(in: .whitespaces)
        if !brand.isEmpty, name.lowercased().hasSuffix(brand.lowercased()) {
            let rest = String(name.dropLast(brand.count)).trimmingCharacters(in: .whitespaces)
            if !rest.isEmpty { name = rest }
        }
        return name
    }

    /// Артикул з дужок у кінці назви.
    var code: String? {
        guard let r = title.range(of: #"\(([^)]*)\)\s*$"#, options: .regularExpression) else { return nil }
        return title[r].trimmingCharacters(in: CharacterSet(charactersIn: "() "))
    }

    /// Мітка на фото: серверна або «Остання одиниця».
    @MainActor var tag: String? {
        if let b = badge, !b.isEmpty { return ProductArt.badgeTitle(b) }
        if stock == 1 { return L("Остання одиниця").s }
        return nil
    }
}

struct ShopWordmark: View {
    var size: CGFloat = 22

    var body: some View {
        Text("SAINT AGNES")
            .font(.system(size: size, weight: .regular).width(.expanded))
            .tracking(size * 0.3)
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

/// Заголовок розділу: розряджені капітелі й дрібний підпис.
struct ShopHeading: View {
    let title: String
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(ShopStyle.caps(19)).tracking(1.6).textCase(.uppercase).foregroundStyle(Theme.ink)
            if let sub { Text(sub).font(.footnote).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Знак TaxPay: жовтий квадрат із «T».
struct TaxPayMark: View {
    var size: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(Theme.accent)
            .frame(width: size, height: size)
            .overlay {
                Text("T").font(.system(size: size * 0.62, weight: .heavy)).foregroundStyle(Theme.onAccent)
            }
    }
}

/// Головний банер: осіннє фото, заголовок у два рядки, кнопка й підпис про TaxPay.
struct ShopHero: View {
    let onShop: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("ShopHero")
                .resizable().scaledToFill()
                .frame(maxWidth: .infinity, minHeight: 420, maxHeight: 420)
                .clipped()
            LinearGradient(stops: [
                .init(color: .black.opacity(0.06), location: 0),
                .init(color: .black.opacity(0.1), location: 0.4),
                .init(color: Color(red: 8 / 255, green: 8 / 255, blue: 7 / 255).opacity(0.84), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L("Осінь").s).foregroundStyle(ShopStyle.cream)
                    Text(L("вже тут").s).foregroundStyle(ShopStyle.tan)
                }
                .font(.system(size: 40, weight: .medium).width(.expanded))
                .textCase(.uppercase)
                .tracking(0.8)
                HStack(spacing: 16) {
                    Button(action: onShop) {
                        HStack(spacing: 10) {
                            Text(L("До каталогу").s).textCase(.uppercase).tracking(1.2).lineLimit(1).fixedSize()
                            Image(systemName: "arrow.right").font(.footnote.weight(.semibold))
                        }
                        .font(ShopStyle.caps(12, .semibold))
                        .foregroundStyle(ShopStyle.ink)
                        .padding(.horizontal, 20).frame(height: 48)
                        .background(ShopStyle.cream, in: .rect(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(PressScale())
                    HStack(spacing: 8) {
                        TaxPayMark()
                        Text(L("Оплата TaxPay").s).font(.footnote).foregroundStyle(ShopStyle.cream.opacity(0.85))
                    }
                    .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(22)
        }
        .clipShape(.rect(cornerRadius: 28, style: .continuous))
    }
}

/// Чотири гарантії магазину 2 x 2 між тонкими лініями.
struct ShopTrust: View {
    private let items: [(icon: String?, text: String)] = [
        ("shippingbox", L("Нова пошта").s), ("checkmark.shield", L("100% оригінал").s),
        ("arrow.2.squarepath", L("Обмін 14 днів").s), (nil, L("Оплата TaxPay").s),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: 1)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 18) {
                ForEach(items, id: \.text) { item in
                    HStack(spacing: 11) {
                        if let icon = item.icon {
                            Image(systemName: icon).font(.system(size: 19, weight: .light)).frame(width: 22)
                        } else {
                            TaxPayMark(size: 22)
                        }
                        Text(item.text).font(ShopStyle.caps(10.5)).tracking(1.1).textCase(.uppercase)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Theme.ink.opacity(0.85))
                }
            }
            .padding(.vertical, 20)
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}

/// Дві фото-плитки «Жінкам» / «Чоловікам».
struct ShopCollections: View {
    let pick: (ShopCategory) -> Void

    var body: some View {
        HStack(spacing: 12) {
            tile("ShopWomen", .women, L("Жінкам").s, L("Сукні · верхній одяг · взуття").s)
            tile("ShopMen", .men, L("Чоловікам").s, L("Сорочки · поло · костюми").s)
        }
    }

    private func tile(_ image: String, _ category: ShopCategory, _ title: String, _ sub: String) -> some View {
        Button { pick(category) } label: {
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay { Image(image).resizable().scaledToFill() }
                .overlay {
                    LinearGradient(colors: [.clear, Color(red: 8 / 255, green: 8 / 255, blue: 7 / 255).opacity(0.8)],
                                   startPoint: .init(x: 0.5, y: 0.45), endPoint: .bottom)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(title).font(ShopStyle.caps(14)).tracking(1).textCase(.uppercase).lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right").font(.caption.weight(.semibold))
                        }
                        Text(sub).font(.caption).foregroundStyle(ShopStyle.cream.opacity(0.72))
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(ShopStyle.cream)
                    .padding(14)
                }
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(PressScale())
    }
}

/// Фото товару 3:4 на світлому тлі; запасний варіант - знак-емодзі.
struct ShopPhoto: View {
    @Environment(AppModel.self) private var model
    let product: API.Product
    var radius: CGFloat = 16
    var ratio: CGFloat = 3 / 4

    private var url: URL? {
        guard let raw = product.imageUrl, !raw.isEmpty else { return nil }
        return raw.hasPrefix("http") ? URL(string: raw) : URL(string: raw, relativeTo: model.serverURL)?.absoluteURL
    }

    var body: some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay {
                ZStack {
                    ShopStyle.photoBack
                    if let url {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else if phase.error != nil {
                                Text(product.imageEmoji ?? "🛍️").font(.system(size: 44)).grayscale(1)
                            } else {
                                ProgressView().controlSize(.small)
                            }
                        }
                    } else {
                        Text(product.imageEmoji ?? "🛍️").font(.system(size: 44)).grayscale(1)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}

/// Мітка на фото: світла «табличка» з дрібними капітелями.
struct ShopTag: View {
    let text: String

    var body: some View {
        Text(text).font(ShopStyle.caps(9, .semibold)).tracking(0.9).textCase(.uppercase)
            .foregroundStyle(ShopStyle.ink)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(ShopStyle.cream, in: .rect(cornerRadius: 5, style: .continuous))
    }
}

/// Картка товару без рамки: фото, бренд капітелями, назва, ціна. Кнопка «у кошик» на фото.
struct ShopCard: View {
    let product: API.Product
    let inCart: Int
    let open: () -> Void
    let add: () -> Void

    private var out: Bool { (product.stock ?? 1) <= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: open) {
                    ShopPhoto(product: product)
                        .overlay(alignment: .topLeading) {
                            if let tag = product.tag { ShopTag(text: tag).padding(10) }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                Button(action: add) {
                    ZStack {
                        Image(systemName: "bag.badge.plus").font(.system(size: 16, weight: .regular))
                            .opacity(inCart > 0 ? 0 : 1)
                        if inCart > 0 {
                            Text("\(inCart)").font(.subheadline.weight(.bold)).monospacedDigit()
                                .contentTransition(.numericText(value: Double(inCart)))
                        }
                    }
                    .foregroundStyle(ShopStyle.ink)
                    .frame(width: 36, height: 36)
                    .background(ShopStyle.cream.opacity(0.95), in: .rect(cornerRadius: 12, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .buttonStyle(PressScale())
                .disabled(out)
                .opacity(out ? 0.45 : 1)
                .padding(10)
                .accessibilityLabel(L("У кошик").s)
            }
            Button(action: open) {
                VStack(alignment: .leading, spacing: 4) {
                    if !product.brand.isEmpty {
                        Text(product.brand).font(ShopStyle.caps(10.5, .semibold)).tracking(1.3).textCase(.uppercase)
                            .foregroundStyle(Theme.ink).lineLimit(1)
                    }
                    Text(product.shortName).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(product.price.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "uk_UA"))))
                            .font(.system(size: 16, weight: .semibold)).monospacedDigit().foregroundStyle(Theme.accent)
                        Text("TAX").font(.system(size: 10, weight: .medium)).tracking(0.6).foregroundStyle(.tertiary)
                    }
                    .padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 11).padding(.horizontal, 2)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .animation(.snappy(duration: 0.2), value: inCart)
    }
}

/// Вкладки з підкресленням: розряджені капітелі, жовта лінія під активною.
struct ShopTabBar<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T
    var gap: CGFloat = 26
    @Namespace private var ns

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: gap) {
                ForEach(items.indices, id: \.self) { i in
                    let on = selection == items[i].0
                    Button { withAnimation(.snappy(duration: 0.25)) { selection = items[i].0 } } label: {
                        VStack(spacing: 10) {
                            Text(items[i].1).font(ShopStyle.caps(11.5, on ? .semibold : .medium)).tracking(1.5).textCase(.uppercase)
                                .foregroundStyle(on ? Theme.ink : Color.secondary)
                            ZStack {
                                Rectangle().fill(Color.clear).frame(height: 2)
                                if on { Rectangle().fill(Theme.accent).frame(height: 2).matchedGeometryEffect(id: "shop-tab-\(items.count)", in: ns) }
                            }
                        }
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1).offset(y: 0) }
    }
}
