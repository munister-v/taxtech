import CryptoKit
import SwiftUI

/// Дослід: доказ роботи. Шукаємо nonce, щоб відбиток SHA-256 починався з нулів.
/// Пошук - перебір, перевірка - один хеш. Під час пошуку видно справжні відбитки справжніх nonce.
struct WorkLab: View {
    private struct Found: Sendable {
        let nonce: Int
        let attempts: Int
        let ms: Int
        let zeros: Int
    }

    /// Спільний лічильник між потоком пошуку й екраном: екран читає поточний nonce щокадру.
    private nonisolated final class Live: @unchecked Sendable {
        private let lock = NSLock()
        private var n = 0
        private var halt = false
        var nonce: Int { lock.lock(); defer { lock.unlock() }; return n }
        var stopped: Bool { lock.lock(); defer { lock.unlock() }; return halt }
        func set(_ v: Int) { lock.lock(); n = v; lock.unlock() }
        func stop() { lock.lock(); halt = true; lock.unlock() }
    }

    private enum Stage {
        case idle
        case mining(Live)
        /// Пошук закінчився: екран за пів-хвилини проганяє ті самі nonce від нуля до знайденого.
        case replay(start: Date, duration: Double, nonce: Int)
        case locked(Date)
    }

    @State private var data = "Переказ 100 TAX"
    @State private var zeros = 3.0
    @State private var found: Found?
    @State private var stage = Stage.idle

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

    private static func hex(_ h: [UInt8]) -> [Character] { Array(h.map { String(format: "%02x", $0) }.joined()) }

    private var searching: Bool {
        if case .idle = stage { return false }
        return true
    }

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

    // MARK: Результат і живий пошук

    private func shownNonce(_ now: Date) -> Int {
        switch stage {
        case .idle: return found?.nonce ?? 0
        case .mining(let live): return live.nonce
        case .replay(let start, let duration, let nonce):
            let t = min(max(now.timeIntervalSince(start) / duration, 0), 1)
            return Int(Double(nonce) * pow(t, 2.2))
        case .locked: return found?.nonce ?? 0
        }
    }

    private var result: some View {
        let finished = !searching || { if case .locked = stage { return true } else { return false } }()
        return LabHero(ok: found == nil || valid || !finished) {
            HeroCaption(heroCaption)
            TimelineView(.animation(paused: !searching)) { tl in
                miner(tl.date)
            }
            .padding(.top, 8)
            if let found, finished {
                HStack(spacing: 22) {
                    Stat(value: found.attempts.formatted(), label: L("Спроб пошуку").s)
                    Stat(value: L("\(found.ms) мс").s, label: L("Час пошуку").s)
                    Stat(value: "1", label: L("Хешів на перевірку").s)
                }
                .padding(.top, 14)
            }
        }
    }

    private var heroCaption: String {
        if searching, !{ if case .locked = stage { return true } else { return false } }() { return L("Шукаємо…").s }
        if found == nil { return L("Блок").s }
        return valid ? L("Доказ роботи є").s : L("Дані змінено, доказ втрачено").s
    }

    @ViewBuilder private func miner(_ now: Date) -> some View {
        let target = found.map { searching ? Int(zeros) : $0.zeros } ?? Int(zeros)
        let nonce = shownNonce(now)
        let digest = Self.digest(data, nonce)
        let z = Self.leadingZeros(digest)
        let idleEmpty = found == nil && !searching
        let lockAge: Double = { if case .locked(let d) = stage { return now.timeIntervalSince(d) } else { return 9 } }()
        VStack(alignment: .leading, spacing: 10) {
            Text(idleEmpty ? L("Nonce ще не знайдено").s : "nonce \(nonce.formatted(.number.grouping(.never)))")
                .font(idleEmpty ? .display(26, .medium) : .system(size: 30, weight: .medium)).tracking(-0.4)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            pips(target: target, lit: idleEmpty ? 0 : z, flash: lockAge < 0.6)
            hashRows(digest, target: target, lit: !idleEmpty, glow: lockAge < 1.0)
                .opacity(idleEmpty ? 0.35 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if lockAge < 1.0 {
                Circle().stroke(Theme.accent.opacity(1 - lockAge), lineWidth: 2)
                    .scaleEffect(0.3 + 2.2 * lockAge).frame(width: 140, height: 140)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Слоти під потрібні нулі: засвічуються, коли поточний відбиток має стільки нулів на початку.
    private func pips(target: Int, lit: Int, flash: Bool) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<max(target, 1), id: \.self) { i in
                Capsule()
                    .fill(i < lit ? Theme.accent : Theme.ink.opacity(0.10))
                    .frame(height: 6)
                    .shadow(color: Theme.accent.opacity(i < lit && flash ? 0.9 : 0), radius: 6)
            }
        }
    }

    private func hashRows(_ h: [UInt8], target: Int, lit: Bool, glow: Bool) -> some View {
        let chars = Self.hex(h)
        let z = Self.leadingZeros(h)
        func row(_ r: Range<Int>) -> Text {
            r.reduce(Text("")) { acc, i in
                let c: Color = lit && i < z ? Theme.accent : (lit && i < target ? Theme.ink : Color.secondary)
                return acc + Text(String(chars[i])).foregroundStyle(c)
            }
        }
        return VStack(alignment: .leading, spacing: 2) {
            row(0..<32)
            row(32..<64)
        }
        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
        .shadow(color: Theme.accent.opacity(glow ? 0.6 : 0), radius: 8)
    }

    // MARK: Керування

    private var controls: some View {
        LabPanel(title: L("Блок").s) {
            HStack {
                Text(L("Дані").s).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 12)
                TextField(L("Дані блока").s, text: $data).multilineTextAlignment(.trailing).font(.subheadline.weight(.medium))
                    .disabled(searching)
            }
            LabSlider(title: L("Нулів на початку").s, value: "\(Int(zeros))",
                      x: Binding(get: { zeros }, set: { zeros = $0.rounded() }), range: 1...6)
            if case .mining(let live) = stage {
                Button(L("Зупинити").s) { live.stop() }.buttonStyle(LineButton())
            } else {
                Button(searching ? L("Шукаємо…").s : L("Знайти nonce").s) { search() }
                    .buttonStyle(InkButton()).disabled(searching)
            }
        }
    }

    private var cost: some View {
        LabPanel(title: L("Ціна пошуку").s) {
            ForEach(1...6, id: \.self) { d in
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
        let live = Live()
        found = nil
        stage = .mining(live)
        Task {
            let r = await Task.detached(priority: .userInitiated) { () -> Found? in
                let t0 = ContinuousClock.now
                var nonce = 0
                while Self.leadingZeros(Self.digest(text, nonce)) < target {
                    nonce += 1
                    if nonce & 0x3FF == 0 {
                        live.set(nonce)
                        if live.stopped { return nil }
                    }
                }
                let ms = Int((ContinuousClock.now - t0) / .milliseconds(1))
                return Found(nonce: nonce, attempts: nonce + 1, ms: ms, zeros: target)
            }.value
            guard let r else { stage = .idle; return }
            // швидкий пошук програємо повільніше, щоб його було видно; довгий лише коротко доганяємо до знайденого
            let duration = r.ms < 1500 ? 2.0 : 0.5
            stage = .replay(start: Date(), duration: duration, nonce: r.nonce)
            try? await Task.sleep(for: .seconds(duration))
            found = r
            stage = .locked(Date())
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            try? await Task.sleep(for: .seconds(1.1))
            stage = .idle
        }
    }
}
