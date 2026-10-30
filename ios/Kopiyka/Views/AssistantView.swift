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

    static let suggestions = [
        L("Як скласти бюджет на місяць?").s,
        L("Скільки податку платить ФОП 3 групи?").s,
        L("Як повернути ПДФО за навчання?").s,
        L("Що таке хеш запису в чеку?").s,
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 18) {
                        if turns.isEmpty { intro }
                        ForEach(turns) { t in
                            VStack(spacing: 10) {
                                questionBubble(t.question)
                                if t.answer != nil || t.error != nil { answerBubble(t) }
                            }
                            .id(t.id)
                        }
                        if working {
                            HStack {
                                ProgressView()
                                Text(L("Думаю…").s).foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(Theme.gutter)
                    .padding(.bottom, 80)
                }
                .onChange(of: turns.count) { withAnimation { proxy.scrollTo(turns.last?.id, anchor: .bottom) } }
            }
            .screenBackground()
            .navigationTitle(L("Помічник").s)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack(alignment: .bottom) {
                    TextField(L("Ваше питання").s, text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .onSubmit(ask)
                    Button(action: ask) {
                        Image(systemName: "arrow.up")
                            .font(.headline)
                            .foregroundStyle(Theme.onInk)
                            .frame(width: 34, height: 34)
                            .background(Theme.ink, in: .circle)
                    }
                    .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || working)
                    .opacity(question.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
                .background(Theme.surface, in: .rect(cornerRadius: 24, style: .continuous))
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
        }
    }

    private var intro: some View {
        Surface {
            ForEach(Array(Self.suggestions.enumerated()), id: \.offset) { i, s in
                if i > 0 { Rule() }
                Button {
                    question = s
                    ask()
                } label: {
                    HStack {
                        Text(s).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private func questionBubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: 48)
            Text(text)
                .foregroundStyle(Theme.onInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Theme.ink, in: .rect(cornerRadius: 18, style: .continuous))
        }
    }

    private func answerBubble(_ t: Turn) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                if let a = t.answer { Text(a) }
                if let e = t.error { Text(e).foregroundStyle(.secondary) }
                if let r = t.record {
                    FeedbackButtons(id: r.id)
                }
            }
            .padding(16)
            .background(Theme.surface, in: .rect(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 32)
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
                                                 executors: AssistantTask.executors(cloud: model.cloudAI))
                turns[i].answer = routed.output
                turns[i].record = routed.record
            } catch {
                turns[i].error = error.localizedDescription
            }
        }
    }
}
