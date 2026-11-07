import SwiftUI

/// Перший запуск: заставка з назвою і згода на сервер. Пояснення механізмів - в експертному режимі.
struct ConsentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let last = 1

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                privacy.tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(alignment: .top) {
            ZStack(alignment: .top) { Theme.bg; AuroraField().frame(height: 700) }.ignoresSafeArea()
        }
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
                    Button(L("Дозволити сервер").s) { decide(true) }.buttonStyle(InkButton())
                    Button(L("Лише на телефоні").s) { decide(false) }.buttonStyle(LineButton())
                }
            } else {
                HStack(spacing: 10) {
                    if page > 0 {
                        Button(L("Назад").s) { page -= 1 }.buttonStyle(LineButton()).frame(width: 110)
                    }
                    Button(page == 0 ? L("Почати").s : L("Далі").s) { page += 1 }.buttonStyle(InkButton())
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
        ZStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VirtualCardView(number: "•••• •••• •••• 2026", expiry: "10/30", holder: "TAXTECH", design: .dark)
                    .tilt(cornerRadius: 20)
                    .padding(.horizontal, 24)
                Text(Brand.name)
                    .font(.display(60, .medium)).tracking(-2)
                    .foregroundStyle(Theme.goldFill)
                    .minimumScaleFactor(0.7).lineLimit(1)
                    .padding(.top, 36)
                VStack(spacing: 6) {
                    Text(Brand.lab).foregroundStyle(.secondary)
                    Text(L("Токен TAX - навчальна одиниця, а не гроші.").s).foregroundStyle(Theme.ink)
                }
                .font(.subheadline).multilineTextAlignment(.center)
                .padding(.horizontal, 32).padding(.top, 14)
                Spacer(minLength: 0)
            }
        }
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(L("Ваші дані").s)
                .font(.system(size: 40, weight: .semibold)).tracking(-1.2)
                .padding(.top, 56)
            VStack(spacing: 0) {
                fact("iphone", L("Лише телефон").s,
                     L("Фото чека розпізнається на телефоні й нікуди не йде.").s)
                Rectangle().fill(.white.opacity(0.08)).frame(height: Theme.hairline).padding(.leading, 70)
                fact("sparkles", L("Що може піти на сервер").s,
                     L("Текст чека чи питання помічнику для мовної моделі Anthropic - але спершу телефон прибирає номери карток, рахунків, телефонів, пошту, ІПН і паспорт.").s)
                Rectangle().fill(.white.opacity(0.08)).frame(height: Theme.hairline).padding(.leading, 70)
                fact("slider.horizontal.3", L("Згоду можна змінити").s,
                     L("Налаштування, експертний режим, журнал рішень.").s)
            }
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: Theme.hairline))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func fact(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
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
