import re
L = open('raw.txt', encoding='utf-8').read().split('\n')
for i, l in enumerate(L):
    if re.match(r'^\s*(LIVRO|CAPÍTULO|PARTE|CONCLUSÃO|INTRODUÇÃO|PROLEGÔMENOS|Livro|Parte|Capítulo)\b', l):
        print(i, repr(l), '|', repr(L[i+1]) if i+1 < len(L) else '')
