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
    /// The library dua this counter was made from, so tapping it again reopens the same counter.
    var libraryID: String?

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
        self.libraryID = nil
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
        self.libraryID = content.id
    }

    /// Reopens the counter for a library dua, or creates it the first time.
    static func findOrCreate(for content: DuaContent, target: Int? = nil, in context: ModelContext) -> ZikrItem {
        let id: String? = content.id
        var descriptor = FetchDescriptor<ZikrItem>(predicate: #Predicate { $0.libraryID == id })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            if let target, target != existing.target {
                existing.target = target
                existing.count = min(existing.count, max(0, target - 1))
            }
            return existing
        }
        let item = ZikrItem(content: content, target: target)
        context.insert(item)
        return item
    }

    /// Counts one recitation. Returns true when this tap completed a round.
    @discardableResult
    func increment(in context: ModelContext) -> Bool {
        count += 1
        totalCount += 1
        updatedAt = .now
        DailyTally.add(1, in: context)
        ZikrDayCount.add(1, itemID: id, in: context)
        guard target > 0, count >= target else { return false }
        rounds += 1
        count = 0
        return true
    }

    /// Takes back the last recitation (also across a finished round).
    func undo(in context: ModelContext) {
        guard totalCount > 0 else { return }
        if count > 0 {
            count -= 1
        } else if rounds > 0 {
            rounds -= 1
            count = max(0, target - 1)
        }
        totalCount -= 1
        DailyTally.add(-1, in: context)
        ZikrDayCount.add(-1, itemID: id, in: context)
    }

    /// Recitations left in the current round.
    var remaining: Int { target > 0 ? max(0, target - count) : 0 }

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

/// Recitations of one zikr on one day, for per-zikr daily, weekly, monthly
/// and yearly totals.
@Model
final class ZikrDayCount {
    /// "<zikr id>|<yyyy-MM-dd>"
    @Attribute(.unique) var key: String
    var itemID: UUID
    var day: String
    var total: Int

    init(itemID: UUID, day: String, total: Int) {
        self.key = "\(itemID.uuidString)|\(day)"
        self.itemID = itemID
        self.day = day
        self.total = total
    }

    static func add(_ delta: Int, itemID: UUID, in context: ModelContext) {
        let day = DailyTally.key()
        let key = "\(itemID.uuidString)|\(day)"
        var descriptor = FetchDescriptor<ZikrDayCount>(predicate: #Predicate { $0.key == key })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.total = max(0, existing.total + delta)
        } else if delta > 0 {
            context.insert(ZikrDayCount(itemID: itemID, day: day, total: delta))
        }
    }
}
