import SwiftUI
import SwiftData

/// The tasbih counter: tap anywhere on the lower half to count.
struct CounterView: View {
    @Bindable var item: ZikrItem
    @Environment(\.modelContext) private var context
    @AppStorage("haptics") private var haptics = true
    @AppStorage("showTranslation") private var showTranslation = true
    @AppStorage("showTransliteration") private var showTransliteration = true

    @State private var celebrate = false
    @State private var pulse = false
    @State private var editingTarget = false
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            if hasText {
                ScrollView {
                    DuaTextView(
                        arabic: item.arabic,
                        transliteration: item.transliteration,
                        translation: item.translation,
                        source: item.source,
                        arabicSize: item.arabic.count > 300 ? 22 : 28,
                        showTransliteration: showTransliteration,
                        showTranslation: showTranslation
                    )
                    .padding(20)
                }
                .frame(maxHeight: 280)
                .background(Color(.secondarySystemGroupedBackground))
            }

            tapArea
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.title)
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

    private var tapArea: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            ZStack {
                Circle()
                    .stroke(Theme.green.opacity(0.12), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: item.target > 0 ? item.progress : 0)
                    .stroke(
                        AngularGradient(colors: [Theme.green, Theme.gold, Theme.green], center: .center),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.3), value: item.count)

                VStack(spacing: 4) {
                    Text("\(item.count)")
                        .font(.system(size: 76, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(value: Double(item.count)))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text(item.target > 0 ? "of \(item.target)" : "no target")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if item.rounds > 0 {
                        Text("Round \(item.rounds + 1) · \(item.rounds) done")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 4)
                    }
                }
                .padding(30)
            }
            .frame(maxWidth: 280, maxHeight: 280)
            .scaleEffect(pulse ? 0.96 : 1)
            .overlay {
                if celebrate {
                    Label("Round complete", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Text("Tap anywhere to count")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: increment)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), count \(item.count)\(item.target > 0 ? " of \(item.target)" : "")")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to count")
        .accessibilityAction(named: "Undo") { undo() }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: undo) { Image(systemName: "arrow.uturn.backward") }
                .disabled(item.totalCount == 0)
                .accessibilityLabel("Undo")
            Menu {
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
        withAnimation(.snappy(duration: 0.15)) {
            item.count += 1
            item.totalCount += 1
            pulse = true
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.snappy(duration: 0.15)) { pulse = false }
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
