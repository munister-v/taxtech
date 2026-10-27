import EdgeRouter
import SwiftData
import SwiftUI

/// Головна: великі цифри місяця, швидкі дії, навчальний банк і рішення телефона за журналом.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var balance: Double?
    @State private var adding = false
    @State private var scanning = false
    let open: (RootView.AppTab) -> Void

    private var cal: Calendar { .current }

    private var thisMonth: Double {
        expenses.filter { cal.isDate($0.date, equalTo: .now, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
    }

    private var lastMonth: Double {
        let prev = cal.date(byAdding: .month, value: -1, to: .now) ?? .now
        return expenses.filter { cal.isDate($0.date, equalTo: prev, toGranularity: .month) }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    hero
                    ActionBar(items: [
                        .init(title: "Витрата", symbol: "plus") { adding = true },
                        .init(title: "Чек", symbol: "doc.text.viewfinder") { scanning = true },
                        .init(title: "Помічник", symbol: "text.bubble") { open(.assistant) },
                    ])
                    bank
                    phone
                    if !expenses.isEmpty { recent }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle(Brand.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $adding) { AddExpenseView() }
            .sheet(isPresented: $scanning) { ReceiptView(closable: true) }
            .task(id: model.signedIn) {
                balance = model.signedIn ? try? await model.api.account().balance : nil
                await model.refresh()
            }
            .refreshable {
                balance = model.signedIn ? try? await model.api.account().balance : nil
                await model.refresh()
            }
        }
    }

    // MARK: Великі блоки

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "uk_UA"))))
                .caption()
            Text("Витрати цього місяця")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Text(Format.money(thisMonth))
                .font(Theme.balance(60))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(delta)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var delta: String {
        guard lastMonth > 0 else { return expenses.isEmpty ? "Додайте першу витрату або чек" : "Минулого місяця витрат не було" }
        let d = (thisMonth - lastMonth) / lastMonth * 100
        return "\(d >= 0 ? "+" : "−")\(Int(abs(d)))% до минулого місяця"
    }

    private var bank: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Навчальний банк", trailing: "віртуальні гроші")
            Button { open(.bank) } label: {
                Surface {
                    VStack(alignment: .leading, spacing: 6) {
                        if let balance {
                            Text(Format.money(balance))
                                .font(Theme.balance(40)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                            Text("на головному рахунку").font(.footnote).foregroundStyle(.secondary)
                        } else {
                            Text("Увійдіть у навчальний банк")
                                .font(.system(size: 26, weight: .semibold)).tracking(-0.4)
                            Text("Картки, депозити, кредити й цілі на віртуальних грошах")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var phone: some View {
        let d = model.decisions
        let n = Double(max(d.count, 1))
        let onDevice = Double(d.filter { $0.placement == .device }.count) / n
        return VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Телефон чи сервер", trailing: d.isEmpty ? nil : "\(d.count) рішень")
            Button { open(.lab) } label: {
                Surface {
                    VStack(alignment: .leading, spacing: 14) {
                        if d.isEmpty {
                            Text("Рішень ще немає")
                                .font(.system(size: 26, weight: .semibold)).tracking(-0.4)
                            Text("Сфотографуйте чек або спитайте помічника - застосунок сам обере, де рахувати")
                                .font(.footnote).foregroundStyle(.secondary)
                        } else {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(Int(onDevice * 100))%")
                                    .font(Theme.balance(40)).monospacedDigit()
                                Text("задач виконано на телефоні").font(.footnote).foregroundStyle(.secondary)
                            }
                            Meter(value: onDevice)
                            HStack {
                                Text("середня затримка").foregroundStyle(.secondary)
                                Spacer()
                                Text(Format.ms(d.map(\.latencyMs).reduce(0, +) / n)).monospacedDigit()
                            }
                            .font(.footnote)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 12) {
            BlockTitle("Останні витрати", trailing: nil)
            Surface {
                ForEach(Array(expenses.prefix(3).enumerated()), id: \.element.persistentModelID) { i, e in
                    if i > 0 { Rule() }
                    AmountRow(title: e.merchant,
                              subtitle: "\(e.category), \(e.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "uk_UA"))))",
                              amount: Format.money(e.amount))
                }
            }
            Button("Усі витрати") { open(.money) }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 4)
        }
    }
}
