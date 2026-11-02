import SwiftUI
import SwiftData

/// Runs a collection as a swipe deck. Each swipe (or tap) counts +1 on the
/// current dhikr; when its count is reached, the next dhikr rises up.
/// Every count is also added to that dhikr's own counter, so its totals
/// (today, week, month, year, all time) keep growing.
struct CollectionRunnerView: View {
    let collection: ZikrCollection
    @Environment(\.modelContext) private var context
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false

    private struct Page {
        let step: ZikrCollection.Step
        let stepNumber: Int
        let cycle: Int
    }

    private let pages: [Page]
    @State private var counts: [Int]
    @State private var index = 0
    /// Page indexes in the order they were counted, for undo.
    @State private var history: [Int] = []
    @State private var confirmRestart = false
    @State private var unlocked: HueJourney.Achievement?
    @Query private var items: [ZikrItem]

    init(collection: ZikrCollection) {
        self.collection = collection
        var pages: [Page] = []
        for cycle in 0..<max(1, collection.cycles) {
            for (number, step) in collection.steps.enumerated() {
                pages.append(Page(step: step, stepNumber: number + 1, cycle: cycle))
            }
        }
        self.pages = pages
        _counts = State(initialValue: Array(repeating: 0, count: pages.count))
    }

    private var done: Int { counts.reduce(0, +) }
    private var left: Int { max(0, collection.totalCount - done) }
    private var finished: Bool { !pages.isEmpty && index >= pages.count }

    var body: some View {
        VStack(spacing: 14) {
            if pages.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "tray")
            } else if finished {
                finishedView
            } else {
                stepProgress
                SwipeDeck(
                    currentKey: AnyHashable(index),
                    canGoBack: index > 0,
                    onSwipeUp: countCurrent,
                    onSwipeDown: { index = max(0, index - 1) },
                    onTap: countCurrent
                ) { depth in
                    card(depth: depth)
                }
                .padding(.horizontal, 16)

                Text("Swipe up or tap to count — the next dhikr comes up by itself")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                RemainingPill(text: "\(left) left").contentTransition(.numericText())
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { sound.toggle() } label: {
                    Image(systemName: sound ? "speaker.wave.2" : "speaker.slash")
                }
                .accessibilityLabel(sound ? "Sound on" : "Sound off")
                Button(action: undo) { Image(systemName: "arrow.uturn.backward") }
                    .disabled(history.isEmpty)
                    .accessibilityLabel("Undo")
                Button { confirmRestart = true } label: { Image(systemName: "arrow.counterclockwise") }
                    .disabled(done == 0)
                    .accessibilityLabel("Start again")
            }
        }
        .sensoryFeedback(trigger: done) { old, new in
            new > old ? CounterFeedView.feedback(old: old, new: new, enabled: haptics) : nil
        }
        .achievementToast($unlocked)
        .sensoryFeedback(trigger: index) { _, _ in haptics ? .success : nil }
        .confirmationDialog("Start this collection again?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Start again", role: .destructive, action: restart)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    /// Thin segmented bar: one segment per dhikr.
    private var stepProgress: some View {
        HStack(spacing: 3) {
            ForEach(pages.indices, id: \.self) { i in
                Capsule()
                    .fill(i < index ? Theme.mint : (i == index ? Theme.mint.opacity(0.55) : Color.white.opacity(0.15)))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .animation(.smooth, value: index)
    }

    @ViewBuilder
    private func card(depth: Int) -> some View {
        // The card waiting behind is the same dhikr until its count is reached.
        let pageIndex = depth == 0 || counts[index] + 1 < pages[index].step.count ? index : index + 1
        if pageIndex < pages.count {
            let page = pages[pageIndex]
            ZikrSwipeCard(
                title: page.step.content.title,
                arabic: page.step.content.arabic,
                transliteration: page.step.content.transliteration,
                translation: page.step.content.translation,
                source: page.step.content.source,
                count: counts[pageIndex] + (depth == 1 && pageIndex == index ? 1 : 0),
                target: page.step.count,
                header: headerText(for: page),
                hueTotal: lifetimeTotal(of: page.step.content)
            )
        } else {
            CompletedCard()
        }
    }

    /// All recitations ever made of this dhikr, for its card color.
    private func lifetimeTotal(of content: DuaContent) -> Int {
        items.first { $0.libraryID == content.id }?.totalCount ?? 0
    }

    private func headerText(for page: Page) -> String {
        let base = "\(page.stepNumber) of \(collection.steps.count) · \(collection.title)"
        guard collection.cycles > 1 else { return base }
        return "Round \(page.cycle + 1)/\(collection.cycles) · " + base
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 76))
                .foregroundStyle(Theme.mint)
                .symbolEffect(.bounce, value: finished)
            Text("Completed").font(.largeTitle.bold())
            Text("\(collection.title) · \(collection.totalCount) recitations.\nMay Allah accept it from you.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Start again", action: restart)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
            Spacer()
        }
        .padding(32)
        .sensoryFeedback(.success, trigger: finished)
    }

    // MARK: Counting

    private func countCurrent() {
        guard index < pages.count else { return }
        if sound { CounterFeedback.playTick() }
        let page = pages[index]
        withAnimation(.snappy(duration: 0.2)) { counts[index] += 1 }
        // Add to this dhikr's own counter and history.
        let result = ZikrItem.findOrCreate(for: page.step.content, in: context).increment(in: context)
        if let achievement = result.unlocked {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { unlocked = achievement }
        }
        history.append(index)
        if counts[index] >= page.step.count {
            withAnimation(.smooth) { index += 1 }
        }
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        withAnimation(.snappy(duration: 0.2)) {
            counts[last] -= 1
            index = last
        }
        ZikrItem.findOrCreate(for: pages[last].step.content, in: context).undo(in: context)
    }

    private func restart() {
        withAnimation(.smooth) {
            counts = Array(repeating: 0, count: pages.count)
            index = 0
            history = []
        }
    }
}

/// Shown behind the last card: the collection is about to be complete.
private struct CompletedCard: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.mint)
            Text("Completed").font(.title.bold())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
