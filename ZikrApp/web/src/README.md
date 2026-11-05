# Web build sources

- `app.html` – the app shell, styles and logic
- `data.json` – the dua library and the 99 Names
- `reflections.js`, `more_topics.js` – reflection topics; `hadith.js` – which hadith backs each dhikr
- `art.js` – animated illustrations (shapes only, no faces)
- `sources.js` – **generated**: authentic Quran and hadith text for every reference

## Refreshing authentic texts

`sources.js` is produced by `pull_sources.py` from:
- Quran: the npm package `quran-json` (Uthmani text from QuranEnc / King Fahd Complex,
  Saheeh International English, Tanzil transliteration)
- Hadith: the npm package `hadith` (the sunnah.com collection data: Arabic, English, grading)

```bash
npm pack quran-json@3.1.2 && tar xzf quran-json-3.1.2.tgz -C qj
npm pack hadith && tar xzf hadith-*.tgz -C hadith
python3 pull_sources.py . qj/package/dist hadith/package/data/hadith.db sources.js
python3 build.py   # writes the single-page app
```
The script keeps each cited hadith number and prints any whose wording differs a lot
from the summary, so they can be checked by hand.
