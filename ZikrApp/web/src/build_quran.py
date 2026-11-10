"""Bundle the whole Quran for the reader: Uthmani Arabic (QuranEnc / King Fahd Complex),
Saheeh International English and Tanzil transliteration, from the quran-json package.
Usage: build_quran.py <quran-json dist dir> <out quran.js>"""
import json, os, sys
qdir, out = sys.argv[1:3]
FIX = str.maketrans({"ٗ": "ࣰ", "ٞ": "ࣱ", "ٖ": "ࣲ"})  # standard open-tanwin marks
meta, text = [], []
for n in range(1, 115):
    d = json.load(open(os.path.join(qdir, "chapters", "en", f"{n}.json"), encoding="utf8"))
    meta.append([d["name"], d["transliteration"], d["translation"], d["total_verses"], d["type"]])
    text.append([[v["text"].translate(FIX), v["translation"], v["transliteration"]] for v in d["verses"]])
assert sum(m[3] for m in meta) == 6236
js = ("/* The Quran: Uthmani text (QuranEnc, King Fahd Complex), Saheeh International, Tanzil transliteration. Generated. */\n"
      f"const QURAN_META = {json.dumps(meta, ensure_ascii=False, separators=(',', ':'))};\n"
      f"const QURAN_TEXT = {json.dumps(text, ensure_ascii=False, separators=(',', ':'))};\n")
open(out, "w", encoding="utf8").write(js)
print("ayahs", sum(len(t) for t in text), "size MB", round(len(js.encode()) / 1e6, 2))
