"""Duas and dhikr from hadith, as published (nothing reworded).
1. HadeethEnc (Encyclopedia of Translated Prophetic Hadiths, hadeethenc.com): the "Supplications and remembrance"
   section, the merits of supplication and the dhikr said in prayer; Arabic, English and Bangla, grade, explanation
   and lessons. Where a hadith plainly quotes a dua ("he used to say: «...»"), that quote is also kept on its own
   (Arabic and English exactly as in the hadith) so the counter can show just the dua.
2. Sahih al-Bukhari, Book of Invocations (80), and Sahih Muslim, Book of Remembrance (48), from the sunnah.com data,
   with the Bangla text from the Bangla editions (fawazahmed0/hadith-api) where it matches by Arabic.
Usage: build_hadith_lib.py <hadeethenc dir> <hadith.db> <hbn dir> <out.json>"""
import json, os, re, sqlite3, sys
he_dir, db, hbn, out = sys.argv[1:5]
strip = lambda t: re.sub(r"[ً-ٰٟـ]", "", t or "")
OPEN_AR = re.compile(r"^\s*(اللهم|ربي?|ربنا|رب |يا |سبحان|لا إله|لا حول|أعوذ|اعوذ|بسم|الحمد|أستغفر|استغفر|حسبي|رضيت|أصبحنا|أمسينا|آمنت|اللَّهُمَّ)")
SAY_AR = re.compile(r"(يقول|يدعو|قال|قل|قولوا|فقل|فليقل|دعا|يتعوذ|تعوذ|يكثر أن يقول|كان يقول|ثم قال|ثم يقول)\s*:?\s*[^«]{0,12}$")
OPEN_EN = re.compile(r"^\s*['‘“\"]?\s*(O Allah|Allāhumma|Allahumma|My Lord|Our Lord|O Turner|O Ever|O Possessor|Glory|Glorified|There is no|There is none|None has|I seek|In the name|Bismillāh|All praise|Praise|I ask|I testify|Allah is|How perfect|Subhān|Subhan|Lā ilāha|La ilaha|La hawla|Lā hawla|Astaghfir|I am pleased|Rabbi|Rabbana|Yā )", re.I)
cats = {c["id"]: c for c in json.load(open(os.path.join(he_dir, "cats_en.json")))}
cats_bn = {c["id"]: c["title"] for c in json.load(open(os.path.join(he_dir, "cats_bn.json")))}
ids = json.load(open(os.path.join(he_dir, "ids.json")))
he = []
for hid, root in ids.items():
    if root == 211: continue
    try:
        en = json.load(open(os.path.join(he_dir, "one", f"{hid}_en.json"))); bn = json.load(open(os.path.join(he_dir, "one", f"{hid}_bn.json")))
        if not isinstance(bn, dict): bn = {}
    except Exception: continue
    cat = next((c for c in en.get("categories", []) if c in cats and cats[c]["parent_id"] in ("268", "265", "134")), en.get("categories", [""])[0])
    e = {"id": "he" + hid, "src": int(hid), "cat": cat, "title": en["title"], "title_bn": bn.get("title", ""), "ar": en["hadeeth_ar"], "en": en["hadeeth"], "bn": bn.get("hadeeth", ""),
         "attr": en.get("attribution", ""), "attr_bn": bn.get("attribution", ""), "grade": en.get("grade", ""), "grade_bn": bn.get("grade", ""),
         "expl": en.get("explanation", ""), "expl_bn": bn.get("explanation", ""), "hints": [h.strip() for h in en.get("hints", []) if h.strip()], "hints_bn": [h.strip() for h in bn.get("hints", []) if h.strip()]}
    # the dua itself, when the hadith plainly quotes one
    ar_q = None
    for m in re.finditer(r"«([^«»]+)»", e["ar"]):
        if SAY_AR.search(strip(e["ar"][:m.start()])[-40:]) and OPEN_AR.search(strip(m.group(1))): ar_q = m.group(1).strip(); break
    en_q = None
    for m in re.finditer(r"[\"“]([^\"“”]+)[\"”]", e["en"]):
        if OPEN_EN.search(m.group(1)): en_q = m.group(1).strip(); break
    if ar_q and en_q:
        tl = ""
        mm = re.match(r"^(.*?)\s*\((.+)\)\s*[.]?$", en_q, re.S)   # "Allāhumma ... (O Allah, ...)": transliteration, then meaning
        if mm and re.search(r"[āīūḥṣḍṭẓ‘’]", mm.group(1)) and len(mm.group(2)) > 12: tl, en_q = mm.group(1).strip(), mm.group(2).strip()
        e.update({"dua_ar": ar_q.rstrip("،,. "), "dua_en": en_q, "dua_tl": tl})
    he.append(e)
he.sort(key=lambda e: (e["cat"], e["src"]))
cat_out = {c: {"en": cats[c]["title"] if c in cats else "", "bn": cats_bn.get(c, "")} for c in {e["cat"] for e in he}}
# Bukhari 80 and Muslim 48
cur = sqlite3.connect(db).cursor()
join = lambda *t: " ".join(x.strip() for x in t if x and x.strip())
EN = {r[0]: join(r[1], r[2], r[3]) for r in cur.execute("select arabic_urn, narrator_prefix, content, narrator_postfix from hadith_en where collection_id in (1,2)")}
CH = {(r[0], r[1], r[2]): (r[3] or "").strip() for r in cur.execute("select collection_id, book_id, id, title_en from chapter where collection_id in (1,2)")}
norm = lambda t: re.sub(r"[^ء-ي]", "", strip(t)).replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ى", "ي").replace("ة", "ه")
def ed(lang, c): return {h["hadithnumber"]: h["text"] for h in json.load(open(os.path.join(hbn, f"{lang}-{c}.json"), encoding="utf8"))["hadiths"]}
sahih = []
for cid, book, col, slug, prefix in ((1, 80, "Sahih al-Bukhari", "bukhari", "bk"), (2, 48, "Sahih Muslim", "muslim", "ms")):
    ara, ben = ed("ara", slug), ed("ben", slug)
    ara_n = {k: norm(v) for k, v in ara.items()}
    for urn, num, ch, ar, pre, post in cur.execute("select urn, display_number, chapter_id, content, narrator_prefix, narrator_postfix from hadith where collection_id=? and book_id=? order by order_in_book", (cid, book)).fetchall():
        en = (EN.get(urn) or "").strip()
        if not ar or not en: continue
        key = norm(ar)[-120:] if len(norm(ar)) > 40 else norm(ar)
        hits = [k for k, v in ara_n.items() if key and key in v]
        bn = ""
        if len(hits) == 1:
            t = (ben.get(hits[0]) or "").strip()
            bnum = str(hits[0]).translate(str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯"))
            mk = re.search(re.escape(bnum) + r"\.\s", t)
            if mk and mk.start() > 0: t = t[mk.end():]
            t = t.lstrip("।.,;: ")
            if t and not t.startswith("(…/…)") and "অবিকল" not in t[:200] and not re.match(r"[(ء-يً-ْ\s]{25,}", t): bn = t
        num = num.replace(" ", ""); sahih.append({"id": f"{prefix}{num}", "col": col, "num": num, "chapter": CH.get((cid, book, ch), ""), "ar": join(pre, ar, post).replace("\u200f", ""), "en": en, "bn": bn,
                      "url": f"https://sunnah.com/{slug}:{num}"})
json.dump({"he": he, "he_cats": cat_out, "sahih": sahih}, open(out, "w", encoding="utf8"), ensure_ascii=False, separators=(",", ":"))
print("HadeethEnc", len(he), "with a clear dua", sum(1 for e in he if e.get("dua_ar")), "| Bukhari/Muslim", len(sahih), "with Bangla", sum(1 for s in sahih if s["bn"]))
for e in [x for x in he if x.get("dua_ar")][:8]: print(" ", e["id"], e["dua_ar"][:45], "|", e.get("dua_tl", "")[:30], "|", e["dua_en"][:60])
