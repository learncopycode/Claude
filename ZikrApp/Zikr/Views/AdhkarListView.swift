import SwiftUI
import SwiftData

/// "My Adhkar": everything the user is counting, plus today's stats.
struct AdhkarListView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @Query(sort: \ZikrItem.updatedAt, order: .reverse) private var items: [ZikrItem]
    @Query private var tallies: [DailyTally]
    @State private var showingNew = false

    private var today: Int {
        tallies.first { $0.day == DailyTally.key() }?.total ?? 0
    }

    var body: some View {
        NavigationStack(path: $router.counterPath) {
            List {
                Section {
                    StatsHeader(today: today, streak: DailyTally.streak(from: tallies), lifetime: items.reduce(0) { $0 + $1.totalCount })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if items.isEmpty {
                    Section { emptyState }
                } else {
                    Section("My adhkar") {
                        ForEach(items) { item in
                            NavigationLink(value: item) { ZikrRow(item: item) }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(items[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Zikr")
            .navigationDestination(for: ZikrItem.self) { CounterView(item: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Custom zikr", systemImage: "square.and.pencil") { showingNew = true }
                        Button("After-prayer tasbih (33·33·33)", systemImage: "moon.stars") { addTasbihSet() }
                        Button("Ask AI for a dua", systemImage: "sparkles") { router.tab = .assistant }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingNew) { NewZikrSheet() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "circle.dotted.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.gold)
            Text("Start your first zikr")
                .font(.headline)
            Text("Ask the AI for any dua or surah, browse the library, or add the classic after-prayer tasbih.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                router.tab = .assistant
            } label: {
                Label("Ask AI", systemImage: "sparkles").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button("Add after-prayer tasbih", action: addTasbihSet)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }

    private func addTasbihSet() {
        for id in ["allahuakbar", "alhamdulillah", "subhanallah"] {
            if let dua = DuaLibrary.dua(id: id) {
                context.insert(ZikrItem(content: dua))
            }
        }
    }
}

private struct StatsHeader: View {
    let today: Int
    let streak: Int
    let lifetime: Int

    var body: some View {
        HStack(spacing: 10) {
            stat("Today", "\(today)", "sun.max.fill")
            stat("Streak", "\(streak) \(streak == 1 ? "day" : "days")", "flame.fill")
            stat("All time", "\(lifetime)", "infinity")
        }
        .padding(.vertical, 4)
    }

    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(Theme.gold)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ZikrRow: View {
    let item: ZikrItem

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.green.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: item.progress)
                    .stroke(Theme.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(item.count)")
                    .font(.caption2.bold().monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .padding(4)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline).lineLimit(1)
                if !item.arabic.isEmpty {
                    Text(item.arabic)
                        .font(Theme.arabicFont(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        let goal = item.target > 0 ? "\(item.count)/\(item.target)" : "\(item.count)"
        return item.rounds > 0 ? "\(goal) · \(item.rounds) round\(item.rounds == 1 ? "" : "s")" : goal
    }
}

/// Create a zikr by hand.
struct NewZikrSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var arabic = ""
    @State private var translation = ""
    @State private var target = 33

    var body: some View {
        NavigationStack {
            Form {
                Section("Zikr") {
                    TextField("Name (e.g. SubhanAllah)", text: $title)
                    TextField("Arabic (optional)", text: $arabic, axis: .vertical)
                        .multilineTextAlignment(.trailing)
                    TextField("Meaning (optional)", text: $translation, axis: .vertical)
                }
                Section("Target") {
                    TargetPicker(target: $target)
                }
            }
            .navigationTitle("New zikr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        context.insert(ZikrItem(
                            title: title.trimmingCharacters(in: .whitespaces),
                            arabic: arabic,
                            translation: translation,
                            target: target
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
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
