import Foundation

/// A guided set of adhkar recited one after another, e.g. the tasbih after salah.
struct ZikrCollection: Identifiable, Hashable {
    struct Step: Hashable {
        let content: DuaContent
        let count: Int
    }

    let id: String
    let title: String
    let subtitle: String
    let steps: [Step]
    /// How many times the whole set is repeated (e.g. the Quls 3 times before sleep).
    var cycles: Int = 1

    var totalCount: Int { steps.reduce(0) { $0 + $1.count } * cycles }
}

enum Collections {
    static func collection(id: String) -> ZikrCollection? {
        all.first { $0.id == id } ?? (id == namesCollection.id ? namesCollection : nil)
    }

    private static func steps(_ items: [(String, Int)]) -> [ZikrCollection.Step] {
        items.compactMap { id, count in
            DuaLibrary.dua(id: id).map { ZikrCollection.Step(content: $0, count: count) }
        }
    }

    static let all: [ZikrCollection] = [
        ZikrCollection(
            id: "after-salah",
            title: "Tasbih after salah",
            subtitle: "33 · 33 · 33, then the tahlil and Ayat al-Kursi",
            steps: steps([
                ("astaghfirullah", 3),
                ("subhanallah", 33),
                ("alhamdulillah", 33),
                ("allahuakbar", 33),
                ("tahlil-complete", 1),
                ("quran-2:255", 1),
            ])
        ),
        ZikrCollection(
            id: "morning-evening",
            title: "Morning and evening adhkar for protection",
            subtitle: "From the Quran and authentic hadith",
            steps: steps([
                ("quran-2:255", 1),
                ("quran-112", 3),
                ("quran-113", 3),
                ("quran-114", 3),
                ("sayyid-istighfar", 1),
                ("bismillah-la-yadurr", 3),
                ("raditu", 3),
                ("hasbiyallah", 7),
                ("auzu-bikalimat", 3),
                ("subhanallahi-wa-bihamdihi", 100),
            ])
        ),
        ZikrCollection(
            id: "before-sleep",
            title: "Surahs to read before going to bed",
            subtitle: "Repeat 3 times",
            steps: steps([
                ("quran-112", 1),
                ("quran-113", 1),
                ("quran-114", 1),
            ]),
            cycles: 3
        ),
        ZikrCollection(
            id: "barakah",
            title: "Daily adhkar for forgiveness and barakah",
            subtitle: "Istighfar, salawat and remembrance",
            steps: steps([
                ("astaghfirullah-atubu", 100),
                ("salawat", 10),
                ("hawqala", 33),
                ("tahlil-complete", 10),
                ("afiyah", 3),
            ])
        ),
    ]

    /// Recite all 99 Names once each.
    static let namesCollection = ZikrCollection(
        id: "99-names",
        title: "Recite all 99 Names",
        subtitle: "One tap per name",
        steps: AllahNames.all.map { ZikrCollection.Step(content: $0, count: 1) }
    )
}
