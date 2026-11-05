import json
app=open('app.html').read(); d=json.load(open('data.json'))
out=(app.replace('/*DATA*/',json.dumps(d,ensure_ascii=False).replace('</','<\\/'))
 .replace('/*REFLECTIONS*/',open('reflections.js').read()).replace('/*MORE*/',open('more_topics.js').read()).replace('/*HADITH*/',open('hadith.js').read()).replace('/*SOURCES*/',open('sources.js').read()).replace('/*ART*/',open('art.js').read()))
open('zikr-counter.html','w').write(out)
open('check.js','w').write(out[out.index('<script>')+8:out.rindex('</script>')])
print(len(out))
