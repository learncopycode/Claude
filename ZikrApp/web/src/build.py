import json
app = open('app.html', encoding='utf8').read()
d = {"hisn": json.load(open('hisn.json', encoding='utf8')), "names": json.load(open('names.json', encoding='utf8'))}
r = lambda f: open(f, encoding='utf8').read()
out = (app.replace('/*DATA*/', json.dumps(d, ensure_ascii=False).replace('</', '<\\/'))
       .replace('/*REFLECTIONS*/', r('reflections.js')).replace('/*MORE*/', r('more_topics.js'))
       .replace('/*SOURCES*/', r('sources.js')).replace('/*QURAN*/', r('quran.js')).replace('/*ART*/', r('art.js')))
open('zikr-counter.html', 'w', encoding='utf8').write(out)
open('check.js', 'w', encoding='utf8').write(out[out.index('<script>') + 8:out.rindex('</script>')])
print(len(out))
