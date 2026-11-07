import SwiftUI

enum PosFormat {
    /// «2026-11-09» в короткий день місяця за мовою застосунку.
    static func day(_ iso: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: iso) else { return iso }
        return d.formatted(.dateTime.day().month(.abbreviated).locale(Lang.current.locale))
    }

    static func percent(_ v: Double) -> String {
        v.formatted(.percent.precision(.fractionLength(0...1)).locale(Lang.current.locale))
    }
}

/// Розбір платежу для експертного режиму: комісія MDR, клірінг і виплата, повідомлення ISO 8583.
struct PosBreakdown: View {
    let payment: API.PosPayment

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let s = payment.settlement { settlement(s) }
            if let iso = payment.iso, !iso.isEmpty { isoMessage(iso) }
            Card {
                LearnLink(.network).padding(.horizontal, 18).padding(.vertical, 6)
                Rule().padding(.leading, 18)
                LearnLink(.hold).padding(.horizontal, 18).padding(.vertical, 6)
            }
        }
        .padding(.bottom, 8)
    }

    private func settlement(_ s: API.PosSettlement) -> some View {
        let refunded = payment.isRefunded
        let steps: [(String, String, Bool)] = [
            (L("Авторизація").s, "\(payment.latencyMs ?? 0) ms · \(payment.responseCode)", true),
            (L("Списання").s, PosFormat.day(s.clearingDate), true),
            (L("Клірінг").s, PosFormat.day(s.clearingDate), true),
            (L("Виплата магазину").s, refunded ? L("Повернено").s : PosFormat.day(s.payoutDate), s.paidOut && !refunded),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Клірінг і розрахунок").s).caption()
            Card {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 14) {
                        Image(systemName: step.2 ? "checkmark" : "clock")
                            .font(.system(size: 12, weight: .bold)).frame(width: 28, height: 28)
                            .foregroundStyle(step.2 ? Theme.accent : Color.secondary)
                            .background((step.2 ? Theme.accent : Color.secondary).opacity(0.14), in: .circle)
                        Text(step.0).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(step.1).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    if i < steps.count - 1 { Rule().padding(.leading, 60) }
                }
            }
            Card {
                row(L("Оборот").s, Format.short(s.gross))
                Rule().padding(.leading, 18)
                row("MDR \(PosFormat.percent(s.mdr))", "−" + Format.short(s.fee))
                Rule().padding(.leading, 18)
                row(L("Магазин отримає").s, Format.short(s.net))
            }
        }
    }

    private func isoMessage(_ fields: [API.PosIso]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ISO 8583").caption()
            Card {
                ForEach(Array(fields.enumerated()), id: \.element.id) { i, f in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(f.field).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.accent)
                            .frame(width: 46, alignment: .leading)
                        Text(f.name).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(f.value).font(.system(size: 13, weight: .medium, design: .monospaced)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    if i < fields.count - 1 { Rule().padding(.leading, 18) }
                }
            }
        }
    }

    private func row(_ t: String, _ v: String) -> some View {
        HStack { Text(t).foregroundStyle(.secondary); Spacer(); Text(v).monospacedDigit().lineLimit(1) }
            .font(.subheadline).padding(.horizontal, 18).padding(.vertical, 13)
    }
}

/// Кабінет учбового магазину: оборот, комісії еквайра, графік виплат і розбивка за точками.
struct PosMerchantView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var summary: API.PosMerchantSummary?
    @State private var loaded = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            AuroraField().frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea().opacity(0.6)
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 40).glassCircle()
                    }
                    .buttonStyle(PressScale())
                    Spacer()
                    Text(L("Магазин").s).font(.headline)
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.top, 8)
                content
            }
            .padding(.horizontal, Theme.gutter)
        }
        .task { summary = try? await model.api.posMerchant(); loaded = true }
    }

    @ViewBuilder private var content: some View {
        if let s = summary, s.totals.count + s.totals.declined > 0 || s.totals.refunded > 0 {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero(s.totals)
                    stats(s.totals)
                    if !s.payouts.isEmpty { payouts(s.payouts) }
                    if !s.merchants.isEmpty { shops(s.merchants) }
                    if model.expert {
                        Card {
                            LearnLink(.ledger).padding(.horizontal, 18).padding(.vertical, 6)
                            Rule().padding(.leading, 18)
                            LearnLink(.network).padding(.horizontal, 18).padding(.vertical, 6)
                        }
                    }
                }
                .padding(.top, 18).padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        } else {
            VStack { Spacer(); if loaded { Text(L("Платежів поки немає").s).foregroundStyle(.secondary) } else { ProgressView().tint(Theme.accent) }; Spacer() }
                .frame(maxWidth: .infinity)
        }
    }

    private func hero(_ t: API.PosMerchantSummary.Totals) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L("Чистий оборот").s).caption()
            Text(Format.short(t.net)).font(.system(size: 52, weight: .semibold)).tracking(-1.5).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.5).contentTransition(.numericText())
            if model.expert {
                Text("MDR \(PosFormat.percent(t.mdr)) · T+1").font(.footnote.monospaced()).foregroundStyle(Theme.accent)
            }
        }
    }

    private func stats(_ t: API.PosMerchantSummary.Totals) -> some View {
        Card {
            HStack {
                stat(L("Оборот").s, Format.short(t.gross))
                stat(L("Комісія").s, Format.short(t.fee))
                stat(L("Платежів").s, "\(t.count)")
            }
            .padding(18)
            Rule().padding(.leading, 18)
            HStack {
                stat(L("Схвалено").s, PosFormat.percent(t.approvalRate))
                stat(L("Повернення").s, Format.short(t.refunded))
                stat(L("Відмов").s, "\(t.declined)")
            }
            .padding(18)
            if (t.holds ?? 0) > 0 || (t.disputes ?? 0) > 0 || (t.chargebacks ?? 0) > 0 {
                Rule().padding(.leading, 18)
                HStack {
                    stat(L("Утримання").s, Format.short(t.holds ?? 0))
                    stat(L("Спорів").s, "\(t.disputes ?? 0)")
                    stat(L("Чарджбеків").s, "\(t.chargebacks ?? 0)")
                }
                .padding(18)
            }
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 18, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(t).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func payouts(_ list: [API.PosMerchantSummary.Payout]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L("Виплати").s).caption()
            Card {
                ForEach(Array(list.prefix(8).enumerated()), id: \.element.id) { i, p in
                    HStack(spacing: 14) {
                        Image(systemName: p.paidOut ? "checkmark" : "clock")
                            .font(.system(size: 12, weight: .bold)).frame(width: 28, height: 28)
                            .foregroundStyle(p.paidOut ? Theme.accent : Color.secondary)
                            .background((p.paidOut ? Theme.accent : Color.secondary).opacity(0.14), in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PosFormat.day(p.date)).font(.body.weight(.medium))
                            Text(p.paidOut ? L("Виплачено").s : L("Заплановано").s).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Format.short(p.net)).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                    }
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    if i < min(list.count, 8) - 1 { Rule().padding(.leading, 60) }
                }
            }
        }
    }

    private func shops(_ list: [API.PosMerchantSummary.Shop]) -> some View {
        let top = list.map(\.gross).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            Text(L("Магазини").s).caption()
            Card {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, m in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(m.merchant).font(.body.weight(.medium)).lineLimit(1)
                            Spacer()
                            Text(Format.short(m.gross)).font(.system(size: 16, weight: .semibold)).monospacedDigit()
                        }
                        GeometryReader { g in
                            Capsule().fill(Theme.accent.opacity(0.85)).frame(width: max(6, g.size.width * m.gross / max(top, 1)))
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 13)
                    if i < list.count - 1 { Rule().padding(.leading, 18) }
                }
            }
        }
    }
}
