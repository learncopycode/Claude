import Foundation

/// Fetches Quran text from the free, key-less AlQuran Cloud API
/// (https://alquran.cloud/api): Uthmani Arabic, Saheeh International
/// translation and a transliteration. Results are cached in memory.
actor QuranService {
    static let shared = QuranService()

    enum QuranError: LocalizedError {
        case badResponse
        var errorDescription: String? { "Couldn't load the Quran text. Check your internet connection and try again." }
    }

    private struct Verse {
        let number: Int
        let arabic: String
        let translation: String
        let transliteration: String
    }

    private var surahCache: [Int: [Verse]] = [:]

    func fetch(_ request: QuranRequest) async throws -> DuaContent {
        let verses = try await loadSurah(request.surah)
        let selected: [Verse]
        if let from = request.fromAyah {
            let to = request.toAyah ?? from
            selected = verses.filter { (from...to).contains($0.number) }
        } else {
            selected = verses
        }
        guard !selected.isEmpty else { throw QuranError.badResponse }

        let multiple = selected.count > 1
        let arabic = selected
            .map { multiple ? "\($0.arabic) ﴿\(Self.arabicDigits($0.number))﴾" : $0.arabic }
            .joined(separator: " ")
        let translation = selected
            .map { multiple ? "(\($0.number)) \($0.translation)" : $0.translation }
            .joined(separator: " ")
        let transliteration = selected
            .map { multiple ? "(\($0.number)) \($0.transliteration)" : $0.transliteration }
            .joined(separator: " ")

        let info = QuranIndex.surah(request.surah)
        let source = request.isWholeSurah
            ? "Quran, Surah \(request.surah) · \(info?.ayahCount ?? selected.count) verses"
            : "Quran \(request.reference)"

        return DuaContent(
            id: "quran-\(request.reference)",
            title: request.title,
            arabic: arabic,
            transliteration: transliteration,
            translation: translation,
            source: source,
            category: .quran,
            defaultCount: Self.suggestedCount(for: request)
        )
    }

    /// Common recitation counts: the three Quls are read 3 times morning and evening.
    static func suggestedCount(for request: QuranRequest) -> Int {
        if request.isWholeSurah && [112, 113, 114].contains(request.surah) { return 3 }
        return 1
    }

    private func loadSurah(_ number: Int) async throws -> [Verse] {
        if let cached = surahCache[number] { return cached }

        let url = URL(string: "https://api.alquran.cloud/v1/surah/\(number)/editions/quran-uthmani,en.sahih,en.transliteration")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw QuranError.badResponse }

        let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        func edition(_ id: String) -> [APIAyah] {
            decoded.data.first { $0.edition.identifier == id }?.ayahs ?? []
        }
        let arabic = edition("quran-uthmani")
        let english = edition("en.sahih")
        let translit = edition("en.transliteration")
        guard !arabic.isEmpty else { throw QuranError.badResponse }

        let verses = arabic.enumerated().map { index, ayah in
            Verse(
                number: ayah.numberInSurah,
                arabic: ayah.text.trimmingCharacters(in: .whitespacesAndNewlines),
                translation: index < english.count ? english[index].text : "",
                transliteration: index < translit.count ? Self.stripTags(translit[index].text) : ""
            )
        }
        surahCache[number] = verses
        return verses
    }

    private static func stripTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    static func arabicDigits(_ number: Int) -> String {
        let digits: [Character] = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        return String(String(number).compactMap { $0.wholeNumberValue.map { digits[$0] } })
    }

    private struct APIResponse: Decodable { let data: [APIEdition] }
    private struct APIEdition: Decodable {
        let edition: APIEditionInfo
        let ayahs: [APIAyah]
    }
    private struct APIEditionInfo: Decodable { let identifier: String }
    private struct APIAyah: Decodable {
        let numberInSurah: Int
        let text: String
    }
}
