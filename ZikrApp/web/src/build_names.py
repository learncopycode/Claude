"""The 99 Names exactly as listed in Jami' at-Tirmidhi 3507 (sunnah.com dataset).
English gives "meaning (Transliteration)" pairs; Arabic gives the names in the same order.
Usage: build_names.py <hadith.db> <out names.json>"""
import json, re, sqlite3, sys
db, out = sys.argv[1:3]; cur = sqlite3.connect(db).cursor()
urn, ar, grades = cur.execute("select urn, content, grades from hadith where collection_id=30 and display_number='3507'").fetchone()
en, en_grades = cur.execute("select content, grades from hadith_en where arabic_urn=?", (urn,)).fetchone()
en = re.sub(r"\s+", " ", en)
# Each item is "meaning (optional clarification) (Transliteration)"; the last bracket is the transliteration.
first = re.search(r"He is (Allah, the one whom there is none worthy of worship except for Him) \((Allāhu Lā Ilāha Illā Huwa)\),", en)
items = re.findall(r"((?:[^,()]|\([^()]*\))*?)\s*\(([^()]*)\)\s*(?=,|\.|”|$)", en[first.end():])
pairs = [(first.group(1), first.group(2))] + [(re.sub(r"^(and )", "", m.strip()), t.strip()) for m, t in items if m.strip()]
INVISIBLE = "".join(map(chr, [0x200E, 0x200F]))
letters = lambda w: re.sub("[^" + chr(0x621) + "-" + chr(0x64A) + "]", "", w)
allw = [w for w in re.split(r"\s+", ar.translate({ord(c): None for c in INVISIBLE})) if w]
start = next(i for i, w in enumerate(allw) if letters(w) == "الرحمن")
allah = next(i for i, w in enumerate(allw) if letters(w) == "الله")
start = next(i for i, w in enumerate(allw) if letters(w) == "الرحمن")
allah = next(i for i, w in enumerate(allw) if letters(w) == "الله")
words = allw[start:]
JOIN = {"مالك": 2, "ذو": 3}   # Malik al-Mulk, Dhul-Jalali wal-Ikram
names, i = [], 0
while i < len(words) and len(names) < 99:
    n = JOIN.get(letters(words[i]), 1); names.append(" ".join(words[i:i + n])); i += n
names = [" ".join(allw[allah:start])] + [re.sub(r"[.\u06D4\u060C]+$", "", x) for x in names][:98]
print("english pairs", len(pairs), "arabic names", len(names))
gr = en_grades or grades
try: g = json.loads(gr)[0]
except Exception: g = {"grade": str(gr or ""), "graded_by": ""}
out_list = [{"id": f"name-{k + 1}", "n": k + 1, "arabic": names[k], "translit": pairs[k][1], "meaning": pairs[k][0][0].upper() + pairs[k][0][1:]} for k in range(99)]
json.dump({"names": out_list, "ref": "Jami` at-Tirmidhi 3507", "url": "https://sunnah.com/tirmidhi:3507",
           "grade": " ".join(x for x in [g.get("grade", "").strip(), f"({g.get('graded_by', '').strip()})" if g.get("graded_by", "").strip() else ""] if x)}, open(out, "w", encoding="utf8"), ensure_ascii=False)
for k in [0, 1, 46, 64, 83, 84, 98]: print(k + 1, out_list[k]["arabic"], "|", out_list[k]["translit"], "|", out_list[k]["meaning"])
