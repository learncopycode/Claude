"""Dhikr found inside Hisn al-Muslim's narrations (the "excellence of ..." entries), as counters.
The book marks the words to say in brackets. Arabic: the bracketed phrases in the sunnah.com text;
transliteration and meaning: the bracketed phrases in hisnmuslim.com's English edition, at the places where
the transliteration and the translation differ (identical brackets are just the translator's notes).
The repeat count is hisnmuslim.com's REPEAT. Nothing is reworded.
Usage: build_hisn_virtues.py <hisn.json> <dir with en<chapter>.json> <out hisn_virtues.json>"""
import json, re, sys, os
hisn_p, api_dir, out_p = sys.argv[1:4]
hisn = json.load(open(hisn_p, encoding="utf8"))
api = {}
for f in os.listdir(api_dir):
    if re.fullmatch(r"en\d+\.json", f):
        d = json.load(open(os.path.join(api_dir, f), encoding="utf-8-sig"))
        for items in d.values():
            for it in items: api[int(it["ID"])] = it
AR = re.compile(r"[؀-ۿ]")
def inner(t):
    t = (t or "").strip()
    if t.startswith("(") and t.endswith(")"): t = t[1:-1]
    return re.findall(r"\(([^()]+)\)", t)
out, skipped = [], []
for e in hisn:
    if e["recite"] or not re.fullmatch(r"\d+", e["n"]): continue
    it = api.get(int(e["n"]))
    if not it: skipped.append((e["n"], "not on hisnmuslim.com")); continue
    lat, en = inner(it.get("LANGUAGE_ARABIC_TRANSLATED_TEXT")), inner(it.get("TRANSLATED_TEXT"))
    pairs = [(a.strip(), b.strip()) for a, b in zip(lat, en) if a.strip() != b.strip()] if len(lat) == len(en) else []
    ar = [s.strip() for s in re.findall(r"\(([^()]+)\)", e["arabic"]) if AR.search(s)]
    if not pairs or not ar: skipped.append((e["n"], f"brackets ar={len(ar)} lat={len(lat)} en={len(en)}")); continue
    out.append({"id": "v" + e["n"], "n": e["n"], "ch": e["ch"], "chapter": e["chapter"],
                "arabic": "، ".join(ar), "translit": " ".join(p[0] for p in pairs), "meaning": " ".join(p[1] for p in pairs),
                "count": int(it.get("REPEAT") or 1), "virtue": re.sub(r"^\(|\)$", "", (it.get("TRANSLATED_TEXT") or "").strip()), "ref": e["ref"]})
json.dump(out, open(out_p, "w", encoding="utf8"), ensure_ascii=False, indent=0)
print(len(out), "dhikr from narrations;", len(skipped), "left as narrations")
for o in out: print(f" #{o['n']:>4} ×{o['count']:<3} {o['arabic'][:50]} | {o['translit'][:60]} | {o['meaning'][:60]}")
print("skipped:", skipped)
