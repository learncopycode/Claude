import SwiftUI
import SwiftData

/// The counter screen, with two swipe modes (remembered between launches):
/// - Zikr feed: all your zikrs as cards. Read one, swipe up: +1 to that zikr
///   and the next zikr comes up. Swipe down to go back.
/// - Single zikr: the same card every time. Each swipe (or tap) adds +1.
/// Every count goes into that zikr's own counter and its daily history.
struct CounterFeedView: View {
    @Environment(\.modelContext) private var context
    // Sorted by creation so the order doesn't shift while you count.
    @Query(sort: \ZikrItem.createdAt) private var items: [ZikrItem]
    @AppStorage("swipeMode") private var modeRaw = SwipeMode.feed.rawValue
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false
    @AppStorage("showTranslation") private var showTranslation = true
    @AppStorage("showTransliteration") private var showTransliteration = true

    @State private var currentID: UUID
    @State private var celebrate = false
    @State private var editingTarget = false
    @State private var confirmReset = false
    @State private var unlocked: HueJourney.Achievement?
    @State private var showingAchievements = false

    init(startID: UUID) {
        _currentID = State(initialValue: startID)
    }

    private var mode: Binding<SwipeMode> {
        Binding(
            get: { SwipeMode(rawValue: modeRaw) ?? .feed },
            set: { modeRaw = $0.rawValue }
        )
    }

    private var currentIndex: Int { items.firstIndex { $0.id == currentID } ?? 0 }
    private var current: ZikrItem? { items.isEmpty ? nil : items[currentIndex] }

    private func item(atDepth depth: Int) -> ZikrItem? {
        guard !items.isEmpty else { return nil }
        if mode.wrappedValue == .single { return current }
        return items[(currentIndex + depth) % items.count]
    }

    var body: some View {
        VStack(spacing: 14) {
            SwipeModePicker(mode: mode)
                .padding(.top, 4)

            if let current {
                SwipeDeck(
                    currentKey: AnyHashable("\(mode.wrappedValue.rawValue)-\(current.id)"),
                    canGoBack: mode.wrappedValue == .feed && items.count > 1,
                    onSwipeUp: swipeUp,
                    onSwipeDown: goBack,
                    onTap: { count(current) }
                ) { depth in
                    if let item = item(atDepth: depth) {
                        card(for: item)
                    }
                }
                .padding(.horizontal, 16)

                Text(mode.wrappedValue.hint)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            } else {
                ContentUnavailableView("No counters yet", systemImage: "circle.dotted")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            if mode.wrappedValue == .feed && items.count > 1 {
                PageDots(count: items.count, index: currentIndex).padding(.trailing, 3)
            }
        }
        .overlay(alignment: .top) {
            if celebrate {
                Label("Round complete", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sensoryFeedback(trigger: current?.totalCount ?? 0) { old, new in
            Self.feedback(old: old, new: new, enabled: haptics)
        }
        .achievementToast($unlocked)
        .sheet(isPresented: $showingAchievements) {
            if let current {
                NavigationStack { AchievementsView(item: current) }
                    .presentationDragIndicator(.visible)
            }
        }
        .sensoryFeedback(trigger: celebrate) { _, new in haptics && new ? .success : nil }
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

    private func card(for item: ZikrItem) -> some View {
        ZikrSwipeCard(
            title: item.title,
            arabic: item.arabic,
            transliteration: item.transliteration,
            translation: item.translation,
            source: item.source,
            count: item.count,
            target: item.target,
            caption: captionFor(item),
            countFocused: mode.wrappedValue == .single,
            hueTotal: item.totalCount
        )
    }

    private func captionFor(_ item: ZikrItem) -> String {
        let goal = item.target > 0 ? "of \(item.target)" : "no target"
        return item.rounds > 0 ? "\(goal) · \(item.rounds) round\(item.rounds == 1 ? "" : "s") · \(item.totalCount) total" : goal
    }

    // MARK: Counting

    private func count(_ item: ZikrItem) {
        if sound { CounterFeedback.playTick() }
        var result = ZikrItem.IncrementResult()
        withAnimation(.snappy(duration: 0.2)) {
            result = item.increment(in: context)
        }
        if let achievement = result.unlocked {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { unlocked = achievement }
        } else if result.roundCompleted {
            withAnimation(.spring) { celebrate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation { celebrate = false }
            }
        }
    }

    private func swipeUp() {
        guard let current else { return }
        count(current)
        if mode.wrappedValue == .feed, !items.isEmpty {
            currentID = items[(currentIndex + 1) % items.count].id
        }
    }

    private func goBack() {
        guard !items.isEmpty else { return }
        currentID = items[(currentIndex - 1 + items.count) % items.count].id
    }

    /// Layered haptics: a soft tap per count, firmer every 33, celebration every 100.
    static func feedback(old: Int, new: Int, enabled: Bool) -> SensoryFeedback? {
        guard enabled else { return nil }
        guard new > old else { return .selection }
        if new % HueJourney.recitationsPerColor == 0 { return .success }
        if new % 33 == 0 { return .impact(weight: .heavy, intensity: 0.9) }
        return .impact(flexibility: .soft, intensity: 0.55)
    }

    // MARK: Toolbar

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
                RemainingPill(text: item.target > 0 ? "\(item.remaining) left" : "\(item.totalCount) total")
                    .contentTransition(.numericText())
                    .onTapGesture { editingTarget = true }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                showingAchievements = true
            } label: {
                Image(systemName: "trophy")
            }
            .accessibilityLabel("Achievements")

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
