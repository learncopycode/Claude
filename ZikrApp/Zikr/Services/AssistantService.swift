import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The app's AI. It uses Apple's on-device model (Foundation Models, iOS 26+
/// with Apple Intelligence) — free, private and offline, no API key. On older
/// iPhones it falls back to the built-in smart search.
///
/// The model never writes religious text. It only understands the request
/// and picks entries from the verified library or a Quran reference; the
/// Arabic then comes from the library or the Quran API.
@MainActor
final class AssistantService: ObservableObject {
    enum Mode: Equatable {
        case onDeviceAI
        case smartSearch(reason: String)
    }

    @Published private(set) var mode: Mode = .smartSearch(reason: "")

    init() { refreshMode() }

    func refreshMode() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let reason = OnDeviceAI.unavailableReason {
                mode = .smartSearch(reason: reason)
            } else {
                mode = .onDeviceAI
            }
            return
        }
        #endif
        mode = .smartSearch(reason: "On-device AI needs iOS 26 with Apple Intelligence. Using smart search instead.")
    }

    func answer(_ query: String) async -> AssistantPlan {
        let local = LocalMatcher.plan(for: query)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), mode == .onDeviceAI {
            do {
                let ai = try await OnDeviceAI.plan(for: query)
                return merge(ai: ai, local: local)
            } catch {
                // Guardrails, context limits or a model hiccup: smart search still answers.
                return local
            }
        }
        #endif
        return local
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func merge(ai: AIPlan, local: AssistantPlan) -> AssistantPlan {
        var plan = AssistantPlan(usedAI: true)

        // Only keep IDs that really exist in the library.
        var seen = Set<String>()
        plan.duas = ai.duaIDs
            .compactMap { DuaLibrary.dua(id: $0.trimmingCharacters(in: .whitespaces)) }
            .filter { seen.insert($0.id).inserted }
        if plan.duas.count < 2 {
            for dua in local.duas where seen.insert(dua.id).inserted && plan.duas.count < 3 {
                plan.duas.append(dua)
            }
        }

        // Exact references typed by the user win over the model's guess.
        if !local.quran.isEmpty {
            plan.quran = local.quran
        } else if ai.surah > 0, let request = QuranRequest.valid(
            surah: ai.surah,
            from: ai.fromAyah > 0 ? ai.fromAyah : nil,
            to: ai.toAyah > 0 ? ai.toAyah : nil
        ) {
            plan.quran = [request]
        }

        plan.repetitions = local.repetitions ?? (ai.repetitions > 0 ? min(ai.repetitions, 100_000) : nil)
        if plan.isEmpty { return local }

        let note = ai.note.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.note = note.isEmpty ? local.note : note
        return plan
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct AIPlan {
    @Guide(description: "IDs from the catalog that fit the request, best first. At most 4. Use only IDs that appear in the catalog. Empty if the user only wants Quran.")
    var duaIDs: [String]

    @Guide(description: "Surah number from 1 to 114 if the user wants a surah or Quran verses, otherwise 0.")
    var surah: Int

    @Guide(description: "First verse number if the user wants specific verses, otherwise 0 for the whole surah.")
    var fromAyah: Int

    @Guide(description: "Last verse number for a range, otherwise 0.")
    var toAyah: Int

    @Guide(description: "How many times the user wants to recite it, or 0 if they did not say.")
    var repetitions: Int

    @Guide(description: "One short, warm sentence in English about why these fit. Do not quote Arabic, verses or translations.")
    var note: String
}

@available(iOS 26.0, *)
enum OnDeviceAI {
    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return "This iPhone doesn't support Apple Intelligence. Using smart search instead."
            case .appleIntelligenceNotEnabled:
                return "Turn on Apple Intelligence in Settings to use the on-device AI. Using smart search for now."
            case .modelNotReady:
                return "The on-device AI model is still downloading. Using smart search for now."
            @unknown default:
                return "On-device AI is unavailable. Using smart search instead."
            }
        }
    }

    private static let instructions: String = {
        let catalog = DuaLibrary.all
            .map { "\($0.id): \($0.title) — \($0.tags.prefix(6).joined(separator: ", "))" }
            .joined(separator: "\n")
        return """
        You help Muslims find duas, dhikr and Quran passages to recite and count.
        Pick the best matches for the user's request from this catalog of authentic adhkar \
        (format "id: title — topics"):
        \(catalog)

        Rules:
        - Only return IDs from the catalog. Never invent IDs.
        - If the user names a surah or verses (for example Ayat al-Kursi is surah 2 verse 255, \
        the last two verses of Al-Baqarah are 2:285-286, Surah Al-Mulk is 67, Ya-Sin is 36), \
        fill in the surah and verse numbers.
        - For feelings or situations (anxiety, exams, travel, sleep, parents, forgiveness), \
        choose the catalog entries made for them.
        - Never write Arabic text, Quran verses or hadith wording yourself.
        """
    }()

    static func plan(for query: String) async throws -> AIPlan {
        // A fresh session per request keeps the context small.
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: query, generating: AIPlan.self)
        return response.content
    }
}
#endif
