import SwiftUI
import SwiftData

/// All your counters as a vertical, TikTok-style feed: tap anywhere on the
/// mint panel to count, swipe up for the next zikr, down for the previous.
struct CounterFeedView: View {
    @Environment(\.modelContext) private var context
    // Sorted by creation so pages don't jump around while you count.
    @Query(sort: \ZikrItem.createdAt) private var items: [ZikrItem]
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false
    @AppStorage("showTranslation") private var showTranslation = true
    @AppStorage("showTransliteration") private var showTransliteration = true
    @AppStorage("seenSwipeHint") private var seenSwipeHint = false

    let startID: UUID
    @State private var currentID: UUID?
    @State private var fullScreen = false
    @State private var editingTarget = false
    @State private var confirmReset = false

    init(startID: UUID) {
        self.startID = startID
        _currentID = State(initialValue: startID)
    }

    private var current: ZikrItem? {
        items.first { $0.id == currentID } ?? items.first
    }

    private var currentIndex: Int {
        items.firstIndex { $0.id == current?.id } ?? 0
    }

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    CounterPage(
                        item: item,
                        fullScreen: $fullScreen,
                        showHint: items.count > 1 && !seenSwipeHint && item.id == startID
                    )
                    .containerRelativeFrame(.vertical)
                    .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            if items.count > 1 {
                PageDots(count: items.count, index: currentIndex)
                    .padding(.trailing, 4)
            }
        }
        .onChange(of: currentID) { _, new in
            if new != startID { seenSwipeHint = true }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sensoryFeedback(.selection, trigger: currentID)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $editingTarget) {
            if let current { TargetSheet(item: current) }
        }
        .confirmationDialog("Reset this counter?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset current round", role: .destructive) { current?.count = 0 }
            Button("Reset count and rounds", role: .destructive) {
                current?.count = 0
                current?.rounds = 0
            }
        }
    }

    private var shareText: String {
        guard let item = current else { return "" }
        return [item.title, item.arabic, item.transliteration, item.translation,
                item.source.isEmpty ? "" : "— \(item.source)"]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if let item = current {
                RemainingPill(text: item.target > 0 ? "\(item.remaining) left" : item.title)
                    .contentTransition(.numericText())
                    .onTapGesture { editingTarget = true }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                sound.toggle()
            } label: {
                Image(systemName: sound ? "speaker.wave.2" : "speaker.slash")
            }
            .accessibilityLabel(sound ? "Sound on" : "Sound off")

            ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }

            Menu {
                Button("Undo last count", systemImage: "arrow.uturn.backward") {
                    if let current { withAnimation(.snappy) { current.undo(in: context) } }
                }
                .disabled((current?.totalCount ?? 0) == 0)
                Button("Change target", systemImage: "target") { editingTarget = true }
                Button("Reset", systemImage: "arrow.counterclockwise") { confirmReset = true }
                Divider()
                Toggle("Show transliteration", isOn: $showTransliteration)
                Toggle("Show translation", isOn: $showTranslation)
                Toggle("Haptics", isOn: $haptics)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

/// One full-screen page of the feed: text card on top, tap panel below.
struct CounterPage: View {
    @Bindable var item: ZikrItem
    @Binding var fullScreen: Bool
    var showHint = false
    @Environment(\.modelContext) private var context
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false
    @State private var celebrate = false
    @State private var confirmReset = false

    private var hasText: Bool {
        !item.arabic.isEmpty || !item.translation.isEmpty || !item.transliteration.isEmpty
    }

    var body: some View {
        VStack(spacing: 14) {
            if !fullScreen && hasText {
                CounterTextCard(
                    arabic: item.arabic,
                    transliteration: item.transliteration,
                    translation: item.translation,
                    source: item.source,
                    header: item.title
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            CounterTapPanel(
                count: item.count,
                caption: item.rounds > 0 ? "\(item.totalCount) · round \(item.rounds + 1)" : "\(item.totalCount)",
                fullScreen: $fullScreen,
                celebrate: celebrate,
                progress: item.progress,
                onTap: increment,
                onReset: { confirmReset = true }
            )
            .frame(maxHeight: fullScreen || !hasText ? .infinity : 320)

            if showHint {
                SwipeHint(text: "Swipe up for your next zikr")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sensoryFeedback(trigger: item.totalCount) { old, new in
            guard haptics else { return nil }
            return new > old ? .impact(weight: .light) : .selection
        }
        .sensoryFeedback(trigger: item.rounds) { old, new in
            haptics && new > old ? .success : nil
        }
        .confirmationDialog("Reset this counter?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset current round", role: .destructive) { withAnimation { item.count = 0 } }
            Button("Reset count and rounds", role: .destructive) {
                withAnimation {
                    item.count = 0
                    item.rounds = 0
                }
            }
        }
    }

    private func increment() {
        if sound { CounterFeedback.playTick() }
        var finishedRound = false
        withAnimation(.snappy(duration: 0.18)) {
            finishedRound = item.increment(in: context)
        }
        guard finishedRound else { return }
        withAnimation(.spring) { celebrate = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { celebrate = false }
        }
    }
}

private struct TargetSheet: View {
    @Bindable var item: ZikrItem
    @Environment(\.dismiss) private var dismiss
    @State private var target = 33

    var body: some View {
        NavigationStack {
            Form {
                Section("Count per round") { TargetPicker(target: $target) }
            }
            .navigationTitle("Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        item.target = target
                        if target > 0 { item.count = min(item.count, max(0, target - 1)) }
                        dismiss()
                    }
                }
            }
            .onAppear { target = item.target }
        }
        .presentationDetents([.medium])
    }
}
