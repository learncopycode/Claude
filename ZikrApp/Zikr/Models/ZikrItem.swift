import Foundation
import SwiftData

/// A dhikr the user is counting. Saved on the device with SwiftData.
@Model
final class ZikrItem {
    var id: UUID
    var title: String
    var arabic: String
    var transliteration: String
    var translation: String
    var source: String
    /// How many recitations make one round (0 = no target, count forever).
    var target: Int
    /// Count inside the current round.
    var count: Int
    /// Completed rounds.
    var rounds: Int
    /// Every recitation ever made for this item.
    var totalCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        title: String,
        arabic: String = "",
        transliteration: String = "",
        translation: String = "",
        source: String = "",
        target: Int = 33
    ) {
        self.id = UUID()
        self.title = title
        self.arabic = arabic
        self.transliteration = transliteration
        self.translation = translation
        self.source = source
        self.target = max(0, target)
        self.count = 0
        self.rounds = 0
        self.totalCount = 0
        self.createdAt = .now
        self.updatedAt = .now
    }

    convenience init(content: DuaContent, target: Int? = nil) {
        self.init(
            title: content.title,
            arabic: content.arabic,
            transliteration: content.transliteration,
            translation: content.translation,
            source: content.source,
            target: target ?? content.defaultCount
        )
    }

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(count) / Double(target))
    }
}

/// Total recitations for one calendar day, used for "today" and the streak.
@Model
final class DailyTally {
    @Attribute(.unique) var day: String
    var total: Int

    init(day: String, total: Int = 0) {
        self.day = day
        self.total = total
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date = .now) -> String {
        formatter.string(from: date)
    }

    /// Adds (or removes, for undo) recitations to today's total.
    static func add(_ delta: Int, in context: ModelContext) {
        let today = key()
        var descriptor = FetchDescriptor<DailyTally>(predicate: #Predicate { $0.day == today })
        descriptor.fetchLimit = 1
        if let tally = try? context.fetch(descriptor).first {
            tally.total = max(0, tally.total + delta)
        } else if delta > 0 {
            context.insert(DailyTally(day: today, total: delta))
        }
    }

    /// Consecutive days (ending today or yesterday) with at least one recitation.
    static func streak(from tallies: [DailyTally]) -> Int {
        let active = Set(tallies.filter { $0.total > 0 }.map(\.day))
        let calendar = Calendar.current
        var date = Date()
        if !active.contains(key(for: date)) {
            date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        }
        var days = 0
        while active.contains(key(for: date)) {
            days += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return days
    }
}
