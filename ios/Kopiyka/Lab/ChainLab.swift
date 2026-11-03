import CryptoKit
import SwiftUI

/// Дослід 3: хеш-ланцюг переказів, як `integrity_service.py` на сервері. Запис можна змінити
/// й побачити, де розривається ланцюг, а потім перерахувати хеші й побачити, що видає підміну.
struct ChainLab: View {
    struct Block: Identifiable, Equatable {
        let id: Int
        var note: String
        var amount: Double
        var hash: String
    }

    private static let zero = String(repeating: "0", count: 64)

    @Environment(AppModel.self) private var model
    @State private var mine = false
    @State private var rows = ChainLab.sample()
    @State private var blocks: [Block] = ChainLab.seed()
    /// Останній відбиток, який «записано окремо» - наприклад, у квитанції чи в іншому сховищі.
    @State private var anchor = ChainLab.seed().last?.hash ?? ChainLab.zero

    // MARK: Хеш

    static func digest(_ index: Int, _ note: String, _ amount: Double, prev: String) -> String {
        SHA256.hash(data: Data("\(index)|\(note)|\(amount.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))))|\(prev)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    static func sample() -> [(String, Double)] {
        [(L("Поповнення").s, 1_000), (L("Кава").s, 85), (L("Переказ Ірині").s, 250), (L("Метро").s, 40), (L("Книжки").s, 420)]
    }

    static func seed() -> [Block] { build(sample()) }

    static func build(_ rows: [(String, Double)]) -> [Block] {
        var prev = zero
        return rows.enumerated().map { i, r in
            let h = digest(i + 1, r.0, r.1, prev: prev)
            prev = h
            return Block(id: i + 1, note: r.0, amount: r.1, hash: h)
        }
    }

    /// Перевірка рахує ланцюг наново: де кожна ланка не збігається із записаним відбитком
    /// і який відбиток виходить на кінці.
    private var verified: (broken: [Bool], head: String) {
        var prev = Self.zero
        let broken = blocks.map { b in
            let h = Self.digest(b.id, b.note, b.amount, prev: prev)
            prev = h
            return h != b.hash
        }
        return (broken, prev)
    }

    private var firstBroken: Int? { verified.broken.firstIndex(of: true) }
    /// Відбиток, порахований із поточних даних, проти записаного окремо.
    private var anchorMatches: Bool { verified.head == anchor }

    var body: some View {
        let bad = verified.broken
        VStack(alignment: .leading, spacing: 16) {
            status
            LabPanel(title: L("Записи").s) {
                if model.signedIn {
                    SegmentBar(items: [(false, L("Приклад").s), (true, L("Мої операції").s)], selection: $mine)
                }
                ForEach(blocks.indices, id: \.self) { i in
                    row(i, bad: bad[i])
                    if i < blocks.count - 1 { Rule() }
                }
            }
            LabPanel(title: L("Записаний окремо").s) {
                HStack {
                    Text(L("Останній відбиток при записі").s).font(.subheadline)
                    Spacer()
                    Text(short(anchor)).font(.system(.subheadline, design: .monospaced))
                }
                HStack {
                    Image(systemName: anchorMatches ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(anchorMatches ? Theme.accent : Theme.alert)
                    Text(anchorMatches ? L("Дані дають той самий відбиток").s : L("Інший відбиток: дані змінено").s)
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            actions
        }
        .animation(.snappy, value: bad)
        .animation(.snappy, value: anchorMatches)
        .onChange(of: mine) { _, on in
            Task {
                if on {
                    let ops = await LiveData.operations(model, limit: 5)
                    if !ops.isEmpty { rows = ops.map { ($0.title, $0.amount) } } else { mine = false; return }
                } else {
                    rows = Self.sample()
                }
                blocks = Self.build(rows)
                anchor = blocks.last?.hash ?? Self.zero
            }
        }
        #if DEBUG
        // simctl launch з SIMCTL_CHILD_KOPIYKA_CHAIN_TAMPER=1: другий запис уже змінено
        .onAppear { if ProcessInfo.processInfo.environment["KOPIYKA_CHAIN_TAMPER"] == "1" { blocks[1].amount = 8_500 } }
        #endif
    }

    private var status: some View {
        LabHero(ok: firstBroken == nil) {
            HeroCaption(L("Перевірка ланцюга").s)
            Text(firstBroken.map { L("Розрив із запису №\($0 + 1)").s } ?? L("Ланцюг цілий").s)
                .font(.display(30, .medium)).tracking(-0.6).padding(.top, 4)
        }
    }

    private func row(_ i: Int, bad: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("№\(blocks[i].id)").caption()
                TextField(L("Запис").s, text: $blocks[i].note).font(.subheadline.weight(.medium))
                TextField("0", value: $blocks[i].amount, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(.subheadline.weight(.semibold)).monospacedDigit().frame(width: 84)
            }
            HStack(spacing: 6) {
                Image(systemName: bad ? "link.badge.plus" : "link")
                    .foregroundStyle(bad ? Theme.alert : Theme.accent).font(.caption)
                Text(short(blocks[i].hash)).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(bad ? Theme.alert : Color.secondary)
                Text("←").foregroundStyle(.tertiary).font(.caption)
                Text(short(i == 0 ? Self.zero : blocks[i - 1].hash)).font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button(L("Перерахувати відбитки").s) {
                var prev = Self.zero
                for i in blocks.indices {
                    blocks[i].hash = Self.digest(blocks[i].id, blocks[i].note, blocks[i].amount, prev: prev)
                    prev = blocks[i].hash
                }
            }
            .buttonStyle(InkButton())
            .disabled(firstBroken == nil)
            HStack(spacing: 10) {
                // чесний запис можливий, лише поки дані дають записаний відбиток
                Button(L("Додати запис").s) { append() }.buttonStyle(LineButton())
                    .disabled(!anchorMatches)
                Button(L("Скинути").s) {
                    blocks = Self.build(rows)
                    anchor = blocks.last?.hash ?? Self.zero
                }
                .buttonStyle(LineButton())
            }
        }
    }

    /// Чесне додавання: нова ланка спирається на останній відбиток, і його записують окремо.
    private func append() {
        let prev = blocks.last?.hash ?? Self.zero
        let id = (blocks.last?.id ?? 0) + 1
        let amount = Double(Int.random(in: 20...900))
        let note = L("Покупка").s
        let h = Self.digest(id, note, amount, prev: prev)
        blocks.append(Block(id: id, note: note, amount: amount, hash: h))
        anchor = h
    }

    private func short(_ h: String) -> String { String(h.prefix(8)) }
}
