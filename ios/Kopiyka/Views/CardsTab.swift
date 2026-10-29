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
    @State private var copied = false

    private var card: API.Card? { cards.indices.contains(index) ? cards[index] : nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if loaded && cards.isEmpty {
                        empty
                    } else {
                        carousel
                        if let card { details(card) }
                    }
                    ErrorSection(error: screen.error)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 110)
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

    // MARK: Тло, шапка, стрічка

    private var header: some View {
        ScreenTitle(title: "Картки") {
            Button { issuing = true } label: {
                Label("Випустити", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.surface, in: .capsule)
                    .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(PressScale())
        }
    }

    private var empty: some View {
        VStack(spacing: 18) {
            VirtualCardView(number: "•••• •••• •••• ••••", expiry: nil, holder: nil,
                            look: CardLook(material: .glass, color: .graphite, pattern: .waves))
                .opacity(0.6)
            Text("Карток ще немає").font(.title3.weight(.semibold))
            Text("Випустіть віртуальну картку й зберіть її вигляд: матеріал, колір, візерунок.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Випустити картку") { issuing = true }.buttonStyle(InkButton())
        }
        .frame(maxWidth: .infinity)
    }

    private var carousel: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, c in
                        FlipCard(flipped: i == index && revealed != nil) {
                            VirtualCardView(number: c.maskedNumber, expiry: c.expiryDisplay, holder: c.holderName,
                                            look: c.look, frozen: c.isBlocked)
                        } back: {
                            CardBack(look: c.look, number: revealed?.cardNumber ?? c.maskedNumber,
                                     cvv: revealed?.cvv ?? "•••", expiry: c.expiryDisplay)
                        }
                        .animation(.spring(response: 0.6, dampingFraction: 0.78), value: revealed?.cardNumber)
                        .tilt()
                        .onTapGesture { if i == index { toggleReveal(c) } }
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
            if let card {
                VStack(spacing: 4) {
                    Text(card.look.name.isEmpty ? "Картка •• \(card.maskedNumber.suffix(4))" : card.look.name)
                        .font(.headline)
                        .contentTransition(.opacity)
                    HStack(spacing: 6) {
                        Circle().fill(card.isBlocked ? Color.cyan : Color.green).frame(width: 6, height: 6)
                        Text(card.isBlocked ? "Заморожена" : (card.isPrimary ? "Головна · активна" : "Активна"))
                        if let e = card.expiryDisplay { Text("· до \(e)") }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .animation(.smooth, value: index)
            }
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

    private func toggleReveal(_ c: API.Card) {
        if revealed != nil { revealed = nil } else { act { revealed = try await model.api.reveal(c.id) } }
    }

    // MARK: Вибрана картка

    private func details(_ c: API.Card) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                RoundAction(title: revealed == nil ? "Реквізити" : "Сховати", symbol: revealed == nil ? "eye" : "eye.slash") {
                    toggleReveal(c)
                }
                RoundAction(title: c.isBlocked ? "Розморозити" : "Заморозити", symbol: c.isBlocked ? "sun.max" : "snowflake",
                            on: c.isBlocked) {
                    act { try await model.api.toggleCardBlock(c.id) }
                }
                RoundAction(title: "Вигляд", symbol: "paintpalette") { revealed = nil; designing = c }
                NavigationLink { SecurityView() } label: { RoundActionLabel(title: "PIN", symbol: "lock") }
                    .buttonStyle(PressScale())
            }
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(c.isPrimary ? "Баланс рахунку" : "Баланс картки").caption()
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
                    if c.isPrimary {
                        // головна картка не має окремих грошей - вона платить з рахунку
                        Text("Головна картка списує з основного рахунку.").font(.footnote).foregroundStyle(.secondary)
                    }
                    if let monthOut {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("За місяць витрачено").font(.footnote).foregroundStyle(.secondary)
                            Spacer()
                            BigAmount(value: monthOut, size: 17)
                        }
                    }
                    Button { topping = c } label: {
                        Label("Поповнити картку", systemImage: "plus")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Theme.ink, in: .capsule)
                            .foregroundStyle(Theme.onInk)
                    }
                    .buttonStyle(PressScale())
                }
                .padding(16)
            }
            Surface {
                VStack(alignment: .leading, spacing: 0) {
                    row(copied ? "Номер рахунку скопійовано" : "Скопіювати номер рахунку",
                        symbol: copied ? "checkmark.circle.fill" : "doc.on.doc") { copyAccount() }
                    if !c.isPrimary {
                        Rule()
                        row("Зробити головною", symbol: "star") { act { try await model.api.setPrimary(c.id) } }
                    }
                    Rule()
                    row("Закрити картку", symbol: "xmark.circle", destructive: true) { confirmClose = true }
                }
            }
            .sensoryFeedback(.success, trigger: copied) { _, v in v }
        }
        .disabled(screen.busy)
    }

    private func copyAccount() {
        guard let n = account?.accountNumber else { return }
        UIPasteboard.general.string = n
        withAnimation(.snappy) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { copied = false }
        }
    }

    private func row(_ title: String, symbol: String, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22).contentTransition(.symbolEffect(.replace))
                Text(title).contentTransition(.opacity)
                Spacer()
                if !destructive { Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary) }
            }
            .foregroundStyle(destructive ? Color.red : Theme.ink)
            .padding(16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Кругла скляна дія під карткою, як у гаманці.
struct RoundAction: View {
    let title: String
    let symbol: String
    var on = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { RoundActionLabel(title: title, symbol: symbol, on: on) }
            .buttonStyle(PressScale())
            .sensoryFeedback(.impact(weight: .light), trigger: on)
    }
}

struct RoundActionLabel: View {
    let title: String
    let symbol: String
    var on = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .frame(width: 58, height: 58)
                .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                .background(on ? Theme.accent : Theme.surface, in: .circle)
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: on ? 0 : Theme.hairline))
            Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(Theme.ink)
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
