import EdgeRouter
import PhotosUI
import SwiftData
import SwiftUI
import VisionKit

struct ReceiptView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var ocrTime: Duration?
    @State private var fields: ReceiptTask.Fields?
    @State private var parsed: ReceiptTask.Fields?
    @State private var record: DecisionRecord?
    @State private var error: String?
    @State private var working = false
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            LabForm {
                Section {
                    if VNDocumentCameraViewController.isSupported {
                        Button("Сфотографувати чек") { scanning = true }
                    }
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
                if let error { Text(error).foregroundStyle(.secondary) }

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
                        if let ocrTime {
                            Text("Розпізнавання фото на телефоні: \(Format.ms(ocrTime))")
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
            .labForm()
            .navigationTitle("Чек")
            .fullScreenCover(isPresented: $scanning) {
                DocumentScanner { img in Task { await process(img) } }
                    .ignoresSafeArea()
            }
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
            ocrTime = clock.now - t0
            let routed = try await model.run(ReceiptTask.profile, input: lines,
                                             executors: ReceiptTask.executors(cloud: model.cloudAI))
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

/// Сканер документів VisionKit: сам знаходить краї чека, вирівнює перспективу й прибирає тіні.
struct DocumentScanner: UIViewControllerRepresentable {
    let scanned: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor final class Coordinator: NSObject, @MainActor VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 { parent.scanned(scan.imageOfPage(at: 0)) }
            parent.dismiss()
        }

        func documentCameraViewControllerDidCancel(_ c: VNDocumentCameraViewController) { parent.dismiss() }

        func documentCameraViewController(_ c: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}
