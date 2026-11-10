"""Bangla data for the app, all taken from published sources (nothing translated by hand).
- Quran: Abu Bakr Zakaria's translation (King Fahd Complex), from fawazahmed0/quran-api
  (ben-abubakrzakaria). Only the footnote markers like [১] are removed.
- Hisn al-Muslim chapter titles: hisnmuslim.com (the site carries Bangla titles only).
- Tafsir: Tafsir Abu Bakr Zakaria (King Fahd Complex) and the Bengali Abridged Explanation
  (Al-Mukhtasar), from spa5k/tafsir_api, packed like build_tafsir.py.
Usage: build_bn.py <zak.json> <hisnmuslim bn page.html> <tafbn dir> <out dir>"""
import json, os, re, sys, html
zak, page, tafdir, out = sys.argv[1:5]
q = json.load(open(zak, encoding="utf8"))["quran"]
q.sort(key=lambda x: (x["chapter"], x["verse"]))
assert len(q) == 6236
clean = lambda t: re.sub(r"\s+([,।;?!])", r"\1", re.sub(r"\s*\[[০-৯0-9]+\]", "", t)).strip()
json.dump([clean(x["text"]) for x in q], open(os.path.join(out, "quran_bn.json"), "w", encoding="utf8"), ensure_ascii=False)
t = open(page, encoding="utf8").read()
# The page's chapter index links /i/bn/<k> to chapter k, except that links 0, 1 and 28 hold
# chapters 28, 27 and 1 (checked against the site's English titles).
links = dict((int(k), html.unescape(v).strip()) for k, v in re.findall(r'href="https://hisnmuslim.com/i/bn/(\d+)">\s*([^<]+?)\s*</a>', t)[:133][::-1])
SWAP = {28: 0, 27: 1, 1: 28}
titles = {}
for ch in range(1, 133):
    v = links.get(SWAP.get(ch, ch), "")
    v = re.sub(r"^[০-৯0-9]+\s*-\s*", "", v)
    if v: titles[ch] = v
json.dump(titles, open(os.path.join(out, "hisn_bn_titles.json"), "w", encoding="utf8"), ensure_ascii=False)
print("quran", len(q), "titles", len(titles))
for slug, short in [("bn-tafsir-abu-bakr-zakaria", "zkb"), ("bengali-mokhtasar", "mxb")]:
    os.makedirs(os.path.join(out, "tafsir", short), exist_ok=True)
    for s in range(1, 115):
        ayahs = sorted(json.load(open(os.path.join(tafdir, slug, f"{s}.json"), encoding="utf8")), key=lambda x: x["ayah"])
        p, idx, m = [], {}, []
        for a in ayahs:
            tx = a["text"].strip()
            if tx not in idx: idx[tx] = len(p); p.append(tx)
            m.append(idx[tx])
        json.dump({"p": p, "m": m}, open(os.path.join(out, "tafsir", short, f"{s}.json"), "w", encoding="utf8"), ensure_ascii=False, separators=(",", ":"))
