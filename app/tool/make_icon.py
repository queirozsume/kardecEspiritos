"""Gera o ícone do app (ramo de videira com uvas) em assets/icon/."""
import math
import os
from PIL import Image, ImageDraw

S = 4                      # supersampling
N = 1024
BG = (59, 47, 99)
CREAM = (232, 217, 168)
LEAF = (214, 196, 140)
LEAF_DARK = (150, 128, 80)
GRAPE = (176, 140, 232)
GRAPE_DARK = (112, 78, 176)
GRAPE_HI = (226, 206, 250)
OX, OY = -15, 95           # centraliza o desenho no quadro


def bez(p, t):
    a, b, c, d = p
    u = 1 - t
    return tuple(u**3 * a[i] + 3 * u * u * t * b[i] + 3 * u * t * t * c[i] + t**3 * d[i] for i in (0, 1))


def leaf(dr, cx, cy, R, rot):
    pts = []
    for k in range(361):
        th = math.radians(k)
        r = R * (0.52 + 0.48 * abs(math.cos(2.5 * th)) ** 0.8)
        a = th + rot
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    dr.polygon(pts, fill=LEAF)
    for k in range(5):
        a = rot + math.radians(72 * k)
        dr.line([(cx, cy), (cx + 0.8 * R * math.cos(a), cy + 0.8 * R * math.sin(a))], fill=LEAF_DARK, width=5)


def vine(dr):
    path = [(180 + OX, 400 + OY), (380 + OX, 300 + OY), (620 + OX, 520 + OY), (850 + OX, 380 + OY)]
    pts = [bez(path, i / 200) for i in range(201)]
    for i in range(len(pts) - 1):
        w = 22 - 10 * i / 200
        dr.line([pts[i], pts[i + 1]], fill=CREAM, width=w)
        dr.ellipse([pts[i][0] - w / 2, pts[i][1] - w / 2, pts[i][0] + w / 2, pts[i][1] + w / 2], fill=CREAM)
    c = path[3]
    for k in range(60):
        a = k / 59 * 4.2
        r = 46 * (1 - k / 70)
        x, y = c[0] + r * math.cos(a - 1.2), c[1] + r * math.sin(a - 1.2) - 40
        dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=CREAM)
    p1 = bez(path, 0.22)
    p2 = bez(path, 0.82)
    leaf(dr, p1[0] - 5, p1[1] - 135, 135, math.radians(-100))
    leaf(dr, p2[0] + 10, p2[1] - 125, 120, math.radians(-75))
    g = bez(path, 0.5)
    dr.line([g, (g[0], g[1] + 70)], fill=CREAM, width=14)
    r = 44
    y = g[1] + 80
    for n in (4, 3, 2, 1):
        x0 = g[0] - (n - 1) * r
        for j in range(n):
            x = x0 + j * 2 * r
            dr.ellipse([x - r, y - r, x + r, y + r], fill=GRAPE, outline=GRAPE_DARK, width=5)
            dr.ellipse([x - r * 0.5, y - r * 0.6, x - r * 0.1, y - r * 0.2], fill=GRAPE_HI)
        y += r * 1.55


class Scaled:
    """Aplica supersampling e uma escala k em torno do centro do quadro."""

    def __init__(self, draw, k):
        self.d, self.k = draw, k

    def _p(self, v):
        return ((v[0] - N / 2) * self.k + N / 2) * S, ((v[1] - N / 2) * self.k + N / 2) * S

    def _coords(self, v):
        if isinstance(v, tuple) and len(v) == 2 and not isinstance(v[0], (tuple, list)):
            return self._p(v)
        if isinstance(v, list) and v and isinstance(v[0], (tuple, list)):
            return [self._p(x) for x in v]
        if isinstance(v, list):
            return [c for i in range(0, len(v), 2) for c in self._p((v[i], v[i + 1]))]
        return v

    def _call(self, name, *a, **k):
        if 'width' in k:
            k['width'] = max(1, round(k['width'] * self.k * S))
        return getattr(self.d, name)(self._coords(a[0]), **k)

    def line(self, *a, **k):
        return self._call('line', *a, **k)

    def ellipse(self, *a, **k):
        return self._call('ellipse', *a, **k)

    def polygon(self, *a, **k):
        return self._call('polygon', *a, **k)


def render(bg, k):
    layer = Image.new('RGBA', (N * S, N * S), (0, 0, 0, 0))
    vine(Scaled(ImageDraw.Draw(layer), k))
    im = Image.new('RGBA', (N * S, N * S), bg + (255,) if bg else (0, 0, 0, 0))
    im.alpha_composite(layer)
    return im.resize((N, N), Image.LANCZOS)


if __name__ == '__main__':
    out = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icon')
    os.makedirs(out, exist_ok=True)
    render(BG, 0.9).convert('RGB').save(os.path.join(out, 'icon.png'))
    render(None, 0.72).save(os.path.join(out, 'icon_fg.png'))
