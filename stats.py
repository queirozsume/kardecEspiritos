import pymupdf, collections
d = pymupdf.open('Livro-dos-Espiritos.pdf')
c = collections.Counter(); ex = {}
for pi in range(54, 484):
    for b in d[pi].get_text('dict')['blocks']:
        if b['type'] != 0: continue
        for l in b['lines']:
            sp = l['spans']
            k = (sp[0]['font'][:22], round(sp[0]['size'], 1), sp[0]['flags'], round(l['bbox'][0]/10)*10 if sp[0]['size']<12 else 0)
            c[k] += 1
            ex.setdefault(k, (pi, ''.join(x['text'] for x in sp)[:60]))
for k, v in c.most_common(60):
    print(v, k, ex[k])
