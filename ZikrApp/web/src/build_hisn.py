"""Hisn al-Muslim (Fortress of the Muslim) from the sunnah.com dataset (npm package "hadith").
Arabic, transliteration and English are taken verbatim; the English field holds
"transliteration. translation. Reference: ..." and is split here (no words are changed).
Usage: build_hisn.py <hadith.db> <out hisn.json>"""
import json, re, sqlite3, sys
db, out = sys.argv[1:3]
cur = sqlite3.connect(db).cursor()
chapters = {r[0]: r[1] for r in cur.execute("select id, title_en from chapter where collection_id=300")}
rows = cur.execute("select urn, display_number, chapter_id, content from hadith where collection_id=300").fetchall()
EN = {r[0]: r[1] for r in cur.execute("select arabic_urn, content from hadith_en where collection_id=300")}
MAC = re.compile(r"[āīūḥṣḍṭẓĀĪŪḤṢḌṬẒ`ʿ]")   # transliteration marks only (not English apostrophes)
ENGLISH = set("in the of to and i you your my is me glory praise o there seek name forgiveness we our he his him be with for from on upon by who what all none has have not no as at it this that are am lord".split())
def is_translit_word(w): return bool(MAC.search(w))
START = set("O In I Whoever Praise Glory There And Our My All None May He His We You Allah Lord Say Seek Grant Forgive Have".split())
def word_split(text):
    """Split 'translit English...' at the first capitalised English word after the transliteration."""
    w = text.split()
    for i in range(1, len(w)):
        word = re.sub(r"[^A-Za-z]", "", w[i])
        nxt = [re.sub(r"[^a-z]", "", x.lower()) for x in w[i:i + 3]]
        starts = word in START and not is_translit_word(w[i])
        englishy = sum(x in ENGLISH for x in nxt) >= 2 and not is_translit_word(w[i]) and w[i][:1].isupper()
        if (starts or englishy) and any(is_translit_word(x) or x[:1].islower() for x in w[:i]):
            return " ".join(w[:i]), " ".join(w[i:])
    return "", text
def split(en):
    en = re.sub(r"\s+", " ", en or "").strip(); ref = ""
    m = re.search(r"\bReference:\s*", en)
    if m: ref, en = en[m.end():].strip(), en[:m.start()].strip()
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z(“\"'\[])", en); tl, rest = [], []
    for p in parts:
        dens = len(MAC.findall(p)) / max(1, len(p.split()))
        (tl if (not rest and dens >= 0.25) else rest).append(p)
    tl, tr = " ".join(tl), " ".join(rest)
    if tl and (not tr or sum(re.sub(r"[^a-z]", "", x.lower()) in ENGLISH and x[:1].isupper() for x in tl.split()) >= 1):
        a, b = word_split(tl)
        if a: tl, tr = a, (b + " " + tr).strip()
    elif not tl and tr and re.match(r"^[A-Z][a-z]+ (And|In|O|I|May) [a-z]", tr) and tr.split()[0].lower() not in ENGLISH:
        tl, tr = tr.split(" ", 1)   # a one-word dua such as "Walaka And you."
    elif not tl and tr and is_translit_word(tr.split()[0]): tl, tr = word_split(tr)
    return tl, tr, ref
def count_of(ar, tr):
    ar = re.sub(r"[\u064b-\u065f\u0670]", "", ar)   # ignore harakat when reading "three times" etc.
    m = re.search(r"(\d+|one hundred|three|seven|ten|four|thirty-three)\s+times", tr, re.I)
    words = {"one hundred": 100, "three": 3, "seven": 7, "ten": 10, "four": 4, "thirty-three": 33}
    if m: v = m.group(1).lower(); return int(v) if v.isdigit() else words[v]
    if "مائة" in ar or "مئة" in ar: return 100
    if "ثلاثاً" in ar or "ثلاثا" in ar or "ثلاث مرات" in ar: return 3
    if re.search(r"سبع(ا|اً)?\s*مرات|\(سبعا", ar): return 7
    return 1
NARRATIVE = set("the you your said says whoever messenger prophet who will him his for planted paradise most beloved words excellent invocation deeds which endure accepted islam".split())
key = lambda r: (int(re.match(r"\d+", r[1]).group()), r[1])
out_list = []
for urn, dn, ch, ar in sorted(rows, key=key):
    tl, tr, ref = split(EN.get(urn, ""))
    # Narrations with a dhikr embedded in them stay whole, as written.
    if tl and (sum(re.sub(r"[^a-z]", "", x.lower()) in NARRATIVE for x in tl.split()) >= 3 or not any(is_translit_word(x) for x in tl.split())):
        tl, tr = "", (tl + " " + tr).strip()
    ar = (ar or "").replace("ـ", "").replace("‏", "").strip()   # drop tatweel and RTL marks only
    out_list.append({"id": f"h{dn}", "n": dn, "ch": ch, "chapter": chapters.get(ch, ""), "arabic": ar, "translit": tl,
                     "meaning": tr, "ref": ref, "count": count_of(ar, tr), "recite": bool(tl)})
json.dump(out_list, open(out, "w", encoding="utf8"), ensure_ascii=False)
rec = [e for e in out_list if e["recite"]]
print("entries", len(out_list), "recitable", len(rec), "chapters", len({e["ch"] for e in out_list}))
REAL_EN = set("the you your my me glory praise seek name forgiveness our his him with from upon who what none have not this that are said says whoever messenger".split())
sus = [e for e in out_list if e["recite"] and (e["meaning"][:1].islower() or sum(re.sub(r"[^a-z]", "", x.lower()) in REAL_EN for x in e["translit"].split()) >= 2)]
print("suspicious after split:", [(e["n"], e["translit"][-30:], e["meaning"][:30]) for e in sus])
for n in ["9", "11", "18", "33", "73", "153", "171", "197"]:
    e = next(x for x in out_list if x["n"] == n); print(f" #{n}: TL[{e['translit'][:60]}] TR[{e['meaning'][:60]}] x{e['count']}")
