import pymupdf, re, json, sys

PDF = 'Livro-dos-Espiritos.pdf'
d = pymupdf.open(PDF)

ROMAN = {'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10, 'XI': 11, 'XII': 12}


def clean(s):
    return s.replace('\xad', '').replace('\t', ' ').replace('\u00a0', ' ')


def page_lines(pi):
    """Return list of lines, each a dict with spans [(cls, text)] and geometry."""
    out = []
    for b in d[pi].get_text('dict')['blocks']:
        if b['type'] != 0:
            continue
        for l in b['lines']:
            spans = [s for s in l['spans'] if s['text'].strip() != '' or True]
            if not spans:
                continue
            out.append({'spans': spans, 'x0': l['bbox'][0], 'x1': l['bbox'][2], 'y0': l['bbox'][1]})
    return out


def span_class(s, line_y):
    f, z, t = s['font'], round(s['size'], 1), s['text']
    if 'Myriad' in f:
        return 'note_num' if z < 6 else 'note'
    if 'Calligraphic' in f:
        return 'skip'
    if 'Garamond' in f:
        if z <= 7.5:
            return 'skip'  # superscript call-outs
        if z == 12 and 'Semibold' in f:
            return 'num'
        if z == 14 and 'Semibold' in f:
            return 'theme'
        if z == 12 and 'Italic' in f:
            return 'q'
        if z == 12:
            return 'body12'
        if z == 10:
            if line_y < 45 or line_y > 600:
                return 'skip'
            return 'c'
        if z == 11 and t.strip().upper().startswith('CAP'):
            return 'chapnum'
        if z == 28:
            return 'chaptitle'
        if z == 16:
            return 'bigtitle'
        if z in (40,):
            return 'parttitle'
        if z == 22:
            return 'partsub'
        return 'skip'
    return 'skip'


class Para:
    def __init__(self):
        self.lines = []  # (text, ends_paragraph)

    def add(self, text, end=False):
        text = clean(text).strip()
        if text:
            self.lines.append((text, end))

    def paragraphs(self):
        paras, cur = [], ''
        for text, end in self.lines:
            if cur:
                if cur.endswith('-') and text[:1].islower() and not cur.endswith(' -') and not cur.endswith('--'):
                    cur = cur[:-1] + text
                else:
                    cur += ' ' + text
            else:
                cur = text
            if end:
                paras.append(cur)
                cur = ''
        if cur:
            paras.append(cur)
        return paras

    def text(self):
        return ' '.join(self.paragraphs())


def join_lines(lines):
    p = Para()
    for l in lines:
        p.add(l)
    return p.text()


def tidy(s):
    s = re.sub(r'\s+', ' ', s).strip()
    s = re.sub(r'\s+([,.;:!?])', r'\1', s)
    return s


class Collector:
    """State machine that consumes classified spans across pages."""

    def __init__(self):
        self.parts = []
        self.blocks = []          # current chapter blocks
        self.cur = None           # current question dict or text block
        self.section = None       # 'q','a','c'
        self.note = None
        self.theme = ''
        self.qs = []
        self.chapter = None
        self.part = None
        self.page = 0

    def new_chapter(self, num, title):
        self.finish()
        if num == 1:
            idx = len(self.parts)
            self.part = {'id': idx + 1, 'title': self.pending_part_title, 'chapters': []}
            self.parts.append(self.part)
        self.chapter = {'id': f"{self.part['id']}.{num}", 'num': num, 'title': title, 'themes': []}
        self.part['chapters'].append(self.chapter)
        self.theme = ''
        self.cur = None
        self.section = None

    def finish(self):
        if self.cur is not None:
            self.close_cur()
        self.cur = None

    def close_cur(self):
        c = self.cur
        if c.get('kind') == 'q':
            for k in ('q', 'a', 'c'):
                pass
            c['q'] = tidy(c['_q'].text())
            c['a'] = tidy(c['_a'].text())
            c['c'] = [tidy(x) for x in c['_c'].paragraphs()]
            c['notes'] = [tidy(n.text()) for n in c['_notes']]
            for k in ('_q', '_a', '_c', '_notes', 'kind'):
                del c[k]
            self.qs.append(c)
        elif c.get('kind') == 'text':
            c['p'] = [tidy(x) for x in c['_c'].paragraphs()]
            c['notes'] = [tidy(n.text()) for n in c['_notes']]
            del c['_c'], c['_notes']
            self.chapter.setdefault('texts', []).append(
                {'theme': c['theme'], 'p': c['p'], 'notes': c['notes'], 'page': c['page'], 'after': c['after']})


def merge_spans(sp):
    out = []
    for k, s in sp:
        if out and out[-1][0] == k and k in ('num', 'q', 'theme', 'chaptitle'):
            out[-1] = (k, {**out[-1][1], 'text': out[-1][1]['text'] + s['text']})
        else:
            out.append((k, s))
    return out


def parse_body(c: Collector, first, last):
    last_q = 0
    for pi in range(first, last + 1):
        printed = pi + 1
        c.page = printed
        lines = page_lines(pi)
        if any(round(s['size']) == 40 for l in lines for s in l['spans']):
            # part divider page
            t = ' '.join(clean(s['text']).strip() for l in lines for s in l['spans'] if round(s['size']) == 22)
            c.pending_part_title = tidy(t)
            continue
        # right edge for paragraph detection
        right = {}
        for l in lines:
            for s in l['spans']:
                z = round(s['size'])
                if z in (10, 12):
                    right[z] = max(right.get(z, 0), l['x1'])
        chap_num, chap_title = None, []
        for l in lines:
            y = l['y0']
            sp = merge_spans([(span_class(s, y), s) for s in l['spans']])
            classes = {k for k, _ in sp}
            if 'chapnum' in classes:
                m = re.search(r'CAP\S*TULO\s+([IVX]+)', ''.join(s['text'] for _, s in sp))
                chap_num = ROMAN[m.group(1)]
                continue
            if 'chaptitle' in classes:
                chap_title.append(''.join(s['text'] for k, s in sp if k == 'chaptitle'))
                continue
            if chap_num is not None and 'chapnum_done' not in classes:
                if chap_title:
                    c.new_chapter(chap_num, tidy(join_lines(chap_title)))
                    chap_num, chap_title = None, []
            # chapter summary (bulleted) lines directly after title
            if getattr(c, 'in_summary', False):
                if classes <= {'body12', 'skip'} and c.cur is None and c.section is None:
                    continue
                c.in_summary = False
            if chap_num is None and chap_title:
                c.new_chapter(chap_num or 0, tidy(join_lines(chap_title)))
            for k, s in sp:
                t = s['text']
                if k == 'skip':
                    continue
                if k == 'theme':
                    c.finish()
                    c.section = None
                    c.theme = tidy(t)
                    if c.theme and (not c.chapter['themes'] or c.chapter['themes'][-1]['title'] != c.theme):
                        c.chapter['themes'].append({'title': c.theme, 'page': printed})
                    continue
                if k == 'num':
                    m = re.match(r'\s*(\d+)\.', t)
                    if m:
                        c.finish()
                        n = int(m.group(1))
                        c.cur = {'kind': 'q', 'n': n, 'part': c.part['id'], 'chapter': c.chapter['id'],
                                 'theme': c.theme, 'page': printed,
                                 '_q': Para(), '_a': Para(), '_c': Para(), '_notes': []}
                        c.section = 'q'
                        continue
                if k == 'q':
                    if c.cur is not None and c.cur.get('kind') == 'q' and c.section in ('q',):
                        c.cur['_q'].add(t)
                    else:
                        # italic emphasis inside comment text
                        add_text(c, t, l, right, 10)
                    continue
                if k in ('body12', 'c'):
                    z = 12 if k == 'body12' else 10
                    if k == 'body12' and c.cur is not None and c.cur.get('kind') == 'q' and c.section in ('q', 'a'):
                        c.section = 'a'
                        c.cur['_a'].add(t)
                    else:
                        add_text(c, t, l, right, z)
                    continue
                if k == 'note_num':
                    c.note = Para()
                    if c.cur is None:
                        c.cur = {'kind': 'text', 'theme': c.theme, 'page': printed, '_c': Para(), '_notes': [],
                                 'after': last_q}
                    c.cur['_notes'].append(c.note)
                    continue
                if k == 'note':
                    if c.note is None:
                        c.note = Para()
                        if c.cur is not None:
                            c.cur['_notes'].append(c.note)
                    c.note.add(t)
                    continue
            if 'chaptitle' in classes:
                c.in_summary = True
        if c.cur is not None and c.cur.get('kind') == 'q':
            last_q = c.cur['n']
    c.finish()


def add_text(c, t, l, right, z):
    """Add comment / free text to the current question or a free text block."""
    if c.cur is None:
        c.cur = {'kind': 'text', 'theme': c.theme, 'page': c.page, '_c': Para(), '_notes': [],
                 'after': c.qs[-1]['n'] if c.qs else 0}
    c.section = 'c'
    end = False
    stripped = t.rstrip()
    if stripped and l['x1'] < right.get(z, 0) - 30 and stripped[-1] in '.?!:”"»)' and l['spans'][-1]['text'] == t:
        end = True
    c.cur['_c'].add(t, end)
    if c.cur.get('kind') == 'q':
        pass


def parse_free(first, last, split_roman=True):
    """Introdução / Conclusão / Prolegômenos / Nota: items split by roman headings."""
    items, cur = [], {'label': '', 'p': Para(), 'page': first + 1}
    notes = []
    note = None
    for pi in range(first, last + 1):
        lines = page_lines(pi)
        right = max([l['x1'] for l in lines for s in l['spans'] if round(s['size']) == 12 and 'Garamond' in s['font']] or [0])
        for l in lines:
            for s in l['spans']:
                k = span_class(s, l['y0'])
                t = s['text']
                if k == 'theme' and split_roman and re.fullmatch(r'[IVXL]+', t.strip()):
                    if cur['p'].lines or cur['label']:
                        items.append(cur)
                    cur = {'label': t.strip(), 'p': Para(), 'page': pi + 1}
                elif k in ('body12', 'c', 'q', 'num', 'theme'):
                    if k == 'theme':
                        cur['p'].add(t, True)
                        continue
                    end = False
                    st = t.rstrip()
                    if st and l['x1'] < right - 30 and st[-1] in '.?!:”"»)' and l['spans'][-1]['text'] == t:
                        end = True
                    cur['p'].add(t, end)
                elif k == 'note_num':
                    note = Para()
                    notes.append((cur['label'], note))
                elif k == 'note':
                    if note is None:
                        note = Para()
                        notes.append((cur['label'], note))
                    note.add(t)
    if cur['p'].lines or cur['label']:
        items.append(cur)
    out = []
    for it in items:
        out.append({'label': it['label'], 'page': it['page'], 'p': [tidy(x) for x in it['p'].paragraphs()],
                    'notes': [tidy(n.text()) for lab, n in notes if lab == it['label']]})
    return out


def find_page(pattern, start, end):
    for pi in range(start, end):
        for l in page_lines(pi):
            tx = ''.join(s['text'] for s in l['spans']).strip()
            if re.match(pattern, tx) and any(round(s['size']) == 16 for s in l['spans']):
                return pi
    return None


def parse_index(first, last):
    entries = []
    cur = None
    sub = None
    for pi in range(first, last + 1):
        for l in page_lines(pi):
            z = round(l['spans'][0]['size'])
            f = l['spans'][0]['font']
            tx = clean(''.join(s['text'] for s in l['spans'])).strip()
            if 'Myriad' in f or not tx:
                continue
            if z == 16 or l['y0'] < 45 or l['y0'] > 600:
                continue
            if z == 10 and len(tx) == 1:
                continue
            if z == 10:
                sub = None
                m = re.match(r'(.*?)\s+[–-]\s+(.*)$', tx)
                if m:
                    cur = {'term': m.group(1).strip(), 'refs': m.group(2).strip(), 'subs': []}
                else:
                    cur = {'term': tx, 'refs': '', 'subs': []}
                entries.append(cur)
            elif z == 9 and cur is not None:
                if sub is not None and not sub_complete(sub):
                    sub = sub + ' ' + tx
                    cur['subs'][-1] = sub
                else:
                    sub = tx
                    cur['subs'].append(sub)
    res = []
    for e in entries:
        subs = []
        for s in e['subs']:
            m = re.match(r'(.*?)\s+[–]\s+(.*)$', s)
            if m:
                subs.append({'label': m.group(1).strip(), 'refs': parse_refs(m.group(2))})
            else:
                subs.append({'label': s.strip(' –'), 'refs': []})
        res.append({'term': e['term'], 'refs': parse_refs(e['refs']), 'subs': subs})
    return res


def sub_complete(s):
    s = s.strip()
    return ' – ' in s + ' ' and not s.endswith(',') and not s.endswith('–') and not s.endswith(' a')


def parse_refs(s):
    refs = []
    prefix = None
    s = s.replace(' a ', '-')
    for tok in re.split(r'[,;]', s):
        tok = tok.strip()
        if not tok:
            continue
        if tok in ('introd.', 'concl.', 'proleg.'):
            prefix = tok.rstrip('.')
            if tok == 'proleg.':
                refs.append(['s', 'proleg', ''])
                prefix = None
            continue
        if re.fullmatch(r'[IVXL]+', tok) and prefix:
            refs.append(['s', prefix, tok])
            continue
        m = re.fullmatch(r'(\d+)([a-z]?)\s*-\s*(\d+)([a-z]?)', tok)
        if m:
            refs.append(['r', int(m.group(1)), int(m.group(3)), tok])
            continue
        m = re.fullmatch(r'(\d+)([a-z]?)', tok)
        if m:
            refs.append(['q', int(m.group(1)), tok])
            continue
        m = re.fullmatch(r'(\d+)\s*[a-z]?\s*(\d+)', tok)
        refs.append(['x', tok])
    return refs


if __name__ == '__main__':
    c = Collector()
    c.pending_part_title = ''
    BODY_FIRST, BODY_LAST = 52, 459
    parse_body(c, BODY_FIRST, BODY_LAST)
    qs = c.qs
    print('questions:', len(qs), 'first', qs[0]['n'], 'last', qs[-1]['n'])
    nums = [q['n'] for q in qs]
    missing = sorted(set(range(1, 1020)) - set(nums))
    dups = sorted({n for n in nums if nums.count(n) > 1})
    print('missing', missing[:40], 'dups', dups[:40])
    print('parts', [(p['title'], len(p['chapters'])) for p in c.parts])

    concl_start = find_page(r'CONCLUS.O', 455, 470)
    nota_start = find_page(r'NOTA EXPLICATIVA', 470, 485)
    proleg_start = find_page(r'PROLEG.MENOS', 40, 52)
    intro_start = find_page(r'INTRODU..O AO ESTUDO\s*', 10, 20)
    print('starts', intro_start, proleg_start, concl_start, nota_start)
    index_start = find_page(r'.NDICE GERAL.*', 478, 490)
    print('index start', index_start)
    sections = {
        'introd': parse_free(intro_start, proleg_start - 1),
        'proleg': parse_free(proleg_start, BODY_FIRST - 1, False),
        'concl': parse_free(concl_start, nota_start - 1),
        'nota': parse_free(nota_start, index_start - 1, False),
    }
    last_index = max(pi for pi in range(index_start, len(d)) if 'Índice geral' in d[pi].get_text()[:40] or 'ÍNDICE GERAL' in d[pi].get_text()[:40])
    index = parse_index(index_start, last_index)
    print('index end page idx', last_index, 'entries', len(index))
    data = {'parts': c.parts, 'questions': qs, 'sections': sections, 'index': index,
            'texts': [{'chapter': ch['id'], **t} for p in c.parts for ch in p['chapters'] for t in ch.get('texts', [])]}
    json.dump(data, open('data.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
