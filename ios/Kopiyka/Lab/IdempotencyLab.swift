import SwiftUI

/// Дослід: ключ ідемпотентності, як `idempotency_service.py`. Відповідь на оплату губиться, клієнт повторює запит.
/// З ключем сервер віддає збережену відповідь, без ключа списує вдруге.
struct IdempotencyLab: View {
    @State private var balance = 1_000.0
    @State private var charges = 0
    @State private var useKey = true
    @State private var loseFirst = true
    @State private var amount = 100.0
    @State private var key = IdempotencyLab.newKey()
    @State private var attempts = 0
    /// Таблиця сервера: ключ -> сума, з якою його вперше використали.
    @State private var store: [String: Double] = [:]
    @State private var clientSees: String?
    @State private var log: [String] = []

    private static func newKey() -> String { "k-" + String(UUID().uuidString.prefix(4)).lowercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            account
            controls
            client
            server
        }
        .animation(.snappy, value: log.count)
    }

    private var account: some View {
        HeroPanel(yellow: charges <= 1) {
            HeroCaption(L("Рахунок").s)
            Text(Format.short(balance)).font(Theme.balance(44)).monospacedDigit().padding(.top, 2)
            Text(L("Списань за цією оплатою: \(charges)").s).font(.subheadline).padding(.top, 4)
        }
    }

    private var controls: some View {
        LabPanel(title: L("Умови").s) {
            Toggle(L("Ключ ідемпотентності").s, isOn: $useKey).tint(Theme.accent)
            Toggle(L("Губити відповідь на першу спробу").s, isOn: $loseFirst).tint(Theme.accent)
            Picker(L("Сума").s, selection: $amount) {
                Text("100").tag(100.0)
                Text("250").tag(250.0)
            }
            .pickerStyle(.segmented)
            if useKey {
                HStack {
                    Text(L("Ключ").s).font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text(key).font(.system(.subheadline, design: .monospaced))
                }
            }
        }
    }

    private var client: some View {
        LabPanel(title: L("Клієнт").s) {
            if let clientSees {
                Text(clientSees).font(.headline)
            } else {
                Text(L("Ще нічого не надсилали").s).foregroundStyle(.secondary)
            }
            Button(L("Надіслати оплату").s) { send() }.buttonStyle(InkButton())
            Button(L("Нова оплата").s) { reset() }.buttonStyle(LineButton())
        }
    }

    private var server: some View {
        LabPanel(title: L("Журнал сервера").s) {
            if log.isEmpty { Text(L("Порожньо").s).foregroundStyle(.secondary) }
            ForEach(Array(log.enumerated().reversed()), id: \.offset) { i, line in
                Text("\(i + 1). \(line)").font(.footnote).foregroundStyle(i == log.count - 1 ? .primary : .secondary)
            }
        }
    }

    private func charge(_ a: Double) {
        balance -= a
        charges += 1
    }

    private func send() {
        attempts += 1
        if !useKey {
            charge(amount)
            log.append(L("без ключа: виконано, списано \(Format.short(amount))").s)
        } else if let first = store[key] {
            if first == amount {
                log.append(L("replay: ключ уже виконано, віддано збережену відповідь, списання немає").s)
            } else {
                log.append(L("conflict: ключ уже був з сумою \(Format.short(first)), запит відхилено").s)
            }
        } else {
            store[key] = amount
            charge(amount)
            log.append(L("new: ключ зарезервовано, виконано, списано \(Format.short(amount))").s)
        }
        let lost = loseFirst && attempts == 1
        clientSees = lost ? L("Тайм-аут: відповіді немає. Спробуйте ще раз.").s
                          : (log.last?.hasPrefix("conflict") == true ? L("Помилка: конфлікт ключа").s : L("Оплату підтверджено").s)
    }

    private func reset() {
        balance = 1_000
        charges = 0
        attempts = 0
        key = Self.newKey()
        store = [:]
        clientSees = nil
        log = []
    }
}
