import Network
import SwiftUI
import UIKit

// MARK: Мережа

/// Чи є зв'язок. Слухає систему, тож банер «без зв'язку» з'являється одразу, а не після першого збою запиту.
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    private(set) var online = true
    @ObservationIgnored private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { path in
            let ok = path.status == .satisfied
            Task { @MainActor in
                if NetworkMonitor.shared.online != ok { NetworkMonitor.shared.online = ok }
            }
        }
        monitor.start(queue: DispatchQueue(label: "net.monitor", qos: .utility))
    }

    func start() {}
}

/// Смужка над вмістом: немає зв'язку або сервер не відповів. Дані на екрані - збережені, і це сказано прямо.
struct ConnectionBanner: View {
    @Environment(AppModel.self) private var model

    private var text: String? {
        if !model.online { return Tx("Немає зв'язку. Показано збережене", "No connection. Showing saved data", "Нет связи. Показано сохранённое") }
        if model.serverTrouble { return Tx("Сервер не відповів", "The server did not respond", "Сервер не ответил") }
        return nil
    }

    var body: some View {
        if let text {
            HStack(spacing: 10) {
                Image(systemName: model.online ? "exclamationmark.triangle.fill" : "wifi.slash")
                    .foregroundStyle(model.online ? Theme.amber : Theme.alert)
                Text(text).font(Theme.ui(style: .footnote, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if model.online {
                    Button(Tx("Ще раз", "Retry", "Ещё раз")) { model.syncTick += 1 }
                        .font(Theme.ui(style: .footnote, .bold)).foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 14).frame(height: 40)
            .background(Theme.surface, in: .capsule)
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: Theme.hairline))
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: Завіса

/// Закриває екран, коли застосунок не активний (перемикач програм) або йде запис екрана: сума й картки не потрапляють у знімок.
struct PrivacyShield: View {
    let recording: Bool

    var body: some View {
        ZStack {
            Theme.bg
            VStack(spacing: 14) {
                Image(systemName: recording ? "record.circle" : "lock.fill")
                    .font(Theme.ui(34, .semibold)).foregroundStyle(Theme.accent)
                if recording {
                    Text(Tx("Іде запис екрана", "Screen recording is on", "Идёт запись экрана"))
                        .font(Theme.ui(style: .headline, .semibold))
                    Text(Tx("Суми й картки приховано", "Amounts and cards are hidden", "Суммы и карты скрыты"))
                        .font(Theme.ui(style: .footnote)).foregroundStyle(Theme.muted)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
    }
}

enum ScreenCapture {
    @MainActor static var isOn: Bool {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.contains { $0.screen.isCaptured }
    }
}

// MARK: Автоблокування

enum AutoLock {
    /// Через скільки секунд у фоні банк знову просить PIN. 0 - одразу.
    static var options: [(seconds: Int, title: String)] { [
        (0, Tx("Одразу", "Immediately", "Сразу")),
        (60, Tx("Через 1 хв", "After 1 min", "Через 1 мин")),
        (300, Tx("Через 5 хв", "After 5 min", "Через 5 мин")),
    ] }
}

// MARK: Перевірка введеного

enum RecipientCheck {
    enum Result { case empty, ok, bad }

    /// Рахунок виду KP-100003 / MRC-…; картка - 16 цифр. Контрольну суму Луна не перевіряємо: навчальні картки її свідомо не проходять.
    static func check(_ raw: String, byCard: Bool) -> Result {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return .empty }
        if byCard {
            let digits = s.filter(\.isNumber)
            return digits.count == 16 && digits.count == s.filter { !$0.isWhitespace }.count ? .ok : .bad
        }
        return s.range(of: #"^[A-Za-z]{2,4}-[A-Za-z0-9-]{3,}$"#, options: .regularExpression) != nil ? .ok : .bad
    }
}

// MARK: Для VoiceOver

extension API.Transaction {
    /// «Мінус 120,40 TAX» повністю, а не «мінус, 120, кома, 40».
    var spokenAmount: String {
        (isIncome ? Tx("плюс", "plus", "плюс") : Tx("мінус", "minus", "минус")) + " " + Format.money(amount)
    }
}

// MARK: Виписка

enum StatementCSV {
    /// Виписка файлом: дата, вид, кому/від кого, сума зі знаком, нотатка. Номер операції - для звірки з квитанцією.
    static func file(for items: [API.Transaction]) -> URL? {
        func esc(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let iso = ISO8601DateFormatter()
        var out = "id,date,type,counterparty,amount,note\n"
        for t in items {
            let signed = (t.isIncome ? "" : "-") + String(format: "%.2f", t.amount)
            out += [String(t.id), iso.string(from: t.date), esc(BankText.type(t.txType)), esc(t.relatedAccount ?? ""), signed, esc(t.note ?? "")]
                .joined(separator: ",") + "\n"
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "taxtech-statement.csv")
        do { try out.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }
}
