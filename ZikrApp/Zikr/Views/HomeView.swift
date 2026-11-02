import SwiftUI
import SwiftData

/// The Counter tab: your counters, then sections of dhikr, duas, the 99 Names
/// and guided collections. Tapping any item opens its counter straight away.
struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @Query(sort: \ZikrItem.updatedAt, order: .reverse) private var items: [ZikrItem]
    @Query private var tallies: [DailyTally]
    @Query(sort: \CustomCollection.createdAt, order: .reverse) private var myCollections: [CustomCollection]

    @EnvironmentObject private var assistant: AssistantService
    @State private var newSheetKind: NewZikrSheet.Kind?
    @State private var dhikrsExpanded = true
    @State private var collectionsExpanded = true

    private static let dhikrCategories: [DuaCategory] = [.tasbih, .forgiveness, .salawat]
    private static let duaCategories: [DuaCategory] = [.morningEvening, .protection, .hardship, .daily]

    private var dhikrs: [DuaContent] { Self.dhikrCategories.flatMap(DuaLibrary.items(in:)) }
    private var duaCount: Int { Self.duaCategories.map { DuaLibrary.items(in: $0).count }.reduce(0, +) }
    private var today: Int { tallies.first { $0.day == DailyTally.key() }?.total ?? 0 }

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    askCard
                    stats

                    if !items.isEmpty {
                        header("My counters")
                        ForEach(items.prefix(8)) { item in
                            Button { router.path.append(.counter(item)) } label: { MyCounterRow(item: item) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", systemImage: "trash", role: .destructive) { context.delete(item) }
                                }
                        }
                    }

                    header("Dhikr & duas")

                    Button { router.path.append(.names) } label: {
                        SectionCard(
                            title: "99 Names of Allah",
                            quote: "“And to Allah belong the best names, so invoke Him by them.” – Quran 7:180",
                            symbol: "star.fill",
                            count: AllahNames.all.count
                        )
                    }
                    .buttonStyle(.plain)

                    Button { withAnimation(.snappy) { dhikrsExpanded.toggle() } } label: {
                        SectionCard(
                            title: "Dhikrs",
                            quote: "“Remember Allah much, so that you may be successful.” – Quran 8:45",
                            symbol: "leaf.fill",
                            count: dhikrs.count,
                            expandable: true,
                            expanded: dhikrsExpanded
                        )
                    }
                    .buttonStyle(.plain)
                    if dhikrsExpanded {
                        ForEach(dhikrs) { dua in
                            Button { open(dua) } label: { BulletRow(title: dua.title) }
                                .buttonStyle(.plain)
                        }
                    }

                    Button {
                        router.path.append(.duas(title: "Duas", categories: Self.duaCategories))
                    } label: {
                        SectionCard(
                            title: "Duas",
                            quote: "“And your Lord says: Call upon Me; I will respond to you.” – Quran 40:60",
                            symbol: "book.fill",
                            count: duaCount
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        router.path.append(.duas(title: "Duas of the prophets", categories: [.quranic]))
                    } label: {
                        SectionCard(
                            title: "Duas from the Quran",
                            quote: "Duas of the prophets and believers, from the Holy Quran",
                            symbol: "book.closed.fill",
                            count: DuaLibrary.items(in: .quranic).count
                        )
                    }
                    .buttonStyle(.plain)

                    Button { router.path.append(.surahs) } label: {
                        SectionCard(
                            title: "Quran",
                            quote: "All 114 surahs — read and count any surah or verse",
                            symbol: "text.book.closed.fill",
                            count: QuranIndex.surahs.count
                        )
                    }
                    .buttonStyle(.plain)

                    Button { withAnimation(.snappy) { collectionsExpanded.toggle() } } label: {
                        SectionCard(
                            title: "Collections",
                            quote: "Guided sets of dhikr and duas, one after another",
                            symbol: "list.bullet",
                            count: Collections.all.count + myCollections.count,
                            expandable: true,
                            expanded: collectionsExpanded
                        )
                    }
                    .buttonStyle(.plain)
                    if collectionsExpanded {
                        ForEach(myCollections) { custom in
                            Button { router.path.append(.customCollection(custom)) } label: {
                                BulletRow(title: custom.title, subtitle: custom.asCollection.subtitle, badge: "Mine")
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { context.delete(custom) }
                            }
                        }
                        Button { newSheetKind = .collection } label: {
                            Label("Create a collection with AI", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(Theme.mint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        ForEach(Collections.all) { collection in
                            Button { router.path.append(.collection(collection.id)) } label: {
                                BulletRow(
                                    title: collection.title,
                                    subtitle: collection.subtitle,
                                    badge: collection.cycles > 1 ? "\(collection.cycles)x" : nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .themedBackground()
            .navigationTitle("Zikr")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { newSheetKind = .zikr } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New zikr")
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .counter(let item):
                    CounterView(item: item)
                case .collection(let id):
                    if let collection = Collections.collection(id: id) {
                        CollectionRunnerView(collection: collection)
                    }
                case .customCollection(let custom):
                    CollectionRunnerView(collection: custom.asCollection)
                case .names:
                    NamesListView()
                case .duas(let title, let categories):
                    DuaListView(title: title, categories: categories)
                case .surahs:
                    SurahListView()
                }
            }
            .sheet(item: $newSheetKind) { kind in
                NewZikrSheet(initialKind: kind)
                    .environmentObject(router)
                    .environmentObject(assistant)
            }
        }
    }

    private func open(_ dua: DuaContent) {
        router.path.append(.counter(ZikrItem.findOrCreate(for: dua, in: context)))
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.title2.bold())
            .padding(.top, 14)
    }

    private var askCard: some View {
        Button { router.ask() } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(Theme.mint, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ask AI").font(.headline).foregroundStyle(.white)
                    Text("Find any dua, surah or zikr and start counting")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }

    private var stats: some View {
        HStack(spacing: 10) {
            stat("Today", "\(today)", "sun.max.fill")
            stat("Streak", "\(DailyTally.streak(from: tallies))d", "flame.fill")
            stat("All time", "\(items.reduce(0) { $0 + $1.totalCount })", "infinity")
        }
    }

    private func stat(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(Theme.mint)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .card(padding: 12)
    }
}

/// A saved counter with its progress bar, like the community cards in the reference app.
private struct MyCounterRow: View {
    let item: ZikrItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if !item.arabic.isEmpty {
                    Text(item.arabic)
                        .font(Theme.arabicFont(size: 20))
                        .lineLimit(1)
                        .frame(maxWidth: 170, alignment: .trailing)
                }
            }
            HStack {
                Text(item.rounds > 0 ? "\(item.rounds) round\(item.rounds == 1 ? "" : "s") done" : "In progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.mint)
                Spacer()
                Text(item.target > 0 ? "\(item.count) / \(item.target)" : "\(item.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: item.progress)
                .tint(Theme.mint)
        }
        .card()
    }
}

/// The 99 Names: tap a name to count it, or recite all 99 in order.
struct NamesListView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                Button { router.path.append(.collection(Collections.namesCollection.id)) } label: {
                    BulletRow(title: "Recite all 99 Names", subtitle: "One tap per name, moves on automatically", badge: "99")
                }
                .buttonStyle(.plain)

                ForEach(AllahNames.all) { name in
                    Button {
                        router.path.append(.counter(ZikrItem.findOrCreate(for: name, in: context)))
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name.title).font(.headline).foregroundStyle(.white)
                                Text(name.translation).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(name.arabic)
                                .font(Theme.arabicFont(size: 26))
                                .foregroundStyle(Theme.mint)
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .themedBackground()
        .navigationTitle("99 Names of Allah")
    }
}

/// Duas from some categories, grouped. Tapping one opens its counter.
struct DuaListView: View {
    let title: String
    let categories: [DuaCategory]
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(categories) { category in
                    if categories.count > 1 {
                        Label(category.rawValue, systemImage: category.symbol)
                            .font(.headline)
                            .foregroundStyle(Theme.mint)
                            .padding(.top, 12)
                    }
                    ForEach(DuaLibrary.items(in: category)) { dua in
                        Button {
                            router.path.append(.counter(ZikrItem.findOrCreate(for: dua, in: context)))
                        } label: {
                            BulletRow(title: dua.title)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .themedBackground()
        .navigationTitle(title)
    }
}
