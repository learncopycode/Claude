import Foundation

struct SurahInfo: Identifiable, Hashable {
    let number: Int
    let name: String
    let ayahCount: Int
    var id: Int { number }
}

/// The 114 surahs with their verse counts, bundled so surah lookups work offline.
enum QuranIndex {
    static let surahs: [SurahInfo] = zip(names, counts).enumerated().map { index, pair in
        SurahInfo(number: index + 1, name: pair.0, ayahCount: pair.1)
    }

    static func surah(_ number: Int) -> SurahInfo? {
        (1...114).contains(number) ? surahs[number - 1] : nil
    }

    private static let names = [
        "Al-Fatihah", "Al-Baqarah", "Ali 'Imran", "An-Nisa", "Al-Ma'idah", "Al-An'am", "Al-A'raf",
        "Al-Anfal", "At-Tawbah", "Yunus", "Hud", "Yusuf", "Ar-Ra'd", "Ibrahim", "Al-Hijr", "An-Nahl",
        "Al-Isra", "Al-Kahf", "Maryam", "Taha", "Al-Anbiya", "Al-Hajj", "Al-Mu'minun", "An-Nur",
        "Al-Furqan", "Ash-Shu'ara", "An-Naml", "Al-Qasas", "Al-'Ankabut", "Ar-Rum", "Luqman",
        "As-Sajdah", "Al-Ahzab", "Saba", "Fatir", "Ya-Sin", "As-Saffat", "Sad", "Az-Zumar", "Ghafir",
        "Fussilat", "Ash-Shura", "Az-Zukhruf", "Ad-Dukhan", "Al-Jathiyah", "Al-Ahqaf", "Muhammad",
        "Al-Fath", "Al-Hujurat", "Qaf", "Adh-Dhariyat", "At-Tur", "An-Najm", "Al-Qamar", "Ar-Rahman",
        "Al-Waqi'ah", "Al-Hadid", "Al-Mujadilah", "Al-Hashr", "Al-Mumtahanah", "As-Saff", "Al-Jumu'ah",
        "Al-Munafiqun", "At-Taghabun", "At-Talaq", "At-Tahrim", "Al-Mulk", "Al-Qalam", "Al-Haqqah",
        "Al-Ma'arij", "Nuh", "Al-Jinn", "Al-Muzzammil", "Al-Muddaththir", "Al-Qiyamah", "Al-Insan",
        "Al-Mursalat", "An-Naba", "An-Nazi'at", "'Abasa", "At-Takwir", "Al-Infitar", "Al-Mutaffifin",
        "Al-Inshiqaq", "Al-Buruj", "At-Tariq", "Al-A'la", "Al-Ghashiyah", "Al-Fajr", "Al-Balad",
        "Ash-Shams", "Al-Layl", "Ad-Duha", "Ash-Sharh", "At-Tin", "Al-'Alaq", "Al-Qadr", "Al-Bayyinah",
        "Az-Zalzalah", "Al-'Adiyat", "Al-Qari'ah", "At-Takathur", "Al-'Asr", "Al-Humazah", "Al-Fil",
        "Quraysh", "Al-Ma'un", "Al-Kawthar", "Al-Kafirun", "An-Nasr", "Al-Masad", "Al-Ikhlas",
        "Al-Falaq", "An-Nas",
    ]

    private static let counts = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109, 123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60, 34, 30, 73, 54, 45, 83, 182, 88, 75, 85, 54, 53,
        89, 59, 37, 35, 38, 29, 18, 45, 60, 49, 62, 55, 78, 96, 29, 22, 24, 13, 14, 11, 11, 18, 12,
        12, 30, 52, 52, 44, 28, 28, 20, 56, 40, 31, 50, 40, 46, 42, 29, 19, 36, 25, 22, 17, 19, 26,
        30, 20, 15, 21, 11, 8, 8, 19, 5, 8, 8, 11, 11, 8, 3, 9, 5, 4, 7, 3, 6, 3, 5, 4, 5, 6,
    ]
}

/// A request for a whole surah or a range of its verses.
struct QuranRequest: Hashable {
    let surah: Int
    var fromAyah: Int? = nil
    var toAyah: Int? = nil

    /// Returns a request clamped to real verse numbers, or nil if the surah doesn't exist.
    static func valid(surah: Int, from: Int? = nil, to: Int? = nil) -> QuranRequest? {
        guard let info = QuranIndex.surah(surah) else { return nil }
        guard let from, from > 0 else { return QuranRequest(surah: surah) }
        let start = min(from, info.ayahCount)
        let end = min(max(to ?? start, start), info.ayahCount)
        if start == 1 && end == info.ayahCount { return QuranRequest(surah: surah) }
        return QuranRequest(surah: surah, fromAyah: start, toAyah: end)
    }

    var isWholeSurah: Bool { fromAyah == nil }

    var reference: String {
        guard let fromAyah else { return "\(surah)" }
        let to = toAyah ?? fromAyah
        return to == fromAyah ? "\(surah):\(fromAyah)" : "\(surah):\(fromAyah)–\(to)"
    }

    var title: String {
        if surah == 2 && fromAyah == 255 && (toAyah ?? 255) == 255 { return "Ayat al-Kursi" }
        if surah == 2 && fromAyah == 285 && toAyah == 286 { return "Last two verses of Al-Baqarah" }
        let name = QuranIndex.surah(surah)?.name ?? "Surah \(surah)"
        return isWholeSurah ? "Surah \(name)" : "\(name) \(reference)"
    }
}
