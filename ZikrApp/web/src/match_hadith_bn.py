"""Find the Bangla text for each hadith in sources.js, from fawazahmed0/hadith-api.
The cited number is located in the Arabic edition by matching our sunnah.com Arabic matn
(search near the cited number), then the Bangla edition's text at that number is taken as is.
Usage: match_hadith_bn.py <sources.js> <hbn dir> <out hadith_bn.json>"""
import json, re, sys, difflib
src, d, out = sys.argv[1:4]
txt = open(src, encoding='utf8').read()
H = json.loads(re.search(r"const HADITH_SRC = (\{.*?\});\s*$", txt, re.S | re.M).group(1))
COL = {"Sahih al-Bukhari": "bukhari", "Sahih Muslim": "muslim", "Jami‘ at-Tirmidhi": "tirmidhi", "Sunan Abi Dawud": "abudawud", "Sunan Ibn Majah": "ibnmajah"}
norm = lambda t: re.sub(r"[^ء-ي]", "", re.sub(r"[ً-ٰٟـ]", "", t or "")).replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي").replace("ة", "ه")
cache = {}
def ed(lang, c):
    k = lang + c
    if k not in cache:
        cache[k] = {}
        for h in json.load(open(f"{d}/{lang}-{c}.json", encoding="utf8"))["hadiths"]:
            cache[k].setdefault(h["hadithnumber"], h["text"])
    return cache[k]
res = {}
for ref, h in H.items():
    col = next((v for k, v in COL.items() if ref.startswith(k)), None)
    if not col: print("skip", ref); continue
    num = int(re.search(r"(\d+)", ref.split(" ")[-1]).group(1)); key = norm(h["ar"])
    ara, ben = ed("ara", col), ed("ben", col)
    best = (0, None)
    for n in range(num - 60, num + 61):
        for cand in [k for k in ara if int(k) == n]:
            a = norm(ara[cand])
            if not a: continue
            if key and key in a: score = 1.0
            else: score = difflib.SequenceMatcher(None, key, a[-len(key) * 2:] if key else a).ratio() if key else 0
            score -= abs(n - num) * 0.0005
            if score > best[0]: best = (score, cand)
    if best[0] < 0.9 and key:   # numbering differs (e.g. Sahih Muslim): search the whole book for the exact matn
        hits = [k for k, t in ara.items() if key in norm(t)]
        hits.sort(key=lambda k: -len(ben.get(k) or ""))   # several chains: take the full narration
        if hits: best = (0.95 if len(hits) == 1 else 0.9, hits[0])
    bt = (ben.get(best[1]) or "").strip() if best[1] is not None else ""
    chain_only = bt.startswith("(…/…)") or "অবিকল" in bt[:200] or "এ সূত্রে" in bt[:160]
    # Some entries open with the chapter's own notes before the hadith. The edition marks where the
    # hadith begins with its number in Bangla digits ("৪৫৬৯."), so the text is taken from there.
    if best[1] is not None:
        bnum = str(best[1]).translate(str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯"))
        mk = re.search(re.escape(bnum) + r"\.\s", bt)
        if mk and mk.start() > 0: bt = bt[mk.end():]
    bt = bt.lstrip("।.,;: ")
    has_chapter_notes = bool(re.match(r"[(\u0621-\u064a\u064b-\u0652\s]{25,}", bt))   # still opens with Arabic notes
    ok = best[0] > 0.6 and bt and not chain_only and not has_chapter_notes
    print(f"{ref:28} -> {best[1]} score {best[0]:.2f}", "" if ok else "  ** NO MATCH")
    if ok: res[ref] = {"bn": bt, "src": f"fawazahmed0/hadith-api ben-{col} #{best[1]}"}
json.dump(res, open(out, "w", encoding="utf8"), ensure_ascii=False)
print(len(res), "of", len(H))
