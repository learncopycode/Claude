import SwiftUI
import SwiftData

/// Chat-style assistant: ask for a dua, surah or zikr and add it to a counter.
struct AssistantView: View {
    @EnvironmentObject private var assistant: AssistantService
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var thinking = false
    @FocusState private var focused: Bool

    private let suggestions = [
        "Dua for anxiety", "Ayat al-Kursi", "Surah Al-Mulk", "Istighfar 100 times",
        "Morning adhkar", "Dua before an exam", "The three Quls", "Dua for my parents",
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ModeBanner(mode: assistant.mode)
                        if messages.isEmpty { intro }
                        ForEach(messages) { message in
                            MessageView(message: message).id(message.id)
                        }
                        if thinking {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Looking it up…").foregroundStyle(.secondary)
                            }
                            .id("thinking")
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) {
                    if let id = messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .top) }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle("Ask AI")
            .toolbar {
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear") { messages.removeAll() }
                    }
                }
            }
            .onAppear { assistant.refreshMode() }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask for any dua, surah or zikr — in your own words. I'll fetch it from verified sources and you can add it to a counter in one tap.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { text in
                    Button(text) { send(text) }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .font(.subheadline)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("e.g. dua for sleep, Surah Yasin, 2:255", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { send(input) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 32))
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || thinking)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !thinking else { return }
        input = ""
        focused = false
        messages.append(ChatMessage(role: .user, text: query))
        thinking = true

        Task {
            let plan = await assistant.answer(query)
            var results: [DuaContent] = []
            var errors: [String] = []
            for request in plan.quran {
                do {
                    results.append(try await QuranService.shared.fetch(request))
                } catch {
                    errors.append("\(request.title): \(error.localizedDescription)")
                }
            }
            results += plan.duas
            messages.append(ChatMessage(
                role: .assistant,
                text: plan.note,
                results: results,
                repetitions: plan.repetitions,
                usedAI: plan.usedAI,
                errors: errors
            ))
            thinking = false
        }
    }
}

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
    var results: [DuaContent] = []
    var repetitions: Int? = nil
    var usedAI = false
    var errors: [String] = []
}

private struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(Theme.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        case .assistant:
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(message.text)
                } icon: {
                    Image(systemName: message.usedAI ? "sparkles" : "magnifyingglass")
                        .foregroundStyle(Theme.gold)
                }
                .font(.subheadline)

                ForEach(message.results) { content in
                    ResultCard(content: content, suggestedCount: message.repetitions)
                }
                ForEach(message.errors, id: \.self) { error in
                    Label(error, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// A fetched dua with one-tap "Add to counter".
struct ResultCard: View {
    let content: DuaContent
    var suggestedCount: Int?
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var added: ZikrItem?
    @State private var expanded = false

    private var count: Int { suggestedCount ?? content.defaultCount }
    private var isLong: Bool { content.arabic.count > 260 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(content.category.rawValue, systemImage: content.category.symbol)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.gold)
                Spacer()
                Text("×\(count)").font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(content.title).font(.headline)

            DuaTextView(
                arabic: isLong && !expanded ? String(content.arabic.prefix(260)) + " …" : content.arabic,
                transliteration: isLong && !expanded ? "" : content.transliteration,
                translation: isLong && !expanded ? String(content.translation.prefix(220)) + "…" : content.translation,
                source: content.source,
                arabicSize: 24
            )
            if isLong {
                Button(expanded ? "Show less" : "Show full text") {
                    withAnimation { expanded.toggle() }
                }
                .font(.footnote)
            }

            HStack {
                if let added {
                    Button {
                        router.openCounter(added)
                    } label: {
                        Label("Added — open counter", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        let item = ZikrItem(content: content, target: count)
                        context.insert(item)
                        added = item
                    } label: {
                        Label("Add to counter", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .card()
        .sensoryFeedback(.success, trigger: added != nil)
    }
}

private struct ModeBanner: View {
    let mode: AssistantService.Mode

    var body: some View {
        switch mode {
        case .onDeviceAI:
            Label("On-device AI · free, private, works offline", systemImage: "cpu")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .smartSearch(let reason):
            Label(reason.isEmpty ? "Smart search" : reason, systemImage: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Wraps chips onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += isFirst ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows.filter { !$0.indices.isEmpty }
    }
}
