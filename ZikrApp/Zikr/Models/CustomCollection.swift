import Foundation
import SwiftData

/// A collection the user built (by hand or with the AI). Saved on the device.
@Model
final class CustomCollection {
    var id: UUID
    var title: String
    var createdAt: Date
    /// The steps, stored as JSON so Quran passages fetched online are kept offline too.
    var stepsData: Data

    init(title: String, steps: [ZikrCollection.Step]) {
        self.id = UUID()
        self.title = title
        self.createdAt = .now
        self.stepsData = (try? JSONEncoder().encode(steps.map(StoredStep.init))) ?? Data()
    }

    var steps: [ZikrCollection.Step] {
        let stored = (try? JSONDecoder().decode([StoredStep].self, from: stepsData)) ?? []
        return stored.map { ZikrCollection.Step(content: $0.content, count: $0.count) }
    }

    var asCollection: ZikrCollection {
        let list = self.steps
        return ZikrCollection(
            id: "custom-\(id.uuidString)",
            title: title,
            subtitle: "\(list.count) zikr\(list.count == 1 ? "" : "s") · made by you",
            steps: list
        )
    }
}

/// One step of a saved collection.
private struct StoredStep: Codable {
    let id: String
    let title: String
    let arabic: String
    let transliteration: String
    let translation: String
    let source: String
    let category: String
    let defaultCount: Int
    let count: Int

    init(_ step: ZikrCollection.Step) {
        let c = step.content
        id = c.id
        title = c.title
        arabic = c.arabic
        transliteration = c.transliteration
        translation = c.translation
        source = c.source
        category = c.category.rawValue
        defaultCount = c.defaultCount
        count = step.count
    }

    var content: DuaContent {
        DuaContent(
            id: id, title: title, arabic: arabic, transliteration: transliteration,
            translation: translation, source: source,
            category: DuaCategory(rawValue: category) ?? .tasbih,
            defaultCount: defaultCount
        )
    }
}
