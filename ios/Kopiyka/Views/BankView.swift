import SwiftUI

@MainActor @Observable
final class BankModel {
    var account: API.Account?
    var cards: [API.Card] = []
    var history: [API.Transaction] = []
    var deposits: [API.Deposit] = []
    var credits: [API.Credit] = []
    var goals: [API.Goal] = []
    var error: String?
    var loaded = false

    func load(_ api: API) async {
        do {
            async let a = api.account()
            async let c = api.cards()
            async let h = api.history()
            (account, cards, history) = try await (a, c, h)
            cards = cards.filter { !$0.isClosed }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        deposits = ((try? await api.deposits()) ?? []).filter(\.isActive)
        credits = ((try? await api.credits()) ?? []).filter(\.isActive)
        goals = (try? await api.goals()) ?? []
        loaded = true
    }

    var primaryCard: API.Card? { cards.first { $0.isPrimary } ?? cards.first }

    /// Історія по днях, найновіші першими.
    var days: [(day: Date, items: [API.Transaction])] {
        Dictionary(grouping: history) { Calendar.current.startOfDay(for: $0.date) }
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }
}

struct TransactionRow: View {
    let tx: API.Transaction

    var body: some View {
        AmountRow(title: title,
                  subtitle: "\(kind), \(tx.date.formatted(date: .omitted, time: .shortened))",
                  amount: (tx.isIncome ? "+" : "−") + Format.money(tx.amount), positive: tx.isIncome)
    }

    /// «(віртуальна покупка)» сервер дописує до кожної покупки - тут це зайве, екран і так про віртуальні гроші.
    var title: String {
        let d = tx.description ?? tx.relatedAccount ?? "Операція"
        return d.replacingOccurrences(of: " (віртуальна покупка)", with: "")
    }

    var kind: String {
        switch tx.txType {
        case "payment": "Покупка"
        case "topup": "Поповнення"
        case "transfer":
            tx.isIncome ? "Переказ від \(tx.relatedAccount ?? "")" : "Переказ на \(tx.relatedAccount ?? "")"
        default: tx.isIncome ? "Надходження" : "Списання"
        }
    }
}

/// Конструктор картки: матеріал, колір, візерунок, емблема й назва, живе превʼю з нахилом.
struct CardDesignPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let card: API.Card
    let changed: () async -> Void
    @State private var look = CardLook()
    @State private var screen = Screen()
    @State private var spin = 0.0
    @FocusState private var naming: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VirtualCardView(number: card.maskedNumber, expiry: card.expiryDisplay,
                                    holder: card.holderName, look: look)
                        .tilt()
                        .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                        .padding(.horizontal, 8)
                        .animation(.smooth(duration: 0.35), value: look)
                    nameField
                    section("Матеріал") {
                        HStack(spacing: 8) {
                            ForEach(CardMaterial.allCases) { m in
                                chip(m.title, symbol: m.symbol, on: look.material == m) { look.material = m }
                            }
                        }
                    }
                    section("Колір · \(look.color.title)") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                            ForEach(CardColor.allCases) { c in
                                Button { look.color = c } label: {
                                    Circle()
                                        .fill(LinearGradient(colors: [c.partner, c.base], startPoint: .topTrailing, endPoint: .bottomLeading))
                                        .frame(width: 46, height: 46)
                                        .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                                        .padding(4)
                                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: look.color == c ? 2 : 0))
                                        .accessibilityLabel(c.title)
                                }
                                .buttonStyle(PressScale())
                            }
                        }
                    }
                    section("Візерунок") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(CardPattern.allCases) { p in
                                    Button { look.pattern = p } label: {
                                        VStack(spacing: 6) {
                                            CardSurface(look: CardLook(material: look.material, color: look.color, pattern: p), corner: 9)
                                                .aspectRatio(1.586, contentMode: .fit)
                                                .frame(width: 104)
                                                .padding(3)
                                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .strokeBorder(Theme.ink, lineWidth: look.pattern == p ? 2 : 0))
                                            Text(p.title).font(.caption.weight(look.pattern == p ? .semibold : .regular))
                                                .foregroundStyle(look.pattern == p ? .primary : .secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Theme.gutter)
                        }
                        .padding(.horizontal, -Theme.gutter)
                    }
                    section("Емблема") {
                        HStack(spacing: 8) {
                            ForEach(CardEmblem.allCases) { e in
                                chip(e.title, symbol: nil, on: look.emblem == e) { look.emblem = e }
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { spin += 360 }
                            look = CardLook.random().with(name: look.name)
                        } label: { Label("Навмання", systemImage: "dice") }
                        .buttonStyle(LineButton())
                        Button("Як було") { look = card.look }
                            .buttonStyle(LineButton())
                    }
                    if let e = screen.error {
                        Label(e, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Вигляд картки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Скасувати") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Зберегти") {
                        Task {
                            // помилка лишає екран відкритим і видна під формою
                            if await screen.run({ try await model.api.setCardStyle(card.id, look) }) {
                                await changed()
                                dismiss()
                            }
                        }
                    }
                    .disabled(screen.busy || look == card.look && card.style != nil)
                }
            }
            .onAppear { look = card.look }
            .sensoryFeedback(.selection, trigger: look)
            .sensoryFeedback(.error, trigger: screen.error)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Назва на картці").caption()
            HStack {
                TextField(Brand.name, text: $look.name)
                    .focused($naming)
                    .submitLabel(.done)
                    .onChange(of: look.name) { _, v in
                        if v.count > CardLook.nameLimit { look.name = String(v.prefix(CardLook.nameLimit)) }
                    }
                Text("\(look.name.count)/\(CardLook.nameLimit)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.surface, in: .rect(cornerRadius: 14, style: .continuous))
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).caption().contentTransition(.opacity)
            content()
        }
    }

    private func chip(_ title: String, symbol: String?, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.caption) }
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .padding(.horizontal, 4)
            .background(on ? Theme.ink : Theme.surface, in: .capsule)
            .foregroundStyle(on ? Theme.onInk : Theme.ink)
        }
        .buttonStyle(PressScale())
        .animation(.snappy, value: on)
    }
}

extension CardLook {
    func with(name: String) -> CardLook { var c = self; c.name = name; return c }
}
