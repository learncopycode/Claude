import SwiftUI
import SwiftData

/// Guides through a collection step by step, moving on automatically.
struct CollectionRunnerView: View {
    let collection: ZikrCollection
    @Environment(\.modelContext) private var context
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false

    @State private var stepIndex = 0
    @State private var cycle = 0
    @State private var count = 0
    @State private var done = 0
    @State private var finished = false
    @State private var fullScreen = false
    @State private var history: [(step: Int, cycle: Int, count: Int)] = []

    private var step: ZikrCollection.Step { collection.steps[stepIndex] }
    private var left: Int { max(0, collection.totalCount - done) }

    var body: some View {
        Group {
            if collection.steps.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "tray")
            } else if finished {
                finishedView
            } else {
                VStack(spacing: 16) {
                    if !fullScreen {
                        CounterTextCard(
                            arabic: step.content.arabic,
                            transliteration: step.content.transliteration,
                            translation: step.content.translation,
                            source: step.content.source,
                            header: progressHeader
                        )
                        .id(stepIndex)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                    }
                    CounterTapPanel(
                        count: count,
                        caption: "of \(step.count)",
                        fullScreen: $fullScreen,
                        onTap: increment,
                        onReset: restart
                    )
                    .frame(maxHeight: fullScreen ? .infinity : 300)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { RemainingPill(text: "\(left) left") }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { sound.toggle() } label: {
                    Image(systemName: sound ? "speaker.wave.2" : "speaker.slash")
                }
                Button(action: undo) { Image(systemName: "arrow.uturn.backward") }
                    .disabled(history.isEmpty || finished)
                    .accessibilityLabel("Undo")
            }
        }
        .sensoryFeedback(trigger: done) { old, new in
            haptics && new > old ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(trigger: stepIndex) { _, _ in haptics ? .success : nil }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var progressHeader: String {
        var text = "\(collection.title) · \(stepIndex + 1) of \(collection.steps.count)"
        if collection.cycles > 1 { text += " · round \(cycle + 1) of \(collection.cycles)" }
        return text
    }

    private var finishedView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.mint)
            Text("Completed").font(.largeTitle.bold())
            Text("\(collection.title) · \(collection.totalCount) recitations")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Start again", action: restart)
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
        .sensoryFeedback(.success, trigger: finished)
    }

    private func increment() {
        if sound { CounterFeedback.playTick() }
        history.append((stepIndex, cycle, count))
        done += 1
        DailyTally.add(1, in: context)
        withAnimation(.snappy(duration: 0.15)) { count += 1 }
        guard count >= step.count else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            count = 0
            if stepIndex + 1 < collection.steps.count {
                stepIndex += 1
            } else if cycle + 1 < collection.cycles {
                cycle += 1
                stepIndex = 0
            } else {
                finished = true
            }
        }
    }

    private func undo() {
        guard let last = history.popLast() else { return }
        withAnimation(.snappy(duration: 0.15)) {
            stepIndex = last.step
            cycle = last.cycle
            count = last.count
        }
        done -= 1
        DailyTally.add(-1, in: context)
    }

    private func restart() {
        withAnimation {
            stepIndex = 0
            cycle = 0
            count = 0
            done = 0
            history = []
            finished = false
        }
    }
}
