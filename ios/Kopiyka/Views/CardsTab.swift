import SwiftUI

/// Картки: стрічка карток угорі, під нею все про вибрану - статус, дизайн, баланс, активність і дії.
struct CardsTab: View {
    @Environment(AppModel.self) private var model
    @State private var cards: [API.Card] = []
    @State private var account: API.Account?
    @State private var monthOut: Double?
    @State private var index = 0
    @State private var revealed: API.Revealed?
    @State private var issuing = false
    @State private var designing: API.Card?
    @State private var topping: API.Card?
    @State private var confirmClose = false
    @State private var screen = Screen()
    @State private var loaded = false

    private var card: API.Card? { cards.indices.contains(index) ? cards[index] : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if loaded && cards.isEmpty {
                        VStack(spacing: 14) {
                            VirtualCardView(number: "•••• •••• •••• ••••", expiry: nil, holder: nil, design: .rose)
                            Text("Карток ще немає.")
                                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                    } else {
                        carousel
                        if let card { details(card) }
                    }
                    ErrorSection(error: screen.error)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task { await load() }
            .refreshable { await load() }
            .onChange(of: index) { revealed = nil }
            .sheet(isPresented: $issuing) { IssueCardView { await load() } }
            .sheet(item: $designing) { c in CardDesignPicker(card: c) { await load() } }
            .sheet(item: $topping) { c in
                AmountSheet(title: "На картку", action: "Поповнити", hint: "З головного рахунку на картку.", amount: 500) { a in
                    try await model.api.topUpCard(c.id, a)
                    await load()
                }
            }
            .confirmationDialog("Закрити картку назавжди?", isPresented: $confirmClose, titleVisibility: .visible) {
                Button("Закрити картку", role: .destructive) {
                    if let card { act { try await model.api.closeCard(card.id) } }
                }
            }
        }
    }

    private func load() async {
        async let c = model.api.cards()
        async let a = model.api.account()
        async let s = model.api.analytics()
        cards = ((try? await c) ?? []).filter { !$0.isClosed }.sorted { $0.isPrimary && !$1.isPrimary }
        account = try? await a
        monthOut = (try? await s)?.currentMonth.totalOut
        index = min(index, max(cards.count - 1, 0))
        loaded = true
    }

    private func act(_ work: @escaping () async throws -> Void) {
        Task {
            if await screen.run(work) { await load() }
        }
    }

    // MARK: Шапка і стрічка

    private var header: some View {
        ScreenTitle(title: "Картки") {
            Button { issuing = true } label: {
                Label("Випустити", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                    .foregroundStyle(Theme.onAccent)
            }
            .buttonStyle(PressScale())
        }
    }

    private var carousel: some View {
        VStack(spacing: 10) {
            TabView(selection: $index) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                    VirtualCardView(number: i == index ? (revealed?.cardNumber ?? c.maskedNumber) : c.maskedNumber,
                                    expiry: c.expiryDisplay, holder: c.holderName,
                                    design: CardDesign(server: c.design), frozen: c.isBlocked)
                        .padding(.horizontal, 2)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: (UIScreen.main.bounds.width - 2 * Theme.gutter) / 1.586 + 4)
            .animation(.smooth, value: card?.isBlocked)
            if cards.count > 1 {
                HStack(spacing: 6) {
                    ForEach(cards.indices, id: \.self) { i in
                        Rectangle().fill(i == index ? Theme.ink : Theme.line).frame(width: 18, height: 2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Вибрана картка

    private func details(_ c: API.Card) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Surface {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(revealed?.cardNumber ?? c.maskedNumber).font(.headline.monospaced())
                        Spacer()
                        Text(c.isBlocked ? "Заморожена" : "Активна").font(.footnote.weight(.medium))
                            .foregroundStyle(c.isBlocked ? .secondary : Theme.ink)
                    }
                    .padding(16)
                    Rule()
                    Line2("Тип", "Віртуальна\(c.expiryDisplay.map { ", до \($0)" } ?? "")")
                    Rule()
                    HStack {
                        Text("Дизайн").foregroundStyle(.secondary)
                        Text(CardDesign(server: c.design).title)
                        Spacer()
                        Button("Змінити") { designing = c }.font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                    }
                    .padding(16)
                    if let r = revealed {
                        Rule()
                        Line2("CVV", r.cvv)
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Баланс картки").caption()
                    BigAmount(value: c.displayBalance ?? 0, size: 28)
                    HStack(spacing: 10) {
                        Button("Поповнити") { topping = c }.buttonStyle(InkButton())
                        if !c.isPrimary {
                            Button("Зробити головною") { act { try await model.api.setPrimary(c.id) } }.buttonStyle(LineButton())
                        } else {
                            Text("Головна картка").font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(16)
            }
            if let monthOut {
                Surface {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Активність рахунку за місяць").caption()
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            BigAmount(value: monthOut, size: 24)
                            Text("витрат").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                QuickTile(title: revealed == nil ? "Реквізити" : "Сховати", symbol: "creditcard") {
                    if revealed != nil { revealed = nil } else { act { revealed = try await model.api.reveal(c.id) } }
                }
                NavigationLink { SecurityView() } label: { TileLabel(title: "PIN", symbol: "lock") }.buttonStyle(.plain)
                QuickTile(title: "Дизайн", symbol: "paintbrush") { designing = c }
                QuickTile(title: "Рахунок", symbol: "number") {
                    if let n = account?.accountNumber { UIPasteboard.general.string = n }
                }
            }
            HStack(spacing: 10) {
                Button(c.isBlocked ? "Розморозити" : "Заморозити") { act { try await model.api.toggleCardBlock(c.id) } }
                    .buttonStyle(LineButton())
                Button("Закрити") { confirmClose = true }.buttonStyle(LineButton())
            }
        }
        .disabled(screen.busy)
    }
}

/// Рядок «назва - значення» всередині поверхні.
struct Line2: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .padding(16)
    }
}

/// Вигляд плитки без власної дії - для NavigationLink.
struct TileLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 42, height: 42)
                .background(Theme.ink, in: .rect(cornerRadius: Theme.corner, style: .continuous))
                .foregroundStyle(Theme.onInk)
            Spacer(minLength: 18)
            Text(title).font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.corner, style: .continuous))
        .contentShape(.rect)
    }
}
