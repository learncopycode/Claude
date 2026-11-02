import Foundation

/// What the assistant decided to show for a request.
struct AssistantPlan {
    var duas: [DuaContent] = []
    var quran: [QuranRequest] = []
    /// Times the user asked to recite ("100 times", "x33"), if any.
    var repetitions: Int? = nil
    var note: String = ""
    var usedAI = false

    var isEmpty: Bool { duas.isEmpty && quran.isEmpty }
}

/// What the assistant suggests for a new collection.
struct CollectionSuggestion {
    var title: String
    var items: [DuaContent]
    var note: String
    var usedAI: Bool
}

/// Offline, rule-based understanding of requests. Runs on every iPhone and
/// is also used to double-check exact Quran references the AI returns.
enum LocalMatcher {
    static func plan(for query: String) -> AssistantPlan {
        let quran = quranRequests(in: query)
        let duas = searchDuas(query) + searchNames(query)
        var plan = AssistantPlan(duas: duas, quran: quran, repetitions: repetitions(in: query))
        let total = duas.count + quran.count
        plan.note = total == 0
            ? "I couldn't find a match. Try words like \"anxiety\", \"morning adhkar\", \"Ayat al-Kursi\" or \"Surah Al-Mulk\"."
            : "Here \(total == 1 ? "is what I found" : "are \(total) matches") from verified sources. Tap “Add to counter” to start."
        return plan
    }

    // MARK: Repetitions

    static func repetitions(in query: String) -> Int? {
        let patterns = [
            #"(\d{1,5})\s*(?:x\b|×|times?\b)"#,
            #"\bx\s*(\d{1,5})\b"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(pattern, in: query).flatMap({ Int($0) }), value > 0 {
                return min(value, 100_000)
            }
        }
        return nil
    }

    // MARK: Quran

    private static let keywords = ["surah", "surat", "sura", "suratul", "surah-", "chapter"]
    private static let articles: Set<String> = ["al", "an", "ar", "as", "at", "az", "ad", "ash", "adh", "ath", "el", "ul"]

    /// Names people commonly use without saying "surah".
    private static let aliases: [(phrases: [String], requests: [QuranRequest])] = [
        (["ayatul kursi", "ayat al kursi", "ayat ul kursi", "ayatal kursi", "ayat kursi", "kursi", "throne verse"],
         [QuranRequest(surah: 2, fromAyah: 255, toAyah: 255)]),
        (["last two ayat", "last 2 ayat", "last two verses of baqarah", "last two verses of al baqarah",
          "amana rasul", "amanar rasul", "aamanar rasool", "end of baqarah"],
         [QuranRequest(surah: 2, fromAyah: 285, toAyah: 286)]),
        (["three quls", "3 quls", "the quls", "four quls", "4 quls", "muawwidhat", "mu'awwidhat", "muawwidhatayn"],
         [QuranRequest(surah: 112), QuranRequest(surah: 113), QuranRequest(surah: 114)]),
        (["yasin", "yaseen", "ya sin", "ya-sin", "yaa seen"], [QuranRequest(surah: 36)]),
        (["mulk", "tabarak"], [QuranRequest(surah: 67)]),
        (["kahf", "kahaf"], [QuranRequest(surah: 18)]),
        (["waqiah", "waqia", "waqiyah", "waqi'ah"], [QuranRequest(surah: 56)]),
        (["fatiha", "fatihah", "faatiha", "fatehah", "al hamd surah"], [QuranRequest(surah: 1)]),
        (["ikhlas", "ikhlaas", "qul huwallahu"], [QuranRequest(surah: 112)]),
        (["falaq"], [QuranRequest(surah: 113)]),
        (["sajdah", "as sajda"], [QuranRequest(surah: 32)]),
        (["al imran", "ali imran", "aal imran", "aal e imran", "aale imran"], [QuranRequest(surah: 3)]),
    ]

    private static let surahKeys: [(key: String, number: Int)] = QuranIndex.surahs.map { surah in
        let parts = surah.name.lowercased()
            .split(whereSeparator: { $0 == "-" || $0 == " " })
            .map(String.init)
        let meaningful = parts.count > 1 && articles.contains(normalize(parts[0])) ? Array(parts.dropFirst()) : parts
        return (normalize(meaningful.joined()), surah.number)
    }

    static func quranRequests(in query: String) -> [QuranRequest] {
        var results: [QuranRequest] = []
        func add(_ r: QuranRequest?) {
            if let r, !results.contains(r) { results.append(r) }
        }
        let lower = " " + query.lowercased().replacingOccurrences(of: "’", with: "'") + " "

        // "2:255", "2:285-286"
        for match in allMatches(#"(\d{1,3})\s*:\s*(\d{1,3})(?:\s*[-–]\s*(\d{1,3}))?"#, in: lower) {
            guard let s = Int(match[0]), let from = Int(match[1]) else { continue }
            add(QuranRequest.valid(surah: s, from: from, to: Int(match[2]) ?? from))
        }

        // "surah 67", "chapter 18"
        for match in allMatches(#"\b(?:surah|surat|sura|chapter)\s*(?:no\.?|number|#)?\s*(\d{1,3})\b(?!\s*:)"#, in: lower) {
            if let n = Int(match[0]) { add(QuranRequest.valid(surah: n)) }
        }

        // Well-known names
        let cleaned = lower.replacingOccurrences(of: "-", with: " ")
        for alias in aliases where alias.phrases.contains(where: { cleaned.contains(" \($0)") || cleaned.contains("\($0) ") }) {
            alias.requests.forEach { add($0) }
        }

        // "surah al-mulk", "surat yusuf"
        let words = cleaned
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        for (index, word) in words.enumerated() where keywords.contains(word) || word.hasPrefix("surat") {
            var tail = Array(words.dropFirst(index + 1).prefix(4))
            if word.count > 5, word.hasPrefix("suratul") { tail.insert(String(word.dropFirst(7)), at: 0) }
            while let first = tail.first, articles.contains(first) { tail.removeFirst() }
            for length in stride(from: min(3, tail.count), through: 1, by: -1) {
                let key = normalize(tail.prefix(length).joined())
                if let hit = surahKeys.first(where: { $0.key == key }) {
                    add(QuranRequest(surah: hit.number))
                    break
                }
            }
        }
        return results
    }

    /// Lowercase ASCII letters only, with doubled letters and a trailing "h"
    /// removed so "Al-Baqarah", "baqara" and "baqqarah" all match.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en"))
            .lowercased()
            .replacingOccurrences(of: "ee", with: "i")
            .replacingOccurrences(of: "oo", with: "u")
        var out = ""
        var last: Character?
        for c in folded where c.isASCII && c.isLetter {
            if c != last { out.append(c) }
            last = c
        }
        if out.count > 3, out.hasSuffix("h") { out.removeLast() }
        return out
    }

    // MARK: Duas

    private static let stopWords: Set<String> = [
        "dua", "duas", "doa", "dhikr", "zikr", "zikir", "the", "for", "and", "with", "when", "what", "give",
        "show", "find", "want", "need", "please", "me", "my", "some", "about", "times", "time", "can",
        "you", "that", "this", "say", "read", "recite", "supplication", "prayer", "add", "counter",
        "count", "help", "get", "from", "how", "after", "before",
    ]

    static func searchDuas(_ query: String, limit: Int = 5) -> [DuaContent] {
        let lower = query.lowercased()
        let tokens = lower
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        let compact = normalize(lower)

        var scored: [(DuaContent, Int)] = []
        for dua in DuaLibrary.all {
            var score = 0
            // Phrase tags like "after prayer" or "laylatul qadr".
            for tag in dua.tags where tag.contains(" ") && lower.contains(tag) { score += 5 }
            for token in tokens {
                if dua.tags.contains(where: { $0 == token || ($0.count >= 4 && token.count >= 4 && ($0.hasPrefix(token) || token.hasPrefix($0))) }) {
                    score += 3
                }
                if dua.title.lowercased().contains(token) { score += 2 }
                if dua.translation.lowercased().contains(token) { score += 1 }
            }
            // Typed transliteration, e.g. "subhanallah wa bihamdihi".
            let translit = normalize(dua.transliteration)
            if compact.count >= 6, translit.hasPrefix(compact) || compact.contains(normalize(dua.title)) {
                score += compact == normalize(dua.title) ? 12 : 6
            }
            if score > 0 { scored.append((dua, score)) }
        }
        let sorted = scored.sorted { $0.1 > $1.1 }
        guard let best = sorted.first?.1 else { return [] }
        // Drop weak matches when there are strong ones.
        return sorted.filter { $0.1 * 3 >= best }.prefix(limit).map { $0.0 }
    }

    // MARK: 99 Names

    /// Finds names like "Ya Razzaq" or "al-wadud".
    static func searchNames(_ query: String, limit: Int = 3) -> [DuaContent] {
        let lower = query.lowercased()
        let words = lower
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.letters.inverted.subtracting(CharacterSet(charactersIn: "'")))
            .filter { !$0.isEmpty && !articles.contains($0) && $0 != "ya" }
        let keys = Set(words.map(normalize).filter { $0.count >= 3 })
        guard !keys.isEmpty else { return [] }
        return AllahNames.all.filter { name in
            let parts = name.transliteration.lowercased()
                .split(whereSeparator: { $0 == "-" || $0 == " " })
                .map(String.init)
                .filter { !articles.contains($0) }
            let key = normalize(parts.joined())
            return keys.contains(key)
        }
        .prefix(limit)
        .map { $0 }
    }

    // MARK: Regex helpers

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        allMatches(pattern, in: text).first?.first
    }

    /// Capture groups for each match (empty string for groups that didn't take part).
    private static func allMatches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            (1..<max(match.numberOfRanges, 1)).map { i in
                Range(match.range(at: i), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }
}
