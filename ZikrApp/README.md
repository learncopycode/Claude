# Zikr — tasbih counter with a free, built-in AI

A native iPhone app (SwiftUI) for counting dhikr, with an AI assistant that
finds any dua, surah or zikr you ask for and drops it straight into a counter.

## What it does

- **Ask AI tab** — type in your own words: *"dua for anxiety"*, *"Ayat al-Kursi"*,
  *"Surah Al-Mulk"*, *"istighfar 100 times"*, *"2:285-286"*, *"the three Quls"*.
  The assistant finds it, shows the Arabic, transliteration, translation and
  source, and **Add to counter** puts it in a counter (with the count you asked
  for, e.g. 100).
- **Counter tab** — tap anywhere to count, with a progress ring, rounds
  (e.g. 33 per round), haptics, undo, reset, custom targets and the screen kept
  awake. Shows today's total, your daily streak and your all-time total.
  One tap adds the after-prayer tasbih (33 SubhanAllah · 33 Alhamdulillah · 33 Allahu Akbar).
- **Library tab** — 41 authentic duas and adhkar in 8 categories, plus all 114
  surahs of the Quran.
- Custom zikr with your own text and target. Everything is saved on the phone.

## The AI is free

- **On-device AI**: on iPhones with Apple Intelligence (iPhone 15 Pro or newer,
  iOS 26+), the app uses Apple's built-in Foundation Models. It's free, needs no
  account or API key, runs offline and keeps your requests private.
- **Smart search** on every other iPhone (iOS 17+): a built-in matcher that
  understands topics, surah names, verse numbers and "x times". The app always
  works, with or without Apple Intelligence.
- **Quran text** comes from the free [AlQuran Cloud API](https://alquran.cloud/api)
  (Uthmani script, Saheeh International translation, transliteration). No key needed.

**The AI never writes religious text.** It only understands what you want and
picks from the verified library or a Quran reference. Every Arabic word comes
from the bundled library (each entry cites its hadith or Quran source) or from
the Quran API, so the AI cannot misquote a dua or verse.

## Run it on your iPhone

You need a Mac with **Xcode 26** (free from the Mac App Store; Xcode 16 also
works but without the on-device AI).

1. Open `ZikrApp/Zikr.xcodeproj` in Xcode.
2. Click the **Zikr** project → **Signing & Capabilities** → pick your Apple ID
   under *Team* (a free Apple ID works). If needed, change the bundle ID
   `com.example.zikr` to something unique, e.g. `com.yourname.zikr`.
3. Plug in your iPhone (or pick a simulator) and press **Run** (⌘R).
4. On the iPhone, the first time: *Settings → General → VPN & Device Management*
   → trust your developer certificate. Also turn on *Developer Mode* if asked.

To use the on-device AI, turn on **Apple Intelligence** in iPhone Settings. The
Ask AI tab shows which mode is active.

## Code map

```
Zikr/
  ZikrApp.swift                 App entry, tab router
  Models/ZikrItem.swift         Saved counters + daily totals (SwiftData)
  Models/DuaContent.swift       A dua / Quran passage and its categories
  Data/DuaLibrary.swift         Verified duas with sources — add more here
  Data/QuranIndex.swift         114 surahs, verse counts, verse ranges
  Services/AssistantService.swift  On-device AI (Foundation Models)
  Services/LocalMatcher.swift   Smart search fallback + exact reference parsing
  Services/QuranService.swift   Free Quran API client with caching
  Views/                        Counter, Ask AI, Library, detail screens
```

To add a dua, add a `make(...)` entry in `Data/DuaLibrary.swift` with its
source and topic tags. The AI picks it up automatically.
