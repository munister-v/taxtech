import SwiftUI

/// Перший запуск: що це за лабораторія і чи можна надсилати текст мовній моделі на сервері.
struct ConsentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MarkView(height: 64)
                        .padding(.top, 36)
                    Text(Brand.name)
                        .font(.system(size: 44, weight: .semibold))
                        .tracking(-1)
                        .padding(.top, 20)
                    Text(Brand.lab)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .padding(.bottom, 28)

                    point("01", "Облік витрат",
                          "Витрати, чеки й нотатки зберігаються лише на цьому телефоні.")
                    point("02", "Навчальний банк",
                          "Гроші в банку віртуальні. Справжніх рахунків, карток і переказів немає.")
                    point("03", "Де рахувати",
                          "Кожну розумну задачу застосунок виконує на телефоні або на сервері - залежно від мережі, заряду й того, наскільки впевнена модель телефона. Це частина студентського дослідження.")
                    point("04", "Що йде на сервер",
                          "Фото чека розпізнається лише на телефоні. Мовній моделі Anthropic на сервері може піти текст чека чи питання помічнику - але спершу телефон прибирає номери карток, рахунків, телефонів, пошту, ІПН і паспорт.")
                    Text("Згоду можна змінити будь-коли в «Лабораторії».")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button("Дозволити сервер") { decide(true) }
                        .buttonStyle(InkButton())
                    Button("Лише на телефоні") { decide(false) }
                        .buttonStyle(LineButton())
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
                // суцільна підложка з тонкою лінією: текст не налазить на кнопки
                .background(alignment: .top) {
                    Theme.bg.overlay(alignment: .top) {
                        Rectangle().fill(Theme.line).frame(height: Theme.hairline)
                    }
                    .ignoresSafeArea()
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func point(_ index: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.line).frame(height: Theme.hairline)
            HStack(alignment: .top, spacing: 16) {
                Text(index)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .leading)
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(text).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func decide(_ allowed: Bool) {
        model.cloudAIAllowed = allowed
        model.consentAsked = true
        dismiss()
    }
}
