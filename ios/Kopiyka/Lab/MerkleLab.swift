import CryptoKit
import SwiftUI

/// Дослід: дерево Меркла з чотирьох записів. Корінь підписує весь набір, а доказ для одного запису -
/// це лише сусідні відбитки на шляху до кореня.
struct MerkleLab: View {
    private struct Tree {
        let leaves: [String]
        let pair: [String]
        let root: String

        init(_ texts: [String]) {
            leaves = texts.map(MerkleLab.hash)
            pair = [MerkleLab.hash(leaves[0] + leaves[1]), MerkleLab.hash(leaves[2] + leaves[3])]
            root = MerkleLab.hash(pair[0] + pair[1])
        }
    }

    private static func initial() -> [String] {
        [L("Оплата 120").s, L("Переказ 40").s, L("Зарахування 500").s, L("Оплата 75").s]
    }

    /// Чотири найновіші операції рахунку: назва й сума записом дерева.
    private static func records(_ ops: [LiveOperation]) -> [String] {
        ops.map { "\($0.title) \($0.income ? "+" : "−")\(Format.short($0.amount))" }
    }

    nonisolated static func hash(_ s: String) -> String {
        SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func short(_ h: String) -> String { String(h.prefix(8)) }

    @Environment(AppModel.self) private var model
    @State private var mine = false
    @State private var base = MerkleLab.initial()
    @State private var texts = MerkleLab.initial()
    /// Дерево, корінь якого «записано окремо»: з нього беруться сусідні відбитки для доказу.
    @State private var anchor = Tree(MerkleLab.initial())
    @State private var selected = 0

    private var tree: Tree { Tree(texts) }

    /// Доказ: перераховуємо корінь від поточного тексту запису й двох сусідніх відбитків із записаного дерева.
    private var proofOK: Bool {
        let i = selected
        let leaf = Self.hash(texts[i])
        let sibling = anchor.leaves[i ^ 1]
        let level1 = i % 2 == 0 ? Self.hash(leaf + sibling) : Self.hash(sibling + leaf)
        let uncle = anchor.pair[(i / 2) ^ 1]
        let root = (i / 2) % 2 == 0 ? Self.hash(level1 + uncle) : Self.hash(uncle + level1)
        return root == anchor.root
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            rootPanel
            records
            levels
            proof
        }
        .animation(.snappy, value: tree.root)
    }

    private var rootPanel: some View {
        let same = tree.root == anchor.root
        return LabHero(ok: same) {
            HeroCaption(L("Корінь дерева").s)
            Text(Self.short(tree.root)).font(.system(size: 34, weight: .medium, design: .monospaced)).padding(.top, 4)
            Text(same ? L("Збігається із записаним").s : L("Змінився: записаний був \(Self.short(anchor.root))").s)
                .font(.subheadline).foregroundStyle(.secondary).padding(.top, 6)
        }
    }

    private var records: some View {
        LabPanel(title: L("Записи").s) {
            if model.signedIn {
                SegmentBar(items: [(false, L("Приклад").s), (true, L("Мої операції").s)], selection: $mine)
                    .onChange(of: mine) { _, on in
                        Task {
                            let ops = await LiveData.operations(model, limit: 4)
                            if on && ops.count == 4 { base = Self.records(ops) } else if on { mine = false; return } else { base = Self.initial() }
                            texts = base
                            anchor = Tree(base)
                        }
                    }
            }
            ForEach(0..<4, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        Text("№\(i + 1)").caption()
                        TextField(L("Запис").s, text: $texts[i]).font(.subheadline.weight(.medium))
                    }
                    Text(Self.short(tree.leaves[i]))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(tree.leaves[i] == anchor.leaves[i] ? Color.secondary : Theme.alert)
                }
                if i < 3 { Rule() }
            }
            HStack(spacing: 10) {
                Button(L("Записати корінь").s) { anchor = tree }.buttonStyle(LineButton())
                Button(L("Скинути").s) { texts = base; anchor = Tree(base) }.buttonStyle(LineButton())
            }
        }
    }

    private var levels: some View {
        LabPanel(title: L("Дерево").s) {
            level(L("Корінь").s, [tree.root], [anchor.root])
            level(L("Пари").s, tree.pair, anchor.pair)
            level(L("Листки").s, tree.leaves, anchor.leaves)
        }
    }

    private func level(_ title: String, _ now: [String], _ saved: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(now.indices, id: \.self) { i in
                    Text(Self.short(now[i]).prefix(6))
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background((now[i] == saved[i] ? Theme.ink.opacity(0.08) : Theme.alert.opacity(0.22)), in: .rect(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var proof: some View {
        LabPanel(title: L("Доказ для запису").s) {
            Picker(L("Запис").s, selection: $selected) {
                ForEach(0..<4, id: \.self) { Text("№\($0 + 1)").tag($0) }
            }
            .pickerStyle(.segmented)
            let i = selected
            row(L("Сусідній листок").s, Self.short(anchor.leaves[i ^ 1]))
            row(L("Сусідня пара").s, Self.short(anchor.pair[(i / 2) ^ 1]))
            HStack {
                Image(systemName: proofOK ? "checkmark.seal.fill" : "xmark.seal.fill").foregroundStyle(proofOK ? Theme.accent : Theme.alert)
                Text(proofOK ? L("Доказ вірний: корінь збігається").s : L("Доказ не проходить: запис змінено").s)
                    .font(.subheadline.weight(.medium))
            }
            Text(L("Для доказу потрібні лише два відбитки, а не весь набір.").s).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.subheadline, design: .monospaced))
        }
    }
}
