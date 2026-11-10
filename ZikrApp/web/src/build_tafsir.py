"""Pack English tafsir for the reader, one file per surah, loaded on demand.
Source: spa5k/tafsir_api (data from Quran.com / Tarteel QUL):
  en-tafisr-ibn-kathir    Tafsir Ibn Kathir (abridged English)
  en-tafsir-al-mukhtasar  Al-Mukhtasar, Tafsir Center for Quranic Studies
Ibn Kathir repeats one passage for every ayah it covers, so each file stores the
passages once ("p") plus, per ayah, the index of its passage ("m").
Usage: build_tafsir.py <downloaded tafsir dir> <out dir>"""
import json, os, sys
src, out = sys.argv[1:3]
for slug, short in [("en-tafisr-ibn-kathir", "ik"), ("en-tafsir-al-mukhtasar", "mx")]:
    os.makedirs(os.path.join(out, short), exist_ok=True); total = 0
    for s in range(1, 115):
        ayahs = sorted(json.load(open(os.path.join(src, slug, f"{s}.json"), encoding="utf8")), key=lambda x: x["ayah"])
        passages, index, m = [], {}, []
        for a in ayahs:
            t = a["text"].strip()
            if t not in index: index[t] = len(passages); passages.append(t)
            m.append(index[t])
        data = json.dumps({"p": passages, "m": m}, ensure_ascii=False, separators=(",", ":"))
        open(os.path.join(out, short, f"{s}.json"), "w", encoding="utf8").write(data); total += len(data.encode())
    print(short, f"{total / 1e6:.1f} MB")
