import SwiftUI

/// Дослід: мережа з трьох банків. Потік переказів між людьми, автоплатежі, міжбанківський кліринг,
/// антифрод і бани. Усе рахується на телефоні, кожен крок видно в стрічці.
struct NetworkLab: View {
    @State private var sim = NetSim()
    @State private var params = NetSim.Params()
    @State private var running = false
    @State private var live: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.environment["KOPIYKA_NET_LIVE"] == "1"
        #else
        return false
        #endif
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SegmentBar(items: [(false, L("Модель").s), (true, L("Живий режим").s)], selection: $live)
            if live { LiveNetworkLab() } else { simulation }
        }
        .onChange(of: live) { _, on in if on { running = false } }
    }

    private var simulation: some View {
        VStack(alignment: .leading, spacing: 16) {
            status
            controls
            schemes
            banks
            clearing
            quality
            feed
        }
        .animation(.snappy, value: sim.tick)
        .task(id: running) {
            while running && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(700))
                if Task.isCancelled { break }
                sim.step(params)
            }
        }
        #if DEBUG
        // simctl launch з SIMCTL_CHILD_KOPIYKA_NET_STEPS=40: симуляція вже пройшла 40 кроків
        .onAppear {
            if let n = ProcessInfo.processInfo.environment["KOPIYKA_NET_STEPS"].flatMap(Int.init) {
                for _ in 0..<n { sim.step(params) }
            }
        }
        #endif
    }

    // MARK: Стан

    private var status: some View {
        let intact = abs(sim.money - sim.expectedMoney) < 0.01
        return LabHero(ok: intact) {
            HeroCaption(running ? L("Мережа працює").s : L("Мережа стоїть").s)
            Text(L("Крок \(sim.tick)").s).font(.display(30, .medium)).tracking(-0.6).monospacedDigit().padding(.top, 4)
            HStack(spacing: 22) {
                Stat(value: "\(sim.total)", label: L("Переказів").s)
                Stat(value: "\(sim.caught + sim.falseBlocks)", label: L("Зупинено").s)
                Stat(value: "\(sim.bannedCount)", label: L("Банів").s)
            }
            .padding(.top, 14)
            HStack(spacing: 8) {
                Image(systemName: intact ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(intact ? Theme.accent : Theme.alert)
                Text(intact ? L("Сума мережі не змінилась: \(Format.short(sim.money))").s : L("Сума мережі розійшлась").s)
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.top, 12)
        }
    }

    private var controls: some View {
        LabPanel(title: L("Потік").s) {
            HStack(spacing: 10) {
                Button(running ? L("Пауза").s : L("Запустити").s) { running.toggle() }.buttonStyle(InkButton())
                Button(L("Крок").s) { sim.step(params) }.buttonStyle(LineButton()).disabled(running)
                Button(L("Скинути").s) { running = false; sim = NetSim() }.buttonStyle(LineButton())
            }
            LabSlider(title: L("Переказів за крок").s, value: "\(Int(params.intensity))",
                      x: Binding(get: { params.intensity }, set: { params.intensity = $0.rounded() }), range: 1...6)
            LabSlider(title: L("Частка шахрайства").s, value: "\(Int(params.fraudShare * 100))%",
                      x: Binding(get: { params.fraudShare }, set: { params.fraudShare = ($0 * 20).rounded() / 20 }), range: 0...0.5)
            LabSlider(title: L("Поріг блокування").s, value: "\(Int(params.threshold))",
                      x: Binding(get: { params.threshold }, set: { params.threshold = ($0 / 5).rounded() * 5 }), range: 30...95)
            Toggle(L("Шар історії").s, isOn: $params.history).tint(Theme.accent)
            Toggle(L("Автоплатежі").s, isOn: $params.autopay).tint(Theme.accent)
        }
    }

    // MARK: Схеми

    private var schemes: some View {
        LabPanel(title: L("Схеми шахрайства").s) {
            ForEach(NetSim.Scheme.allCases, id: \.self) { s in
                let on = params.schemes.contains(s)
                let r = sim.results[s] ?? NetSim.Outcome()
                Button {
                    if on { params.schemes.remove(s) } else { params.schemes.insert(s) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.accent : Color.secondary)
                            Text(s.title).font(.subheadline.weight(.medium)).foregroundStyle(on ? Color.primary : Color.secondary)
                            Spacer(minLength: 8)
                            Text(r.total == 0 ? "-" : L("зупинено \(r.caught) з \(r.total)").s)
                                .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                        }
                        GeometryReader { g in
                            Rectangle().fill(Theme.ink.opacity(0.1))
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(r.missed > 0 && r.caught == 0 ? Theme.alert : Theme.accent)
                                        .frame(width: g.size.width * (r.total == 0 ? 0 : Double(r.caught) / Double(r.total)))
                                }
                        }
                        .frame(height: 3)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Text(L("Кожна схема лишає свій слід в історії: одні видно одразу, інші лише за кілька кроків або зовсім не видно. Вимкніть шар історії й порівняйте.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: Банки

    private var banks: some View {
        LabPanel(title: L("Банки").s) {
            ForEach(NetSim.banks.indices, id: \.self) { b in
                let list = sim.accounts.enumerated().filter { $0.element.bank == b }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Banca \(NetSim.banks[b])").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(Format.short(list.reduce(0) { $0 + $1.element.balance })).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(list, id: \.offset) { i, a in cell(i, a) }
                    }
                }
                if b < NetSim.banks.count - 1 { Rule() }
            }
            Text(L("Бан діє двадцять кроків, але його можна зняти вручну торкнувшись рахунку.").s).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func cell(_ i: Int, _ a: NetSim.Account) -> some View {
        Button { if a.banned { sim.unban(i) } } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(a.id).font(.system(.caption, design: .monospaced).weight(.semibold))
                    if a.banned {
                        Image(systemName: "nosign").font(.caption2).foregroundStyle(Theme.alert)
                    } else if a.strikes > 0 {
                        Text(String(repeating: "•", count: a.strikes)).font(.caption2).foregroundStyle(Theme.alert)
                    }
                    Spacer()
                    if a.pending > 0 { Text("+" + Format.short(a.pending)).font(.caption2).foregroundStyle(Theme.accent) }
                }
                Text(Format.short(a.balance)).font(.subheadline.weight(.medium)).monospacedDigit()
                    .foregroundStyle(a.banned ? Theme.alert : Color.primary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((a.banned ? Theme.alert : Theme.ink).opacity(a.banned ? 0.16 : 0.07), in: .rect(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Кліринг

    private var clearing: some View {
        LabPanel(title: L("Міжбанківський кліринг").s) {
            row(L("У дорозі").s, L("\(sim.clearingCount) платежів, \(Format.short(sim.inClearing))").s)
            row(L("Розрахунок через").s, L("\(sim.untilSettlement) кроків").s)
            if let s = sim.settlement {
                Rule()
                row(L("Останній розрахунок").s, L("\(s.gross) платежів → \(s.net)").s)
                row(L("Обсяг").s, "\(Format.short(s.grossVolume)) → \(Format.short(s.netVolume))")
            }
            Text(L("Банки не шлють кожен платіж окремо: зустрічні потоки зараховуються, між парою банків іде лише різниця.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
        }
    }

    // MARK: Якість

    private var quality: some View {
        LabPanel(title: L("Якість антифроду").s) {
            HStack(spacing: 22) {
                Stat(value: percent(sim.recall), label: L("Шахрайство зупинено").s)
                Stat(value: percent(sim.precision), label: L("Зупинено вірно").s)
            }
            Rule()
            row(L("Шахрайство зупинено").s, "\(sim.caught)")
            row(L("Шахрайство пройшло").s, "\(sim.missed) · \(Format.short(sim.leaked))")
            row(L("Чесні зупинені").s, "\(sim.falseBlocks)")
            row(L("Чесні пройшли").s, "\(sim.clean)")
            row(L("Бани: вірні й помилкові").s, "\(sim.bansRight) / \(sim.bansWrong)")
            row(L("Автоплатежі: пройшли й зупинені").s, "\(sim.autoDone) / \(sim.autoFailed)")
            Text(L("Нижчий поріг зупиняє більше шахрайства, але частіше б'є по чесних. Шар історії бачить розсилки, дроблення й транзит.").s)
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func percent(_ v: Double?) -> String { v.map { "\(Int(($0 * 100).rounded()))%" } ?? "-" }

    // MARK: Стрічка

    private var feed: some View {
        LabPanel(title: L("Стрічка").s) {
            if sim.events.isEmpty { Text(L("Ще немає").s).foregroundStyle(.secondary) }
            ForEach(sim.events.prefix(14)) { e in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol(e.kind)).font(.caption).foregroundStyle(tint(e.kind)).frame(width: 16).padding(.top, 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.text).font(.system(.footnote, design: .monospaced)).foregroundStyle(e.kind == .ok ? Color.primary : tint(e.kind))
                        if let d = e.detail { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 4)
                    Text("\(e.tick)").font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                }
            }
        }
    }

    private func symbol(_ k: NetSim.Kind) -> String {
        switch k {
        case .ok: "checkmark"
        case .clearing: "arrow.left.arrow.right"
        case .auto: "repeat"
        case .blocked: "hand.raised.fill"
        case .banned: "nosign"
        case .rejected: "xmark"
        case .settle: "building.columns"
        }
    }

    private func tint(_ k: NetSim.Kind) -> Color {
        switch k {
        case .blocked, .banned, .rejected: Theme.alert
        case .clearing, .settle, .auto: Theme.accent
        case .ok: Color.secondary
        }
    }
}
