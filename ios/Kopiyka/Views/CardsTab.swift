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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(Theme.ink.opacity(0.16), lineWidth: 1))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(PressScale())
        }
    }

    private var carousel: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                        VirtualCardView(number: i == index ? (revealed?.cardNumber ?? c.maskedNumber) : c.maskedNumber,
                                        expiry: c.expiryDisplay, holder: c.holderName,
                                        design: CardDesign(server: c.design), frozen: c.isBlocked)
                            .tilt()
                            .containerRelativeFrame(.horizontal)
                            .scrollTransition(axis: .horizontal) { v, phase in
                                v.scaleEffect(phase.isIdentity ? 1 : 0.86)
                                    .opacity(phase.isIdentity ? 1 : 0.5)
                                    .rotation3DEffect(.degrees(phase.value * -28), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                                    .blur(radius: phase.isIdentity ? 0 : 2)
                            }
                            .id(i)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding(get: { index }, set: { if let v = $0 { index = v } }))
            .scrollClipDisabled()
            .animation(.smooth, value: card?.isBlocked)
            .sensoryFeedback(.selection, trigger: index)
            if cards.count > 1 {
                HStack(spacing: 6) {
                    ForEach(cards.indices, id: \.self) { i in
                        Capsule().fill(i == index ? Theme.ink : Theme.line).frame(width: i == index ? 26 : 8, height: 4)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: index)
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
                    Line2("Статус", c.isBlocked ? "Заморожена" : "Активна")
                    Rule()
                    Line2("Тип", "Віртуальна\(c.expiryDisplay.map { ", до \($0)" } ?? "")")
                    Rule()
                    Button { designing = c } label: {
                        HStack {
                            Text("Дизайн").foregroundStyle(.secondary)
                            Spacer()
                            Text(CardDesign(server: c.design).title)
                            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if let r = revealed {
                        Rule()
                        Line2("CVV", r.cvv)
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Баланс картки").caption()
                        Spacer()
                        if c.isPrimary {
                            Text("Головна")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.ink.opacity(0.1), in: .capsule)
                        }
                    }
                    BigAmount(value: c.displayBalance ?? 0, size: 38)
                    VStack(spacing: 10) {
                        Button { topping = c } label: {
                            Label("Поповнити картку", systemImage: "plus")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(Theme.ink, in: .capsule)
                                .foregroundStyle(Theme.onInk)
                        }
                        .buttonStyle(PressScale())
                        if !c.isPrimary {
                            Button("Зробити головною") { act { try await model.api.setPrimary(c.id) } }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .overlay(Capsule().stroke(Theme.ink.opacity(0.16), lineWidth: 1))
                                .foregroundStyle(Theme.ink)
                                .buttonStyle(PressScale())
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                QuickTile(title: revealed == nil ? "Реквізити" : "Сховати", symbol: "creditcard") {
                    if revealed != nil { revealed = nil } else { act { revealed = try await model.api.reveal(c.id) } }
                }
                NavigationLink { SecurityView() } label: { TileLabel(title: "PIN", symbol: "lock") }.buttonStyle(.plain)
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
                .background(Theme.ink, in: .rect(cornerRadius: 12, style: .continuous))
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
