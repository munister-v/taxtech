import EdgeRouter
import PhotosUI
import SwiftData
import SwiftUI

struct ReceiptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var ocrMs: Double?
    @State private var fields: ReceiptTask.Fields?
    @State private var parsed: ReceiptTask.Fields?
    @State private var record: DecisionRecord?
    @State private var error: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker("Вибрати фото чека", selection: $item, matching: .images)
                    Button("Демо-чек") { Task { await process(DemoReceipt.image()) } }
                } footer: {
                    Text("Фото розпізнається на телефоні. На сервер, якщо знадобиться, іде лише текст без номерів карток, телефонів і ІПН.")
                }

                if let image {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                    }
                }
                if working { ProgressView() }
                if let error { Text(error).foregroundStyle(.red) }

                if fields != nil, let record {
                    Section("Розпізнано") {
                        TextField("Де", text: binding(\.merchant))
                        TextField("Сума, ₴", value: binding(\.total), format: .number).keyboardType(.decimalPad)
                        Picker("Категорія", selection: binding(\.category)) {
                            ForEach(AddExpenseView.categories, id: \.self, content: Text.init)
                        }
                    }
                    Section {
                        RoutedNote(record: record)
                        if let ocrMs {
                            Text("Розпізнавання фото на телефоні: \(Format.ms(ocrMs))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button("Зберегти витрату") { save() }
                            .disabled((fields?.total ?? 0) <= 0)
                    } footer: {
                        Text("Якщо ви виправили суму, метод зарахує це як помилку і наступного разу буде обережнішим.")
                    }
                }
            }
            .navigationTitle("Чек")
            .onChange(of: item) {
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return }
                    await process(img)
                }
            }
        }
    }

    private func binding<T>(_ key: WritableKeyPath<ReceiptTask.Fields, T>) -> Binding<T> {
        Binding(get: { fields![keyPath: key] }, set: { fields![keyPath: key] = $0 })
    }

    private func process(_ img: UIImage) async {
        image = img
        error = nil
        fields = nil
        working = true
        defer { working = false }
        do {
            guard let cg = img.cgImage else { return }
            let clock = ContinuousClock()
            let t0 = clock.now
            let lines = try await ReceiptTask.recognize(cg)
            let d = clock.now - t0
            ocrMs = Double(d.components.seconds) * 1000 + Double(d.components.attoseconds) / 1e15
            let routed = try await model.run(ReceiptTask.profile, input: lines,
                                             executors: ReceiptTask.executors(api: model.api))
            fields = routed.output
            parsed = routed.output
            record = routed.record
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() {
        guard let f = fields, let record else { return }
        context.insert(Expense(amount: f.total ?? 0, merchant: f.merchant, category: f.category, source: "Чек"))
        // мітка зі звичайного користування: сума не змінена - відповідь правильна
        let correct = f.total == parsed?.total
        Task { await model.feedback(record.id, correct: correct) }
        fields = nil
        image = nil
        item = nil
    }
}

/// Чек, намальований у застосунку, - щоб перевірити ланцюжок у симуляторі без фото.
enum DemoReceipt {
    @MainActor
    static func image() -> UIImage {
        let view = VStack(alignment: .leading, spacing: 6) {
            Text("СІЛЬПО").font(.title2.bold())
            Text("м. Ірпінь, вул. Соборна 1")
            Text("Хліб житній          32,50")
            Text("Молоко 2,5%          41,90")
            Text("Сир кисломолочний    89,00")
            Text("Картка 0000 1144 2233 5566")
            Text("СУМА                163,40").font(.headline)
        }
        .font(.system(size: 18, design: .monospaced))
        .foregroundStyle(.black)
        .padding(24)
        .background(.white)
        let r = ImageRenderer(content: view)
        r.scale = 3
        return r.uiImage ?? UIImage()
    }
}
