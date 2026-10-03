import pymupdf, sys
d = pymupdf.open('Livro-dos-Espiritos.pdf')
for pi in [int(x) for x in sys.argv[1:]]:
    p = d[pi]
    print('=== page index', pi, p.rect)
    for b in p.get_text('dict')['blocks']:
        if b['type'] != 0: continue
        for l in b['lines']:
            s = l['spans']
            print(round(l['bbox'][0]), round(l['bbox'][1]), '|', '; '.join(f"{x['font'][:18]}/{x['size']:.1f}/{x['flags']}" for x in s[:2]), '|', ''.join(x['text'] for x in s)[:70])
