import SwiftUI
import SwiftData

/// "Add new zikr": a Zikr, a Dua, or a Collection. Type a few words in the
/// AI box and it fills everything in from verified sources; every field
/// stays editable.
struct NewZikrSheet: View {
    enum Kind: String, CaseIterable, Identifiable {
        case zikr = "Zikr", dua = "Dua", collection = "Collection"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var assistant: AssistantService
    @EnvironmentObject private var router: AppRouter

    @State private var kind: Kind = .zikr

    // AI
    @State private var aiQuery = ""
    @State private var thinking = false
    @State private var aiNote: String?
    @State private var suggestions: [DuaContent] = []

    // Zikr / Dua
    @State private var title = ""
    @State private var arabic = ""
    @State private var transliteration = ""
    @State private var translation = ""
    @State private var target = 33
    /// The verified entry the fields were filled from, if any.
    @State private var filled: DuaContent?

    // Collection
    @State private var collectionTitle = ""
    @State private var steps: [ZikrCollection.Step] = []
    @State private var openSection: String?

    @FocusState private var aiFocused: Bool
    @FocusState private var titleFocused: Bool
    @State private var loadingSuggestionID: String?

    init(initialKind: Kind = .zikr) {
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("Type", selection: $kind) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if kind == .collection {
                        aiBox
                        collectionForm
                    } else {
                        zikrForm
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .themedBackground()
            .navigationTitle("Add new zikr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: kind) {
                aiNote = nil
                suggestions = []
                if filled == nil { target = kind == .dua ? 1 : 33 }
            }
            .onAppear {
                if kind == .collection { aiFocused = true } else { titleFocused = true }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: AI box

    private var aiPlaceholder: String {
        switch kind {
        case .zikr: return "Ask AI: “SubhanAllah 100 times”, “istighfar”"
        case .dua: return "Ask AI: “dua for exams”, “Ayat al-Kursi”"
        case .collection: return "Describe it: “morning protection”, “before sleep”"
        }
    }

    private var aiBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.mint)
                TextField(aiPlaceholder, text: $aiQuery, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($aiFocused)
                    .submitLabel(.go)
                    .onSubmit { runAI() }
                if thinking {
                    ProgressView()
                } else {
                    Button(kind == .collection ? "Build" : "Fill") { runAI() }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .foregroundStyle(.black)
                        .disabled(aiQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.mint.opacity(0.35), lineWidth: 1)
            )

            if let aiNote {
                Label(aiNote, systemImage: aiModeIcon)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if kind != .collection && suggestions.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions) { item in
                            Button(item.title) { fill(item, target: nil) }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(filled?.id == item.id ? Theme.mint : .secondary)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }

    private var aiModeIcon: String {
        assistant.mode == .onDeviceAI ? "sparkles" : "magnifyingglass"
    }

    // MARK: Zikr / Dua form

    /// Live matches while typing the title in English letters.
    private var liveSuggestions: [LocalMatcher.Suggestion] {
        guard titleFocused, title != filled?.title else { return [] }
        return LocalMatcher.autocomplete(title)
    }

    private var showsSearchPanel: Bool {
        titleFocused && title.trimmingCharacters(in: .whitespaces).count >= 2 && title != filled?.title
    }

    private var zikrForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(titleFocused ? Theme.mint : .secondary)
                TextField("Title — type to search, e.g. “rabbana atina”", text: $title)
                    .font(.title3)
                    .focused($titleFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit {
                        if let first = LocalMatcher.autocomplete(title).first {
                            pick(first)
                        } else {
                            runAI(title)
                        }
                    }
                if thinking { ProgressView() }
            }
            .formRow()

            if showsSearchPanel {
                searchPanel
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let aiNote, !showsSearchPanel {
                Label(aiNote, systemImage: aiModeIcon)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }
            if suggestions.count > 1 && !showsSearchPanel {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions) { item in
                            Button(item.title) { fill(item, target: nil) }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .tint(filled?.id == item.id ? Theme.mint : .secondary)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.top, 10)
            }

            TextField("Arabic text", text: $arabic, axis: .vertical)
                .font(arabic.isEmpty ? .title3 : Theme.arabicFont(size: 26))
                .lineSpacing(8)
                .formRow()

            TextField("Transcription", text: $transliteration, axis: .vertical)
                .font(.title3)
                .formRow()

            TextField("Translation", text: $translation, axis: .vertical)
                .font(.title3)
                .formRow()

            if let filled {
                Label(
                    isUnchanged ? "From \(filled.source)" : "Edited by you · originally from \(filled.source)",
                    systemImage: isUnchanged ? "checkmark.seal.fill" : "pencil"
                )
                .font(.footnote)
                .foregroundStyle(isUnchanged ? Theme.mint : .secondary)
                .padding(.vertical, 14)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Count per round").font(.headline)
                TargetPicker(target: $target)
            }
            .padding(.top, 18)
        }
    }

    /// Dropdown of instant matches, plus "Ask AI" for anything in plain words.
    private var searchPanel: some View {
        VStack(spacing: 0) {
            ForEach(liveSuggestions) { suggestion in
                Button { pick(suggestion) } label: {
                    SuggestionRow(suggestion: suggestion, loading: loadingSuggestionID == suggestion.id)
                }
                .buttonStyle(.plain)
                Divider().overlay(Color.white.opacity(0.06))
            }
            Button { runAI(title) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.black)
                        .frame(width: 30, height: 30)
                        .background(Theme.mint, in: Circle())
                    Text("Ask AI: “\(title.trimmingCharacters(in: .whitespaces))”")
                        .foregroundStyle(Theme.mint)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(thinking)
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.06)))
        .animation(.smooth(duration: 0.2), value: liveSuggestions.map(\.id))
    }

    /// Fills the form from a live match (loading Quran text first if needed).
    private func pick(_ suggestion: LocalMatcher.Suggestion) {
        switch suggestion {
        case .content(let content):
            fill(content, target: nil)
            suggestions = []
            aiNote = "Filled from \(content.source). You can still edit anything."
            titleFocused = false
        case .quran(let request):
            loadingSuggestionID = suggestion.id
            Task {
                if let content = try? await QuranService.shared.fetch(request) {
                    fill(content, target: nil)
                    aiNote = "Loaded from the Quran. You can still edit anything."
                    titleFocused = false
                } else {
                    aiNote = "Couldn't load \(request.title). Check your internet connection."
                }
                loadingSuggestionID = nil
            }
        }
    }

    /// True while the Arabic still matches the verified entry it came from.
    private var isUnchanged: Bool {
        guard let filled else { return false }
        return filled.arabic == arabic && filled.title == title
    }

    // MARK: Collection form

    private var collectionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Title", text: $collectionTitle)
                .font(.title3)
                .formRow()

            if !steps.isEmpty {
                HStack {
                    Text("In this collection").font(.title2.bold())
                    Spacer()
                    Button("Clear", role: .destructive) { withAnimation { steps.removeAll() } }
                        .font(.subheadline)
                }
                ForEach($steps, id: \.content.id) { $step in
                    StepEditorRow(step: $step) {
                        withAnimation { steps.removeAll { $0.content.id == step.content.id } }
                    }
                }
            }

            Text("Select zikrs").font(.title2.bold()).padding(.top, 8)

            pickerSection(
                id: "dhikrs", title: "Dhikrs",
                quote: "“Remember Allah much, so that you may be successful.” – Quran 8:45",
                symbol: "leaf.fill",
                items: [DuaCategory.tasbih, .forgiveness, .salawat].flatMap(DuaLibrary.items(in:))
            )
            pickerSection(
                id: "duas", title: "Duas",
                quote: "“And your Lord says: Call upon Me; I will respond to you.” – Quran 40:60",
                symbol: "book.fill",
                items: [DuaCategory.morningEvening, .protection, .hardship, .daily].flatMap(DuaLibrary.items(in:))
            )
            pickerSection(
                id: "quranic", title: "Duas from the Quran",
                quote: "Duas of the prophets and believers, plus Ayat al-Kursi and the Quls",
                symbol: "book.closed.fill",
                items: DuaLibrary.items(in: .quranic) + DuaLibrary.items(in: .quran)
            )
            pickerSection(
                id: "names", title: "99 Names of Allah",
                quote: "“And to Allah belong the best names, so invoke Him by them.” – Quran 7:180",
                symbol: "star.fill",
                items: AllahNames.all
            )
        }
    }

    private func pickerSection(id: String, title: String, quote: String, symbol: String, items: [DuaContent]) -> some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.snappy) { openSection = openSection == id ? nil : id }
            } label: {
                SectionCard(
                    title: title, quote: quote, symbol: symbol, count: items.count,
                    expandable: true, expanded: openSection == id
                )
            }
            .buttonStyle(.plain)

            if openSection == id {
                ForEach(items) { item in
                    let selected = steps.contains { $0.content.id == item.id }
                    Button {
                        withAnimation(.snappy) {
                            if selected {
                                steps.removeAll { $0.content.id == item.id }
                            } else {
                                steps.append(.init(content: item, count: item.defaultCount))
                            }
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? Theme.mint : .secondary)
                            Text(item.title)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text("×\(item.defaultCount)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Actions

    private var canSave: Bool {
        switch kind {
        case .collection:
            return !collectionTitle.trimmingCharacters(in: .whitespaces).isEmpty && !steps.isEmpty
        case .zikr, .dua:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func runAI(_ text: String? = nil) {
        let query = (text ?? aiQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !thinking else { return }
        aiFocused = false
        titleFocused = false
        thinking = true
        let currentKind = kind

        Task {
            if currentKind == .collection {
                let suggestion = await assistant.suggestCollection(query)
                if collectionTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    collectionTitle = suggestion.title
                }
                var added = 0
                withAnimation {
                    for item in suggestion.items where !steps.contains(where: { $0.content.id == item.id }) {
                        steps.append(.init(content: item, count: item.defaultCount))
                        added += 1
                    }
                }
                aiNote = suggestion.items.isEmpty
                    ? "No verified matches. Pick zikrs from the lists below."
                    : "\(suggestion.note) Added \(added). Adjust the counts or add more below."
            } else {
                let plan = await assistant.answer(query)
                var results: [DuaContent] = []
                for request in plan.quran {
                    if let content = try? await QuranService.shared.fetch(request) { results.append(content) }
                }
                for dua in plan.duas where !results.contains(where: { $0.id == dua.id }) {
                    results.append(dua)
                }
                suggestions = Array(results.prefix(6))
                if let first = suggestions.first {
                    fill(first, target: plan.repetitions)
                    aiNote = suggestions.count > 1
                        ? "Filled from verified sources. Not the right one? Pick another below."
                        : "Filled from verified sources. You can still edit anything."
                } else {
                    aiNote = "No verified match found. You can type it in yourself."
                }
            }
            thinking = false
        }
    }

    private func fill(_ content: DuaContent, target newTarget: Int?) {
        withAnimation {
            filled = content
            title = content.title
            arabic = content.arabic
            transliteration = content.transliteration
            translation = content.translation
            target = newTarget ?? content.defaultCount
        }
    }

    private func save() {
        switch kind {
        case .collection:
            let collection = CustomCollection(
                title: collectionTitle.trimmingCharacters(in: .whitespaces),
                steps: steps
            )
            context.insert(collection)
            dismiss()
            router.openCollection(collection)
        case .zikr, .dua:
            let item = ZikrItem(
                title: title.trimmingCharacters(in: .whitespaces),
                arabic: arabic.trimmingCharacters(in: .whitespacesAndNewlines),
                transliteration: transliteration.trimmingCharacters(in: .whitespacesAndNewlines),
                translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
                source: isUnchanged ? (filled?.source ?? "") : "",
                target: target
            )
            if isUnchanged { item.libraryID = filled?.id }
            context.insert(item)
            dismiss()
            router.openCounter(item)
        }
    }
}

/// A live search match: title, Arabic preview and source.
private struct SuggestionRow: View {
    let suggestion: LocalMatcher.Suggestion
    var loading = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                switch suggestion {
                case .content(let content):
                    Text(content.arabic)
                        .font(Theme.arabicFont(size: 18))
                        .foregroundStyle(Theme.mint)
                        .lineLimit(1)
                    Text(content.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .quran:
                    Text("Tap to load from the Quran")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if loading {
                ProgressView()
            } else {
                Image(systemName: "arrow.up.left")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

/// One step in a collection being built: title, count stepper, remove.
private struct StepEditorRow: View {
    @Binding var step: ZikrCollection.Step
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.mint).frame(width: 8, height: 8)
            Text(step.content.title)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Stepper(value: $step.count, in: 1...10_000) {
                Text("×\(step.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.mint)
            }
            .fixedSize()
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension View {
    /// A borderless form row with a thin divider, like the reference design.
    func formRow() -> some View {
        self
            .padding(.vertical, 18)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            }
    }
}

/// Quick presets plus a stepper for the round size.
struct TargetPicker: View {
    @Binding var target: Int
    private let presets = [1, 3, 7, 33, 99, 100, 1000]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(value: $target, in: 0...100_000) {
                Text(target == 0 ? "No target (count freely)" : "\(target) per round")
                    .monospacedDigit()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(presets, id: \.self) { value in
                        Button("\(value)") { target = value }
                            .buttonStyle(.bordered)
                            .tint(value == target ? Theme.green : .secondary)
                    }
                }
            }
        }
    }
}
