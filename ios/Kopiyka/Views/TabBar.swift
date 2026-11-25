import SwiftUI

// MARK: Нижня панель

/// Плаваюча скляна панель: вибрана вкладка розкривається золотою таблеткою з підписом, решта - самі значки.
/// Окремий круг праворуч - сканер QR, дія, якою користуються найчастіше.
struct FloatingTabBar: View {
    struct Item: Identifiable {
        let tab: RootView.AppTab
        let symbol: String
        var id: RootView.AppTab { tab }
    }

    let items: [Item]
    @Binding var selection: RootView.AppTab
    var onScan: (() -> Void)?
    @Namespace private var ns
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 0) {
                    ForEach(items) { item in tabButton(item) }
                }
                .padding(4)
                .glassEffect(.regular.tint(Theme.bg.opacity(0.55)), in: .capsule)
                if let onScan {
                    Button(action: onScan) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(Theme.ui(23, .medium))
                            .foregroundStyle(Theme.goldLight)
                            .frame(width: 54, height: 54)
                            .contentShape(.circle)
                    }
                    .buttonStyle(PressScale())
                    .glassEffect(.regular.tint(Theme.bg.opacity(0.55)).interactive(), in: .circle)
                    .accessibilityLabel(Tx("Сканувати QR", "Scan QR", "Сканировать QR"))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tabButton(_ item: Item) -> some View {
        let on = item.tab == selection
        return Button {
            guard !on else { return }
            withAnimation(reduce ? .easeOut(duration: 0.15) : .spring(response: 0.42, dampingFraction: 0.8)) { selection = item.tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.symbol)
                    .symbolVariant(on ? .fill : .none)
                    .font(Theme.ui(19, .semibold))
                    .frame(width: 24, height: 24)
                if on {
                    Text(item.tab.title)
                        .font(Theme.ui(13.5, .bold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity.combined(with: .scale(scale: 0.6, anchor: .leading)))
                }
            }
            .padding(.horizontal, on ? 13 : 10)
            .frame(height: 46)
            .foregroundStyle(on ? Theme.onAccent : Theme.ink.opacity(0.62))
            .background {
                if on {
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.goldLight, Theme.gold], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Theme.gold.opacity(0.45), radius: 10, y: 3)
                        .matchedGeometryEffect(id: "pill", in: ns)
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.tab.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Тінь під панеллю: прокручений вміст не впирається в неї різким краєм.
struct TabBarBackdrop: View {
    var body: some View {
        LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg.opacity(0.85)], startPoint: .top, endPoint: .bottom)
            .frame(height: 110)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }
}

/// Чи видно екранну клавіатуру: панель на цей час ховається.
struct KeyboardWatcher: ViewModifier {
    @Binding var shown: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in shown = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in shown = false }
    }
}

// MARK: Порядок карток

/// Порядок карток, який вибрав користувач. Без вибору - головна першою.
@MainActor @Observable
final class CardOrder {
    static let shared = CardOrder()
    private static let key = "cardOrder"

    private(set) var ids: [Int] = UserDefaults.standard.array(forKey: CardOrder.key) as? [Int] ?? []

    func set(_ new: [Int]) {
        ids = new
        UserDefaults.standard.set(new, forKey: Self.key)
    }

    func sorted(_ cards: [API.Card]) -> [API.Card] {
        guard !ids.isEmpty else { return cards.sorted { $0.isPrimary && !$1.isPrimary } }
        let rank = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        return cards.enumerated()
            .sorted { (rank[$0.element.id] ?? ids.count + $0.offset) < (rank[$1.element.id] ?? ids.count + $1.offset) }
            .map(\.element)
    }

    /// Кладе картку на `target` місце й запам'ятовує порядок усієї колоди.
    func move(_ id: Int, to target: Int, in cards: [API.Card]) {
        var list = cards.map(\.id)
        guard let from = list.firstIndex(of: id) else { return }
        list.remove(at: from)
        list.insert(id, at: min(max(target, 0), list.count))
        set(list)
    }
}

/// Лист «Порядок»: картки в рядок, тягни за ручку - порядок збережеться й на головній.
struct CardReorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cards: [API.Card]
    let onDone: ([API.Card]) -> Void

    init(cards: [API.Card], onDone: @escaping ([API.Card]) -> Void) {
        _cards = State(initialValue: cards)
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(cards) { c in
                    HStack(spacing: 14) {
                        VirtualCardView(number: c.maskedNumber, expiry: nil, holder: nil, look: c.look, frozen: c.isBlocked, compact: true)
                            .frame(width: 92)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(c.look.name.isEmpty ? L("Картка •• \(c.maskedNumber.suffix(4))").s : c.look.name)
                                .font(Theme.ui(style: .body, .semibold)).lineLimit(1)
                            Text(c.isBlocked ? L("Заморожена").s : (c.isPrimary ? L("Головна").s : "•• \(c.maskedNumber.suffix(4))"))
                                .font(Theme.ui(style: .footnote)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Rectangle().fill(Theme.surface.opacity(0.7)))
                    .listRowSeparatorTint(Theme.line)
                }
                .onMove { from, to in
                    withAnimation(.smooth) { cards.move(fromOffsets: from, toOffset: to) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .environment(\.editMode, .constant(.active))
            .sensoryFeedback(.impact(weight: .light), trigger: cards.map(\.id))
            .navigationTitle(L("Порядок карток").s)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("Готово").s) {
                        CardOrder.shared.set(cards.map(\.id))
                        onDone(cards)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
