import EdgeRouter
import SwiftUI

struct AssistantView: View {
    @Environment(AppModel.self) private var model
    @State private var question = ""
    @State private var turns: [Turn] = []
    @State private var working = false

    struct Turn: Identifiable {
        let id = UUID()
        let question: String
        var answer: String?
        var record: DecisionRecord?
        var error: String?
    }

    var body: some View {
        NavigationStack {
            List {
                if turns.isEmpty {
                    Section {
                        Text("Спитайте про витрати, бюджет чи навчальний банк. Відповідь дасть модель на телефоні або на сервері - залежно від мережі, заряду й упевненості.")
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(turns) { t in
                    Section {
                        Text(t.question).font(.headline)
                        if let a = t.answer { Text(a) }
                        if let e = t.error { Text(e).foregroundStyle(.red) }
                        if let r = t.record {
                            RoutedNote(record: r)
                            FeedbackButtons(id: r.id)
                        }
                    }
                }
                if working { ProgressView() }
            }
            .navigationTitle("Помічник")
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Ваше питання", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit(ask)
                    Button("Надіслати", systemImage: "arrow.up", action: ask)
                        .labelStyle(.iconOnly)
                        .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || working)
                }
                .padding(12)
                .glassEffect(in: .rect(cornerRadius: 22))
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
        }
    }

    private func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        question = ""
        turns.append(Turn(question: q))
        let i = turns.count - 1
        working = true
        Task {
            defer { working = false }
            do {
                let routed = try await model.run(AssistantTask.profile, input: q,
                                                 executors: AssistantTask.executors(api: model.api))
                turns[i].answer = routed.output
                turns[i].record = routed.record
            } catch {
                turns[i].error = error.localizedDescription
            }
        }
    }
}
