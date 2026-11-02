import SwiftUI

/// Each zikr's card slowly travels through a series of colors: every swipe
/// moves it 1% of the way to the next color, so 100 recitations complete
/// one color. Reaching a new color unlocks it as an achievement.
enum HueJourney {
    struct Stop {
        let name: String
        let title: String
        let flavor: String
        let hue: Double        // 0...360
        let saturation: Double // 0...1
        let brightness: Double // 0...1

        var color: Color { Color(hue: hue / 360, saturation: saturation, brightness: brightness) }
    }

    static let recitationsPerColor = 100

    /// Stop 0 is where every zikr starts; each later stop is an achievement.
    static let stops: [Stop] = [
        Stop(name: "Mint", title: "First Step", flavor: "Every journey begins with one recitation.", hue: 150, saturation: 0.50, brightness: 0.80),
        Stop(name: "Teal", title: "Steady Heart", flavor: "A hundred times — the start of a habit.", hue: 172, saturation: 0.58, brightness: 0.74),
        Stop(name: "Sky", title: "Open Sky", flavor: "Your remembrance is becoming part of your day.", hue: 198, saturation: 0.55, brightness: 0.82),
        Stop(name: "Sapphire", title: "Deep Calm", flavor: "Steady and unhurried, like deep water.", hue: 220, saturation: 0.58, brightness: 0.80),
        Stop(name: "Indigo", title: "Quiet Night", flavor: "Remembering when the world is still.", hue: 242, saturation: 0.50, brightness: 0.78),
        Stop(name: "Violet", title: "Soft Light", flavor: "Five hundred — a light that keeps growing.", hue: 266, saturation: 0.45, brightness: 0.80),
        Stop(name: "Orchid", title: "In Bloom", flavor: "What you plant with patience begins to flower.", hue: 292, saturation: 0.42, brightness: 0.80),
        Stop(name: "Rose", title: "Tender Heart", flavor: "A softened heart, turned toward its Lord.", hue: 334, saturation: 0.45, brightness: 0.85),
        Stop(name: "Coral", title: "Warm Glow", flavor: "Warmth that others can feel around you.", hue: 10, saturation: 0.52, brightness: 0.90),
        Stop(name: "Amber", title: "Golden Hour", flavor: "The light of a day well spent.", hue: 32, saturation: 0.62, brightness: 0.92),
        Stop(name: "Gold", title: "The Thousand", flavor: "One thousand recitations. A true companion of this dhikr.", hue: 46, saturation: 0.62, brightness: 0.90),
        Stop(name: "Olive", title: "Deep Roots", flavor: "Roots that hold firm in every season.", hue: 75, saturation: 0.45, brightness: 0.74),
        Stop(name: "Emerald", title: "Evergreen", flavor: "Lasting, like a tree that never loses its leaves.", hue: 135, saturation: 0.55, brightness: 0.70),
    ]

    /// Index of the color a count has fully reached (0 = start).
    static func tier(for total: Int) -> Int { max(0, total) / recitationsPerColor }

    /// The stop for a tier; after the last one the journey loops with "II", "III"…
    static func stop(forTier tier: Int) -> Stop {
        if tier < stops.count { return stops[tier] }
        let cycleLength = stops.count - 1
        let index = (tier - 1) % cycleLength + 1
        let cycle = (tier - 1) / cycleLength + 1
        let base = stops[index]
        return Stop(
            name: "\(base.name) \(roman(cycle))",
            title: base.title,
            flavor: base.flavor,
            hue: base.hue, saturation: base.saturation, brightness: base.brightness
        )
    }

    /// The card color for a total: blended between the current and next color.
    static func color(for total: Int) -> Color {
        let level = tier(for: total)
        let fraction = Double(max(0, total) % recitationsPerColor) / Double(recitationsPerColor)
        let from = stop(forTier: level)
        let to = stop(forTier: level + 1)
        // Travel the short way around the color wheel.
        var delta = to.hue - from.hue
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var hue = from.hue + delta * fraction
        if hue < 0 { hue += 360 }
        if hue >= 360 { hue -= 360 }
        return Color(
            hue: hue / 360,
            saturation: from.saturation + (to.saturation - from.saturation) * fraction,
            brightness: from.brightness + (to.brightness - from.brightness) * fraction
        )
    }

    /// Two-tone gradient for a card footer.
    static func gradient(for total: Int) -> [Color] {
        let base = color(for: total)
        return [base, base.opacity(0.78)]
    }

    struct Achievement: Identifiable, Equatable {
        let tier: Int
        let zikrTitle: String
        var id: Int { tier }
        var stop: Stop { HueJourney.stop(forTier: tier) }
        var count: Int { tier * HueJourney.recitationsPerColor }

        var headline: String { "\(stop.name) · \(stop.title)" }
        var description: String { "\(count.formatted()) × \(zikrTitle). \(stop.flavor)" }

        static func == (a: Achievement, b: Achievement) -> Bool { a.tier == b.tier && a.zikrTitle == b.zikrTitle }
    }

    private static func roman(_ number: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var n = number + 1 // first loop is "II"
        var out = ""
        for (value, symbol) in table {
            while n >= value {
                out += symbol
                n -= value
            }
        }
        return out
    }
}
