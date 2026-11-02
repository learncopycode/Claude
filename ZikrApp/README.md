# Zikr — tasbih counter with a free, built-in AI

A native iPhone app (SwiftUI) for counting dhikr, with an AI assistant that
finds any dua, surah or zikr you ask for and drops it straight into a counter.

## What it does

- **Ask AI tab** — type in your own words: *"dua for anxiety"*, *"Ayat al-Kursi"*,
  *"Surah Al-Mulk"*, *"istighfar 100 times"*, *"2:285-286"*, *"the three Quls"*.
  The assistant finds it, shows the Arabic, transliteration, translation and
  source, and **Add to counter** puts it in a counter (with the count you asked
  for, e.g. 100).
- **Counter tab** — a dark home screen with your counters, then sections you
  can open or expand: **99 Names of Allah**, **Dhikrs**, **Duas**,
  **Duas from the Quran**, **Quran** (all 114 surahs) and **Collections**.
  Tapping any item opens its counter straight away.
- **Two swipe modes** (your choice is remembered):
  - **Zikr feed** — your zikrs as TikTok-style cards. Read one, swipe up:
    +1 goes to that zikr and the next zikr rises up. Swipe down to go back.
  - **Single zikr** — the same card every time; each swipe flies the card
    away with a "+1" and counts. Tapping the card also counts.
  Collections use the same swipe deck and move to the next dhikr by themselves.
  Every count — from either mode or a collection — goes into that zikr's own
  counter and history.
- **Stats tab** — today, this week, this month, this year and all-time totals
  for all zikrs, with a chart, plus each zikr's share; tap a zikr for its own
  five totals and chart.
- **Counter screen** — the dua on a black card (Arabic, transliteration,
  translation, source) above a big mint tap panel. Shows "N left", has a tap
  sound toggle, share, full-screen mode, undo, reset, custom targets, rounds,
  haptics, and keeps the screen awake.
- **Collections** — guided sets that move to the next dhikr automatically:
  tasbih after salah, morning and evening protection, surahs before bed
  (3 times), daily forgiveness and barakah, and all 99 Names in order.
- **Today, streak and all-time totals** on the home screen.
- **Library tab** — search everything; Ayat al-Kursi and the three Quls are
  bundled so they work offline.
- **Add new zikr (with AI)** — the + button opens Zikr / Dua / Collection tabs.
  Start typing a dua in English letters in **Title** ("rabbana atina",
  "hasbunallah", "astagfirullah" — any spelling) and matches appear instantly
  with their Arabic; one tap fills in the Arabic, transcription, translation
  and source. For plain-English requests, tap **Ask AI**: type a few words
  ("dua for exams", "SubhanAllah 100 times") and the AI fills
  in the title, Arabic, transcription, translation, source and count from
  verified sources — every field stays editable, and other matches are one tap
  away. In **Collection**, describe it ("morning protection", "before sleep")
  and the AI picks the zikrs; tick more from the lists, adjust counts, save.
- Everything is saved on the phone.

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
