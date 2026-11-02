import Foundation

/// A category used to group duas in the library.
enum DuaCategory: String, CaseIterable, Identifiable {
    case tasbih = "Tasbih & Dhikr"
    case morningEvening = "Morning & Evening"
    case forgiveness = "Forgiveness"
    case quranic = "Duas from the Quran"
    case protection = "Protection"
    case hardship = "Hardship & Anxiety"
    case daily = "Daily Life"
    case salawat = "Salawat"
    case quran = "Quran"
    case names = "99 Names of Allah"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .tasbih: return "circle.dotted"
        case .morningEvening: return "sun.horizon"
        case .forgiveness: return "drop"
        case .quranic: return "book"
        case .protection: return "shield"
        case .hardship: return "heart"
        case .daily: return "house"
        case .salawat: return "sparkles"
        case .quran: return "book.closed"
        case .names: return "star.fill"
        }
    }
}

/// One dua, dhikr or Quran passage, ready to be shown or added to a counter.
/// Arabic text only ever comes from the bundled library or the Quran API —
/// never from the AI — so the wording is always from a known source.
struct DuaContent: Identifiable, Hashable {
    let id: String
    let title: String
    let arabic: String
    let transliteration: String
    let translation: String
    let source: String
    let category: DuaCategory
    let defaultCount: Int
    var tags: [String] = []
}
