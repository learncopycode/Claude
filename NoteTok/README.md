# NoteTok

Two versions, kept side by side:

| Folder | Version |
|---|---|
| [`v1/`](v1/) | The first NoteTok: notes as a TikTok-style feed of colourful "shorts", made from screenshots by AI. |
| [`v2/`](v2/) | Rebuilt from scratch in the Google Keep style: a notes grid (pinned / others, colours, checklists, labels, archive, search), notes open full screen as posts you swipe through (like, thoughts, share, edit), a Keep-style editor, a **daily review** that brings older notes back on a growing schedule (1, 3, 7, 16, 35, 90 days), and a pinch-zoom **mind map**. Claude (✨) reads screenshots, tidies notes and links them. |

v2 is `v2/app.html` (the page as published in Claude); `python3 v2/build.py` wraps it into `v2/index.html`
for GitHub Pages and the home screen. Nothing on the page zooms except the mind map, and every text field is
16px or larger so iPhone doesn't zoom in while typing.
