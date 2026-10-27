import SwiftUI

/// Перший запуск: чотири великі екрани про те, що це, і п'ятий - згода на сервер.
struct ConsentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let last = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                ledger.tag(1)
                bank.tag(2)
                router.tag(3)
                privacy.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .screenBackground()
        .interactiveDismissDisabled()
        .animation(.smooth(duration: 0.25), value: page)
    }

    // MARK: Нижня смуга

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0...last, id: \.self) { i in
                    Rectangle()
                        .fill(i <= page ? Theme.ink : Theme.line)
                        .frame(height: 3)
                }
            }
            if page == last {
                VStack(spacing: 10) {
                    Button("Дозволити сервер") { decide(true) }.buttonStyle(InkButton())
                    Button("Лише на телефоні") { decide(false) }.buttonStyle(LineButton())
                }
            } else {
                HStack(spacing: 10) {
                    if page > 0 {
                        Button("Назад") { page -= 1 }.buttonStyle(LineButton()).frame(width: 110)
                    }
                    Button(page == 0 ? "Почати" : "Далі") { page += 1 }.buttonStyle(InkButton())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            Theme.bg.overlay(alignment: .top) {
                Rectangle().fill(Theme.line).frame(height: Theme.hairline)
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Сторінки

    private var welcome: some View {
        Slide {
            Spacer(minLength: 0)
            MarkView(height: 150)
            Text(Brand.name)
                .font(.system(size: 64, weight: .semibold))
                .tracking(-2)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.top, 28)
            Text(Brand.lab)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    private var ledger: some View {
        Slide {
            Text("01").caption()
            Text("Усі гроші\nв одному місці")
                .headline1()
            Text("Витрати, чеки й нотатки. Усе лишається на цьому телефоні.")
                .lead()
            Spacer(minLength: 24)
            BarsSketch()
                .frame(height: 150)
            Spacer(minLength: 0)
        }
    }

    private var bank: some View {
        Slide {
            Text("02").caption()
            Text("Навчальний\nбанк")
                .headline1()
            Text("Картки, депозити, кредити й цілі - на віртуальних грошах. Справжніх рахунків і переказів немає.")
                .lead()
            Spacer(minLength: 24)
            VirtualCardView(number: "•••• •••• •••• 2026", expiry: "10/30", holder: "TAXTECH", design: .dark)
                .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
    }

    private var router: some View {
        Slide {
            Text("03").caption()
            Text("Телефон\nчи сервер")
                .headline1()
            Text("Кожну розумну задачу застосунок виконує там, де краще: залежно від мережі, заряду й упевненості моделі. Це частина студентського дослідження.")
                .lead()
            Spacer(minLength: 24)
            RouteSketch()
                .frame(height: 110)
            Spacer(minLength: 0)
        }
    }

    private var privacy: some View {
        Slide {
            Text("04").caption()
            Text("Ваші дані")
                .headline1()
            VStack(alignment: .leading, spacing: 0) {
                fact("Лише телефон",
                     "Фото чека розпізнається на телефоні й нікуди не йде.")
                fact("Що може піти на сервер",
                     "Текст чека чи питання помічнику для мовної моделі Anthropic - але спершу телефон прибирає номери карток, рахунків, телефонів, пошту, ІПН і паспорт.")
                fact("Згоду можна змінити",
                     "Будь-коли в «Лабораторії».")
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    private func fact(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: Theme.hairline)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
        }
    }

    private func decide(_ allowed: Bool) {
        model.cloudAIAllowed = allowed
        model.consentAsked = true
        dismiss()
    }
}

/// Одна сторінка знайомства: вирівнювання вліво, без прокрутки - усе вміщається на екрані.
private struct Slide<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 24)
    }
}

private extension View {
    /// Великий заголовок сторінки.
    func headline1() -> some View {
        font(.system(size: 46, weight: .semibold))
            .tracking(-1.2)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }

    func lead() -> some View {
        font(.title3).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Плоскі стовпчики - «облік»: тиждень витрат.
private struct BarsSketch: View {
    private let values: [CGFloat] = [0.35, 0.6, 0.25, 0.8, 0.5, 1, 0.4]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                Rectangle()
                    .fill(i == 5 ? Theme.ink : Theme.ink.opacity(0.14))
                    .frame(maxWidth: .infinity)
                    .frame(height: 150 * v)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Два блоки з лінією між ними - «телефон» і «сервер».
private struct RouteSketch: View {
    var body: some View {
        HStack(spacing: 0) {
            node("Телефон", filled: true)
            Rectangle().fill(Theme.ink).frame(height: 1.5)
            node("Сервер", filled: false)
        }
        .accessibilityHidden(true)
    }

    private func node(_ title: String, filled: Bool) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(filled ? Theme.onInk : Theme.ink)
            .frame(width: 110, height: 110)
            .background(filled ? Theme.ink : .clear, in: .rect(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(Theme.ink, lineWidth: 1.5))
    }
}
