# NoteTok ⚡ — your notes, TikTok style

A personal note-taking app that feels like TikTok. Paste a screenshot, and AI
turns it into a vivid, animated "note short" you can scroll through like a feed.

## Features

- **📸 Paste a screenshot** anywhere (Ctrl/Cmd+V), drop an image, or type text —
  Claude reads it and writes a punchy title, summary, key takeaways, and picks a
  vivid gradient theme, emoji, and floating particles to match the mood.
- **🏷️ AI-suggested tags** — the AI proposes tags for every note; you tap to
  confirm the ones you want (or add your own) before saving.
- **📱 TikTok-style feed** — full-screen vertical scroll with snap, animated
  gradients, Ken Burns screenshot motion, staggered caption reveals, a progress
  bar, double-tap-to-like heart bursts, and a right-side action rail.
- **🎯 Categories on top** — a horizontally scrollable chip bar (like TikTok's
  For You / Following) filters the feed by the category AI assigned each note.
- **🔍 Search** — full-text search over titles, summaries, extracted screenshot
  text, key points, and `#tags` (type `#tag` to search tags only).
- **🕸️ Mind map** — a separate view where AI analyzes all your notes together
  and links related ones. Force-directed canvas graph: drag nodes, scroll to
  zoom, tap a node to open that note in the feed. Works instantly with
  shared-tag links; the "✨ AI: link my notes" button upgrades them with Claude.
- **🌗 View toggle** — the grid icon (top right) or the bottom nav switches
  between the TikTok feed and a calm, classic notes grid.
- **📤 Share a short** — the rail's share button renders the note into a
  1080×1920 story-format image (gradient, screenshot, title, key points, tags)
  and opens the native share sheet, or downloads the PNG on desktop.
- **▶ Auto-scroll** — the play button (top right) plays through your feed
  hands-free, advancing every 8 seconds and looping back to the top.
- **⌨️ Keyboard nav** — arrow keys (or j/k) flip between shorts on desktop.
- **📲 Installable PWA** — a manifest + service worker make it installable to
  a phone home screen and keep the app shell working offline.

## Running it

It's a buildless static app — just serve the folder:

```bash
python3 -m http.server 8080
# or: npx serve .
```

Then open <http://localhost:8080>. (A server is needed because the app uses ES
modules; opening `index.html` directly from disk won't load them.)

## AI setup

Open **Setup** in the bottom nav and paste an Anthropic API key
(`sk-ant-…`). The key is stored only in your browser's localStorage and sent
only to `api.anthropic.com` (using the API's direct-browser-access CORS mode).
The app uses the `claude-opus-5` model for:

1. **Screenshot/text analysis** — vision + text → title, summary, key points,
   extracted text, suggested tags, category, and a visual theme.
2. **Note linking** — all note digests → mind-map connections with reasons.

**No key? No problem.** The app falls back to a built-in analyzer (first-line
title, keyword tags, shared-tag mind-map links) so everything still works —
just less magical.

## Storage & privacy

Everything lives in your browser: notes and screenshots in IndexedDB, the API
key in localStorage. Nothing is uploaded anywhere except the AI calls to
Anthropic when a key is configured.

## Project layout

```
index.html        app shell, modals
css/styles.css    all styling + animations
js/app.js         glue: nav, categories, search, settings, seeding
js/store.js       IndexedDB note store + settings
js/ai.js          Claude API calls + local fallbacks
js/feed.js        TikTok-style feed
js/notes.js       classic notes grid
js/mindmap.js     force-directed canvas mind map
js/capture.js     paste → analyze → confirm tags → save flow
js/share.js       render a short to a story-format PNG for sharing
sw.js             service worker (offline app shell)
manifest.webmanifest, icon.svg   PWA install metadata
```

---

## Also in this repo: Zikr (iPhone app)

[`ZikrApp/`](ZikrApp/README.md) is a native SwiftUI tasbih/zikr counter with a
free on-device AI that finds duas, surahs and adhkar and adds them to a counter.
See [ZikrApp/README.md](ZikrApp/README.md) to run it.
