"""Builds the single-page app. Run from this folder: python3 build.py
Tafsir folders (ik, mx, zkb, mxb) are read from ./tafsir or $TAFSIR_DIR."""
import json, gzip, base64, os
HERE = os.path.dirname(os.path.abspath(__file__))
TAF = os.environ.get("TAFSIR_DIR") or next(d for d in (os.path.join(HERE, "tafsir"), os.path.join(HERE, "..", "tafsir")) if os.path.isdir(d))
SRC = "app.html" if os.path.exists(os.path.join(HERE, "app.html")) and not os.path.exists(os.path.join(HERE, "app5.html")) else "app5.html"
app = open(os.path.join(HERE, SRC), encoding="utf8").read()
r = lambda f: open(os.path.join(HERE, f), encoding="utf8").read()
j = lambda f: json.load(open(os.path.join(HERE, f), encoding="utf8"))
dump = lambda v: json.dumps(v, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
gz = lambda b: base64.b64encode(gzip.compress(b, 9)).decode()
taf = {ed: {s: gz(open(os.path.join(TAF, ed, f"{s}.json"), "rb").read()) for s in range(1, 115)} for ed in ("ik", "mx", "zkb", "mxb")}
parts = {
    "/*DATA*/": dump({"hisn": j("hisn.json"), "names": j("names.json")}),
    "/*REFLECTIONS*/": r("reflections.js"), "/*MORE*/": r("more_topics.js"),
    "/*SOURCES*/": r("sources.js"), "/*QURAN*/": r("quran.js"), "/*ART*/": r("art.js"),
    "/*HISN_BN_TITLES*/": dump(j("hisn_bn_titles.json")), "/*HADITH_BN*/": dump(j("hadith_bn.json")),
    "/*QURAN_BN*/": json.dumps(gz(open(os.path.join(HERE, "quran_bn.json"), "rb").read())),
    "/*TAFSIR_GZ*/": json.dumps(taf),
}
out = app
for k, v in parts.items():
    assert out.count(k) == 1, k
    out = out.replace(k, v)
open(os.path.join(HERE, "zikr-counter.html"), "w", encoding="utf8").write(out)
open(os.path.join(HERE, "check.js"), "w", encoding="utf8").write(out[out.index("<script>") + 8:out.rindex("</script>")])
print(f"{len(out.encode()) / 1e6:.2f} MB")
