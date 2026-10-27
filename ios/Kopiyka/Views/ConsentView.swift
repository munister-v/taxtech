import SwiftUI

/// Перший запуск: що це за застосунок і чи можна надсилати текст мовній моделі на сервері.
struct ConsentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // віяло карток - перше, що бачить людина
                    ZStack {
                        ForEach(Array([CardDesign.rose, .navy, .forest].enumerated()), id: \.offset) { i, d in
                            VirtualCardView(number: "•••• 0000", expiry: nil, holder: nil, design: d, animated: i == 2)
                                .frame(width: 230)
                                .rotationEffect(.degrees(Double(i - 1) * 9))
                                .offset(x: CGFloat(i - 1) * 34, y: CGFloat(abs(i - 1)) * 10)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .padding(.top, 12)
                    Text("Копійка")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                    point("Облік витрат",
                          "Витрати, чеки й нотатки зберігаються лише на цьому телефоні.")
                    point("Навчальний банк",
                          "Гроші в банку віртуальні. Справжніх рахунків, карток і переказів немає.")
                    point("Де рахувати",
                          "Кожну розумну задачу застосунок виконує на телефоні або на сервері - залежно від мережі, заряду й того, наскільки впевнена модель телефона. Це частина студентського дослідження.")
                    point("Що йде на сервер",
                          "Фото чека розпізнається лише на телефоні. Мовній моделі Anthropic на сервері може піти текст чека чи питання помічнику - але спершу телефон прибирає номери карток, рахунків, телефонів, пошту, ІПН і паспорт.")
                    Text("Згоду можна змінити будь-коли в «Лабораторії».")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .auroraScreen(height: 700)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        decide(true)
                    } label: {
                        // акцент у темній темі світлий - білий текст на ньому не читається
                        Text("Дозволити сервер")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(scheme == .dark ? Color.black : Color.white)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    Button("Лише на телефоні") { decide(false) }
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 8)
                // текст плавно ховається під кнопки, а не налазить на них
                .background {
                    LinearGradient(colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                                   startPoint: .top, endPoint: .init(x: 0.5, y: 0.35))
                        .ignoresSafeArea()
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func point(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }
    }

    private func decide(_ allowed: Bool) {
        model.cloudAIAllowed = allowed
        model.consentAsked = true
        dismiss()
    }
}
