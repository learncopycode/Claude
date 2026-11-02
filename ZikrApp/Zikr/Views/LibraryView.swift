import SwiftUI
import SwiftData

/// Browse the verified dua library and the whole Quran.
struct LibraryView: View {
    @State private var search = ""

    private var filtered: [DuaContent] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return DuaLibrary.all + AllahNames.all }
        let live = LocalMatcher.autocomplete(query, limit: 30).compactMap { suggestion -> DuaContent? in
            if case .content(let content) = suggestion { return content }
            return nil
        }
        var hits = live
        for dua in LocalMatcher.searchDuas(query, limit: 50) + LocalMatcher.searchNames(query)
        where !hits.contains(where: { $0.id == dua.id }) {
            hits.append(dua)
        }
        if !hits.isEmpty { return hits }
        let lower = query.lowercased()
        return (DuaLibrary.all + AllahNames.all).filter {
            $0.title.lowercased().contains(lower) || $0.translation.lowercased().contains(lower)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section {
                        NavigationLink {
                            SurahListView()
                        } label: {
                            Label("Quran — all 114 surahs", systemImage: DuaCategory.quran.symbol)
                        }
                        NavigationLink {
                            QuranLoaderView(request: QuranRequest(surah: 2, fromAyah: 255, toAyah: 255))
                        } label: {
                            Label("Ayat al-Kursi", systemImage: "star")
                        }
                    }
                    .listRowBackground(Theme.card)
                    ForEach(DuaCategory.allCases.filter { $0 != .names }) { category in
                        Section {
                            ForEach(DuaLibrary.items(in: category)) { dua in
                                NavigationLink { DuaDetailView(content: dua) } label: { DuaRow(dua: dua) }
                            }
                        } header: {
                            Label(category.rawValue, systemImage: category.symbol)
                        }
                    }
                    .listRowBackground(Theme.card)
                } else {
                    ForEach(filtered) { dua in
                        NavigationLink { DuaDetailView(content: dua) } label: { DuaRow(dua: dua) }
                    }
                    .listRowBackground(Theme.card)
                }
            }
            .themedBackground()
            .navigationTitle("Library")
            .searchable(text: $search, prompt: "Search duas")
        }
    }
}

private struct DuaRow: View {
    let dua: DuaContent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dua.title).font(.headline)
            Text(dua.arabic)
                .font(Theme.arabicFont(size: 16))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

struct SurahListView: View {
    @State private var search = ""

    private var surahs: [SurahInfo] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return QuranIndex.surahs }
        if let number = Int(query) { return QuranIndex.surahs.filter { $0.number == number } }
        let key = LocalMatcher.normalize(query)
        return QuranIndex.surahs.filter {
            LocalMatcher.normalize($0.name).contains(key) || $0.name.lowercased().contains(query.lowercased())
        }
    }

    var body: some View {
        List(surahs) { surah in
            NavigationLink {
                QuranLoaderView(request: QuranRequest(surah: surah.number))
            } label: {
                HStack(spacing: 14) {
                    Text("\(surah.number)")
                        .font(.callout.bold().monospacedDigit())
                        .foregroundStyle(Theme.gold)
                        .frame(width: 34)
                    VStack(alignment: .leading) {
                        Text(surah.name).font(.headline)
                        Text("\(surah.ayahCount) verses").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Theme.card)
        }
        .themedBackground()
        .navigationTitle("Quran")
        .searchable(text: $search, prompt: "Name or number")
    }
}

/// Loads a surah or verses from the Quran API, then shows the detail screen.
struct QuranLoaderView: View {
    let request: QuranRequest
    @State private var content: DuaContent?
    @State private var error: String?

    var body: some View {
        Group {
            if let content {
                DuaDetailView(content: content)
            } else if let error {
                ContentUnavailableView {
                    Label("Couldn't load", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try again") { Task { await load() } }
                }
            } else {
                ProgressView("Loading \(request.title)…")
            }
        }
        .task { await load() }
    }

    private func load() async {
        error = nil
        do {
            content = try await QuranService.shared.fetch(request)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Full text of a dua with a target picker and "Add to counter".
struct DuaDetailView: View {
    let content: DuaContent
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @State private var target: Int
    @State private var added = false

    init(content: DuaContent) {
        self.content = content
        _target = State(initialValue: content.defaultCount)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DuaTextView(
                    arabic: content.arabic,
                    transliteration: content.transliteration,
                    translation: content.translation,
                    source: content.source,
                    arabicSize: content.arabic.count > 600 ? 24 : 30
                )
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Count per round").font(.subheadline.bold())
                    TargetPicker(target: $target)
                }
                .card()

                Button {
                    added = true
                    router.openCounter(ZikrItem.findOrCreate(for: content, target: target, in: context))
                } label: {
                    Label("Add & start counting", systemImage: "play.circle.fill")
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    _ = ZikrItem.findOrCreate(for: content, target: target, in: context)
                    added = true
                } label: {
                    Label(added ? "Added to counter" : "Add to counter", systemImage: added ? "checkmark" : "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(content.title)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: added)
    }
}
