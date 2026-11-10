"""Bundle the whole Quran for the reader: Uthmani Arabic (QuranEnc / King Fahd Complex),
Saheeh International English and Tanzil transliteration, from the quran-json package.
Transliteration: Quran.com word-by-word data (npm @kmaslesa/holy-quran-word-by-word-full-data),
which uses the standard scheme (dh for ذ, th for ث, ʿ for ع, ā ī ū for long vowels).
Usage: build_quran.py <quran-json dist dir> <word-by-word data.json> <out quran.js>"""
import json, os, sys, collections
qdir, wbw, out = sys.argv[1:4]
words = collections.defaultdict(list)
for page in json.load(open(wbw, encoding="utf8")):
    for ayah in page["ayahs"]:
        for w in ayah["words"]:
            if w.get("char_type_name") == "word": words[w["parentAyahVerseKey"]].append((w["position"], w["transliteration"]["text"]))
translit = {k: " ".join(t for _, t in sorted(v)) for k, v in words.items()}
assert len(translit) == 6236
FIX = str.maketrans({"ٗ": "ࣰ", "ٞ": "ࣱ", "ٖ": "ࣲ"})  # standard open-tanwin marks
meta, text = [], []
for n in range(1, 115):
    d = json.load(open(os.path.join(qdir, "chapters", "en", f"{n}.json"), encoding="utf8"))
    meta.append([d["name"], d["transliteration"], d["translation"], d["total_verses"], d["type"]])
    text.append([[v["text"].translate(FIX), v["translation"], translit[f"{n}:{v['id']}"]] for v in d["verses"]])
assert sum(m[3] for m in meta) == 6236
js = ("/* The Quran: Uthmani text (QuranEnc, King Fahd Complex), Saheeh International, Quran.com transliteration. Generated. */\n"
      f"const QURAN_META = {json.dumps(meta, ensure_ascii=False, separators=(',', ':'))};\n"
      f"const QURAN_TEXT = {json.dumps(text, ensure_ascii=False, separators=(',', ':'))};\n")
open(out, "w", encoding="utf8").write(js)
print("ayahs", sum(len(t) for t in text), "size MB", round(len(js.encode()) / 1e6, 2))
