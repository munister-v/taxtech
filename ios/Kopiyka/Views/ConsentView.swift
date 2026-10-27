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
                    Text("Копійка")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
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
                .padding(.bottom, 8)
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
