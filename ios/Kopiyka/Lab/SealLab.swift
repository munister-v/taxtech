import CryptoKit
import SwiftUI

/// Дослід: код документа, як `make_code` у `document_service.py`: TT-XXXX-XXXX-XXXX з HMAC-SHA256.
/// Ключ лабораторний; на сервері його знає тільки сервер.
struct SealLab: View {
    @State private var kind = "receipt"
    @State private var ref = "tx-4021"
    @State private var owner = 7
    @State private var key = "lab-key"
    @State private var claimed = ""

    /// RFC 4648 base32 перших 12 символів: вони залежать лише від перших 60 бітів HMAC.
    static func code(kind: String, ref: String, owner: Int, key: String) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: Data("\(kind)|\(ref)|\(owner)".utf8), using: SymmetricKey(data: Data(key.utf8)))
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = UInt64(0)
        for b in mac.prefix(8) { bits = bits << 8 | UInt64(b) }
        // 64 біти -> 12 груп по 5 бітів зверху
        let raw = (0..<12).map { i in alphabet[Int((bits >> UInt64(59 - 5 * i)) & 31)] }
        let s = String(raw)
        return "TT-\(s.prefix(4))-\(s.dropFirst(4).prefix(4))-\(s.dropFirst(8))"
    }

    private var code: String { Self.code(kind: kind, ref: ref, owner: owner, key: key) }
    /// Той самий документ, але з іншим останнім символом посилання.
    private var neighbour: String { Self.code(kind: kind, ref: ref + "1", owner: owner, key: key) }
    private var valid: Bool { claimed.uppercased() == code }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            issued
            fields
            check
        }
        .onAppear { if claimed.isEmpty { claimed = code } }
        .animation(.snappy, value: valid)
    }

    private var issued: some View {
        HeroPanel(yellow: true) {
            HeroCaption(L("Код документа").s)
            Text(code).font(.system(size: 26, weight: .semibold, design: .monospaced)).minimumScaleFactor(0.6).lineLimit(1).padding(.top, 4)
            Text(L("З одним символом більше в посиланні: \(neighbour)").s)
                .font(.footnote).foregroundStyle(Theme.onAccent.opacity(0.75)).padding(.top, 6)
        }
    }

    private var fields: some View {
        LabPanel(title: L("Документ").s) {
            Picker(L("Вид").s, selection: $kind) {
                Text(L("Квитанція").s).tag("receipt")
                Text(L("Виписка").s).tag("statement")
            }
            .pickerStyle(.segmented)
            row(L("Посилання").s) { TextField("tx-4021", text: $ref).textInputAutocapitalization(.never).autocorrectionDisabled() }
            Rule()
            row(L("Власник").s) { Stepper("\(owner)", value: $owner, in: 1...99).monospacedDigit() }
            Rule()
            row(L("Ключ сервера").s) { TextField("lab-key", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled() }
        }
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            content().multilineTextAlignment(.trailing).font(.system(.subheadline, design: .monospaced)).frame(maxWidth: 190)
        }
    }

    private var check: some View {
        LabPanel(title: L("Перевірка коду").s) {
            TextField(L("Код з документа").s, text: $claimed)
                .font(.system(.body, design: .monospaced)).textInputAutocapitalization(.characters).autocorrectionDisabled()
            HStack {
                Image(systemName: valid ? "checkmark.seal.fill" : "xmark.seal.fill").foregroundStyle(valid ? Theme.accent : Color.red)
                Text(valid ? L("Код справжній").s : L("Код не збігається").s).font(.subheadline.weight(.medium))
            }
            HStack(spacing: 10) {
                Button(L("Підробити символ").s) { forge() }.buttonStyle(LineButton())
                Button(L("Правильний код").s) { claimed = code }.buttonStyle(LineButton())
            }
        }
    }

    /// Підміна одного символу в коді: підібрати правильний без ключа неможливо.
    private func forge() {
        var c = Array(claimed.isEmpty ? code : claimed)
        guard let i = c.lastIndex(where: { $0.isLetter || $0.isNumber }) else { return }
        c[i] = c[i] == "A" ? "B" : "A"
        claimed = String(c)
    }
}
