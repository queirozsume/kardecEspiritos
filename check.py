import json, sys
d = json.load(open('data.json', encoding='utf-8'))
Q = {q['n']: q for q in d['questions']}
for n in (1, 51, 59, 148, 919, 1019):
    q = Q[n]
    print(json.dumps(q, ensure_ascii=False)[:900]); print()
print('empty a:', [n for n, q in Q.items() if not q['a']][:30])
print('empty q:', [n for n, q in Q.items() if not q['q']][:30])
print('long q:', [n for n, q in Q.items() if len(q['q']) > 400][:30])
print('a without quote:', [n for n, q in Q.items() if q['a'] and q['a'][0] not in '“"'][:40])
print('texts', len(d['texts']), [(t['chapter'], t['after'], len(t['p']), t['p'][0][:50] if t['p'] else '') for t in d['texts']][:25])
for k, v in d['sections'].items():
    print(k, len(v), [(i['label'], len(i['p'])) for i in v][:20])
print(d['sections']['introd'][0]['p'][:2])
print(d['sections']['concl'][-1]['p'][-2:])
print(d['sections']['nota'][0]['p'][:2])
for e in d['index'][:3] + d['index'][100:103]:
    print(json.dumps(e, ensure_ascii=False)[:500])
print([ (e['term'], e['subs'][:2]) for e in d['index'] if any(r[0]=='x' for r in e['refs']) ][:5])
xs = [(e['term'], s['label'], s['refs']) for e in d['index'] for s in e['subs'] if any(r[0] == 'x' for r in s['refs'])]
print(len(xs), xs[:10])
print([e['term'] for e in d['index']][-15:])
for ch in d['parts'][1]['chapters'][:2]: print(ch)
