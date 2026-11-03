import CryptoKit
import SwiftUI

/// Дослід: доказ роботи. Шукаємо nonce, щоб відбиток SHA-256 починався з нулів.
/// Пошук - перебір, перевірка - один хеш.
struct WorkLab: View {
    private struct Found: Sendable {
        let nonce: Int
        let attempts: Int
        let ms: Int
        let zeros: Int
    }

    @State private var data = "Переказ 100 TAX"
    @State private var zeros = 3.0
    @State private var found: Found?
    @State private var searching = false

    nonisolated private static func digest(_ data: String, _ nonce: Int) -> [UInt8] {
        Array(SHA256.hash(data: Data("\(data)|\(nonce)".utf8)))
    }

    nonisolated private static func leadingZeros(_ h: [UInt8]) -> Int {
        var n = 0
        for b in h {
            if b >> 4 == 0 { n += 1 } else { break }
            if b & 0xF == 0 { n += 1 } else { break }
        }
        return n
    }

    private static func hex(_ h: [UInt8]) -> String { h.map { String(format: "%02x", $0) }.joined() }

    /// Поточний відбиток від поточних даних і знайденого nonce: якщо дані змінили, нулі зникають.
    private var current: [UInt8]? { found.map { Self.digest(data, $0.nonce) } }
    private var valid: Bool {
        guard let found, let current else { return false }
        return Self.leadingZeros(current) >= found.zeros
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            result
            controls
            cost
        }
        .animation(.snappy, value: found?.nonce)
    }

    private var result: some View {
        LabHero(ok: found == nil || valid) {
            HeroCaption(found == nil ? L("Блок").s : (valid ? L("Доказ роботи є").s : L("Дані змінено, доказ втрачено").s))
            if let found, let current {
                Text("nonce \(found.nonce)").font(.display(30, .medium)).tracking(-0.6).monospacedDigit().padding(.top, 4)
                hash(current, zeros: valid ? found.zeros : 0).padding(.top, 8)
                HStack(spacing: 22) {
                    Stat(value: found.attempts.formatted(), label: L("Спроб пошуку").s)
                    Stat(value: L("\(found.ms) мс").s, label: L("Час пошуку").s)
                    Stat(value: "1", label: L("Хешів на перевірку").s)
                }
                .padding(.top, 14)
            } else {
                Text(L("Nonce ще не знайдено").s).font(.display(26, .medium)).tracking(-0.4).padding(.top, 4)
            }
        }
    }

    private func hash(_ h: [UInt8], zeros: Int) -> some View {
        let s = Self.hex(h)
        let head = String(s.prefix(zeros))
        let tail = String(s.dropFirst(zeros).prefix(30 - zeros))
        return (Text(head).foregroundStyle(Theme.accent) + Text(tail).foregroundStyle(.secondary))
            .font(.system(.footnote, design: .monospaced))
    }

    private var controls: some View {
        LabPanel(title: L("Блок").s) {
            HStack {
                Text(L("Дані").s).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                TextField(L("Дані блока").s, text: $data).multilineTextAlignment(.trailing).font(.subheadline.weight(.medium))
            }
            LabSlider(title: L("Нулів на початку").s, value: "\(Int(zeros))",
                      x: Binding(get: { zeros }, set: { zeros = $0.rounded() }), range: 1...4)
            Button(searching ? L("Шукаємо…").s : L("Знайти nonce").s) { search() }
                .buttonStyle(InkButton()).disabled(searching)
        }
    }

    private var cost: some View {
        LabPanel(title: L("Ціна пошуку").s) {
            ForEach(1...4, id: \.self) { d in
                HStack {
                    Text(L("Нулів: \(d)").s).font(.subheadline).foregroundStyle(Int(zeros) == d ? Color.primary : Color.secondary)
                    Spacer()
                    Text(L("у середньому \(Int(pow(16.0, Double(d))).formatted()) спроб").s)
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Int(zeros) == d ? Theme.accent : Color.secondary)
                }
            }
            Text(L("Кожен новий нуль робить пошук у 16 разів довшим, а перевірка лишається одним хешем.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func search() {
        let text = data, target = Int(zeros)
        searching = true
        Task {
            let r = await Task.detached(priority: .userInitiated) { () -> Found in
                let t0 = ContinuousClock.now
                var nonce = 0
                while Self.leadingZeros(Self.digest(text, nonce)) < target { nonce += 1 }
                let ms = Int((ContinuousClock.now - t0) / .milliseconds(1))
                return Found(nonce: nonce, attempts: nonce + 1, ms: ms, zeros: target)
            }.value
            found = r
            searching = false
        }
    }
}
