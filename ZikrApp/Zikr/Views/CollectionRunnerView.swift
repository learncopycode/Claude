import SwiftUI
import SwiftData

/// Runs a collection as a vertical feed: one page per dhikr. When a page's
/// count is reached it glides to the next page by itself; you can also swipe.
struct CollectionRunnerView: View {
    let collection: ZikrCollection
    @Environment(\.modelContext) private var context
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false

    private struct Page: Identifiable {
        let id: Int
        let step: ZikrCollection.Step
        let stepNumber: Int
        let cycle: Int
    }

    private let pages: [Page]
    @State private var counts: [Int]
    @State private var currentPage: Int?
    @State private var fullScreen = false
    @State private var confirmRestart = false

    init(collection: ZikrCollection) {
        self.collection = collection
        var pages: [Page] = []
        for cycle in 0..<max(1, collection.cycles) {
            for (index, step) in collection.steps.enumerated() {
                pages.append(Page(id: pages.count, step: step, stepNumber: index + 1, cycle: cycle))
            }
        }
        self.pages = pages
        _counts = State(initialValue: Array(repeating: 0, count: pages.count))
        _currentPage = State(initialValue: 0)
    }

    private var done: Int { counts.reduce(0, +) }
    private var left: Int { max(0, collection.totalCount - done) }
    private var finished: Bool { !pages.isEmpty && left == 0 }
    /// Page ids: one per dhikr, then the "Completed" page.
    private var completedPageID: Int { pages.count }

    var body: some View {
        Group {
            if pages.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "tray")
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(pages) { page in
                            pageView(page)
                                .containerRelativeFrame(.vertical)
                                .id(page.id)
                        }
                        finishedPage
                            .containerRelativeFrame(.vertical)
                            .id(completedPageID)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $currentPage)
                .scrollIndicators(.hidden)
                .overlay(alignment: .trailing) {
                    PageDots(count: pages.count + 1, index: currentPage ?? 0)
                        .padding(.trailing, 4)
                }
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
                    .disabled(done == 0)
                    .accessibilityLabel("Undo")
            }
        }
        .sensoryFeedback(trigger: done) { old, new in
            haptics && new > old ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(trigger: currentPage) { _, _ in haptics ? .selection : nil }
        .sensoryFeedback(trigger: finished) { _, new in haptics && new ? .success : nil }
        .confirmationDialog("Start this collection again?", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("Start again", role: .destructive, action: restart)
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func pageView(_ page: Page) -> some View {
        let count = counts[page.id]
        let isDone = count >= page.step.count
        var header = "\(collection.title) · \(page.stepNumber) of \(collection.steps.count)"
        if collection.cycles > 1 { header += " · round \(page.cycle + 1) of \(collection.cycles)" }

        return VStack(spacing: 14) {
            if !fullScreen {
                CounterTextCard(
                    arabic: page.step.content.arabic,
                    transliteration: page.step.content.transliteration,
                    translation: page.step.content.translation,
                    source: page.step.content.source,
                    header: header
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            CounterTapPanel(
                count: count,
                caption: isDone ? "done ✓" : "of \(page.step.count)",
                fullScreen: $fullScreen,
                progress: Double(count) / Double(max(1, page.step.count)),
                onTap: { tap(page) },
                onReset: { confirmRestart = true }
            )
            .frame(maxHeight: fullScreen ? .infinity : 300)

            if page.id == 0 && done == 0 {
                SwipeHint(text: "Tap to count · it moves on by itself")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var finishedPage: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: finished ? "checkmark.seal.fill" : "hourglass")
                .font(.system(size: 72))
                .foregroundStyle(Theme.mint)
                .symbolEffect(.bounce, value: finished)
            Text(finished ? "Completed" : "Almost there")
                .font(.largeTitle.bold())
            Text(finished
                 ? "\(collection.title) · \(collection.totalCount) recitations. May Allah accept it."
                 : "\(left) recitations left. Swipe back to finish.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if finished {
                Button("Start again", action: restart)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.black)
            }
            Spacer()
        }
        .padding(32)
    }

    private func tap(_ page: Page) {
        // A finished page just moves you along.
        guard counts[page.id] < page.step.count else {
            advance(from: page.id)
            return
        }
        if sound { CounterFeedback.playTick() }
        withAnimation(.snappy(duration: 0.18)) { counts[page.id] += 1 }
        DailyTally.add(1, in: context)
        if counts[page.id] >= page.step.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { advance(from: page.id) }
        }
    }

    /// Glide to the next unfinished page, or to the "Completed" page.
    private func advance(from id: Int) {
        let next = pages.first { $0.id > id && counts[$0.id] < $0.step.count }?.id ?? completedPageID
        withAnimation(.smooth(duration: 0.5)) { currentPage = next }
    }

    private func undo() {
        let id = min(currentPage ?? 0, pages.count - 1)
        // Undo on this page, or on the last page that has counts.
        guard let target = counts[id] > 0 ? id : counts.lastIndex(where: { $0 > 0 }) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            counts[target] -= 1
            currentPage = target
        }
        DailyTally.add(-1, in: context)
    }

    private func restart() {
        withAnimation(.smooth) {
            counts = Array(repeating: 0, count: pages.count)
            currentPage = 0
        }
    }
}
