import SwiftUI
import SwiftData

/// Counter for one saved zikr: text card on top, tap panel below.
struct CounterView: View {
    @Bindable var item: ZikrItem
    @Environment(\.modelContext) private var context
    @AppStorage("haptics") private var haptics = true
    @AppStorage("sound") private var sound = false
    @AppStorage("showTranslation") private var showTranslation = true
    @AppStorage("showTransliteration") private var showTransliteration = true

    @State private var fullScreen = false
    @State private var celebrate = false
    @State private var editingTarget = false
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 16) {
            if !fullScreen && hasText {
                CounterTextCard(
                    arabic: item.arabic,
                    transliteration: item.transliteration,
                    translation: item.translation,
                    source: item.source,
                    header: item.arabic.isEmpty ? item.title : nil
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            CounterTapPanel(
                count: item.count,
                caption: item.rounds > 0 ? "\(item.totalCount) · round \(item.rounds + 1)" : "\(item.totalCount)",
                fullScreen: $fullScreen,
                celebrate: celebrate,
                onTap: increment,
                onReset: { confirmReset = true }
            )
            .frame(maxHeight: fullScreen || !hasText ? .infinity : 330)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sensoryFeedback(trigger: item.totalCount) { old, new in
            guard haptics else { return nil }
            return new > old ? .impact(weight: .light) : .selection
        }
        .sensoryFeedback(trigger: item.rounds) { old, new in
            haptics && new > old ? .success : nil
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sheet(isPresented: $editingTarget) { TargetSheet(item: item) }
        .confirmationDialog("Reset this counter?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset current round", role: .destructive) { item.count = 0 }
            Button("Reset count and rounds", role: .destructive) {
                item.count = 0
                item.rounds = 0
            }
        }
    }

    private var hasText: Bool {
        !item.arabic.isEmpty || !item.translation.isEmpty || !item.transliteration.isEmpty
    }

    private var shareText: String {
        [item.title, item.arabic, item.transliteration, item.translation, item.source.isEmpty ? "" : "— \(item.source)"]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            RemainingPill(text: item.target > 0 ? "\(item.remaining) left" : item.title)
                .onTapGesture { editingTarget = true }
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
                Button("Undo last count", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(item.totalCount == 0)
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

    private func increment() {
        if sound { CounterFeedback.playTick() }
        withAnimation(.snappy(duration: 0.15)) {
            item.count += 1
            item.totalCount += 1
        }
        item.updatedAt = .now
        DailyTally.add(1, in: context)

        if item.target > 0 && item.count >= item.target {
            item.rounds += 1
            withAnimation(.spring) {
                item.count = 0
                celebrate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { celebrate = false }
            }
        }
    }

    private func undo() {
        guard item.totalCount > 0 else { return }
        withAnimation(.snappy(duration: 0.15)) {
            if item.count > 0 {
                item.count -= 1
            } else if item.rounds > 0 {
                item.rounds -= 1
                item.count = max(0, item.target - 1)
            }
            item.totalCount -= 1
        }
        DailyTally.add(-1, in: context)
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
