"""Ikon menu & bahan (128x128) digambar dengan supersampling 4x."""
from PIL import Image, ImageDraw, ImageFilter
import math, os
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icons'); os.makedirs(OUT, exist_ok=True)
K = 4; N = 128
def hexc(h, a=255): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
class C:
    def __init__(s): s.im = Image.new('RGBA', (N * K, N * K), (0, 0, 0, 0))
    def P(s, *v): return [int(round(x * K)) for x in v]
    def _do(s, fn, *cols):
        if any(isinstance(c, tuple) and len(c) == 4 and c[3] < 255 for c in cols):
            ov = Image.new('RGBA', s.im.size, (0, 0, 0, 0)); fn(ImageDraw.Draw(ov)); s.im.alpha_composite(ov)
        else: fn(ImageDraw.Draw(s.im))
    def ell(s, x0, y0, x1, y1, fill=None, outline=None, w=0): s._do(lambda d: d.ellipse(s.P(x0, y0, x1, y1), fill=fill, outline=outline, width=int(w * K)), fill, outline)
    def rr(s, x0, y0, x1, y1, r, fill=None, outline=None, w=0): s._do(lambda d: d.rounded_rectangle(s.P(x0, y0, x1, y1), radius=int(r * K), fill=fill, outline=outline, width=int(w * K)), fill, outline)
    def poly(s, pts, fill=None, outline=None, w=0): s._do(lambda d: d.polygon([int(round(v * K)) for p in pts for v in p], fill=fill, outline=outline), fill, outline)
    def line(s, pts, fill, w=1): s._do(lambda d: d.line([int(round(v * K)) for p in pts for v in p], fill=fill, width=max(1, int(w * K)), joint='curve'), fill)
    def arc(s, box, a0, a1, fill, w=1): s._do(lambda d: d.arc(s.P(*box), a0, a1, fill=fill, width=int(w * K)), fill)
    def save(s, name):
        im = s.im.resize((N, N), Image.LANCZOS)
        sh = Image.new('RGBA', (N, N), (0, 0, 0, 0)); a = im.getchannel('A').filter(ImageFilter.GaussianBlur(2.2)).point(lambda v: int(v * .28)); sh.putalpha(a)
        out = Image.new('RGBA', (N, N), (0, 0, 0, 0)); out.alpha_composite(sh, (0, 2)); out.alpha_composite(im); out.save(f'{OUT}/{name}.png', optimize=True)
WHITE = hexc('#FFFFFF'); RIM = hexc('#D9CFC0'); COF = hexc('#4A2A15'); 
def steam(c, x, y, n=2, col=(255, 255, 255, 150)):
    for i in range(n):
        xs = x + i * 12
        c.line([(xs, y), (xs - 3, y - 6), (xs + 3, y - 12), (xs, y - 18)], col, 2.2)
def saucer(c): c.ell(18, 96, 110, 116, hexc('#F2EBDD'), RIM, 1.4); c.ell(34, 99, 94, 111, hexc('#E4DACA'))
def handle(c, x, y, w, h): c.ell(x, y, x + w, y + h, None, hexc('#F7F2E8'), 5.5); c.ell(x - .5, y - .5, x + w + .5, y + h + .5, None, RIM, 1.2)

def espresso():
    c = C(); saucer(c); steam(c, 52, 40, 2)
    handle(c, 86, 70, 20, 20)
    c.poly([(34, 62), (94, 62), (86, 100), (42, 100)], WHITE); c.ell(42, 92, 86, 108, WHITE); c.poly([(34, 62), (40, 62), (48, 100), (42, 100)], (0, 0, 0, 18))
    c.ell(32, 54, 96, 72, WHITE, RIM, 1.4); c.ell(37, 57, 91, 69, COF); c.ell(42, 59, 86, 67, hexc('#B7804A')); c.ell(50, 60, 78, 65, hexc('#D8A66B'))
    c.save('espresso')
def americano():
    c = C(); saucer(c); steam(c, 44, 36, 3, (255, 255, 255, 140))
    handle(c, 84, 56, 26, 30)
    c.rr(30, 44, 92, 102, 12, WHITE, RIM, 1.2); c.rr(33, 46, 40, 96, 6, (0, 0, 0, 16))
    c.ell(30, 36, 92, 54, WHITE, RIM, 1.4); c.ell(35, 39, 87, 51, hexc('#6B4226')); c.ell(40, 41, 82, 49, hexc('#8A5A36'))
    c.rr(36, 70, 86, 78, 3, (255, 255, 255, 60)); c.save('americano')
def macchiato():
    c = C(); c.ell(26, 104, 102, 118, (0, 0, 0, 30))
    c.poly([(38, 34), (90, 34), (84, 106), (44, 106)], (225, 240, 245, 95), hexc('#BFD6DC'), 1.6)
    c.poly([(41, 72), (87, 72), (84, 106), (44, 106)], hexc('#3A200F')); c.poly([(40, 56), (88, 56), (87, 72), (41, 72)], hexc('#9A6A3C'))
    c.ell(37, 28, 91, 44, hexc('#FFFDF7'), hexc('#EADFCB'), 1.2); c.ell(52, 31, 76, 41, hexc('#FFFFFF'))
    c.ell(58, 33, 70, 39, hexc('#8A5A36')); c.poly([(46, 38), (50, 38), (48, 100), (46, 100)], (255, 255, 255, 80))
    c.rr(36, 104, 92, 112, 3, hexc('#DCD3C4')); c.save('macchiato')
def cappuccino():
    c = C(); saucer(c); steam(c, 50, 38, 2)
    handle(c, 94, 60, 18, 26)
    c.poly([(20, 58), (108, 58), (96, 96), (32, 96)], WHITE); c.ell(32, 86, 96, 106, WHITE); c.poly([(20, 58), (28, 58), (40, 96), (32, 96)], (0, 0, 0, 16))
    c.ell(16, 44, 112, 74, WHITE, RIM, 1.5); c.ell(22, 48, 106, 70, hexc('#B98550')); c.ell(26, 50, 102, 68, hexc('#FFF4E2'))
    # latte art hati
    c.ell(48, 52, 64, 64, hexc('#9A6A3C')); c.ell(62, 52, 78, 64, hexc('#9A6A3C')); c.poly([(49, 60), (77, 60), (63, 70)], hexc('#9A6A3C'))
    c.ell(51, 54, 62, 62, hexc('#FFF4E2')); c.ell(64, 54, 75, 62, hexc('#FFF4E2')); c.poly([(52, 60), (74, 60), (63, 67)], hexc('#FFF4E2'))
    c.save('cappuccino')
def latte():
    c = C(); c.ell(26, 108, 102, 122, (0, 0, 0, 30))
    c.poly([(36, 14), (92, 14), (86, 110), (42, 110)], (225, 240, 245, 90), hexc('#BFD6DC'), 1.6)
    c.poly([(43, 84), (85, 84), (86, 110), (42, 110)], hexc('#3A200F'))
    c.poly([(40, 56), (89, 56), (85, 84), (43, 84)], hexc('#B98550')); c.poly([(38, 34), (90, 34), (89, 56), (40, 56)], hexc('#EBD3B0'))
    c.poly([(37, 18), (91, 18), (90, 34), (38, 34)], hexc('#FFFDF7')); c.ell(36, 12, 92, 24, hexc('#FFFFFF'), hexc('#E6DAC4'), 1)
    c.poly([(44, 22), (50, 22), (48, 108), (44, 108)], (255, 255, 255, 80))
    c.line([(80, 4), (72, 70)], hexc('#E85D75'), 3); c.save('latte')
def doughnut():
    c = C(); c.ell(14, 98, 114, 116, (0, 0, 0, 40))
    c.ell(14, 34, 114, 104, hexc('#D9A05B')); c.ell(14, 30, 114, 98, hexc('#E7B672'))
    c.ell(18, 32, 110, 92, hexc('#F08FB1')); c.ell(26, 36, 102, 86, hexc('#F7A8C4'))
    c.ell(46, 52, 82, 74, hexc('#D9A05B')); c.ell(48, 54, 80, 70, (0, 0, 0, 0))
    # lubang: hapus alpha
    mask = Image.new('L', c.im.size, 255); ImageDraw.Draw(mask).ellipse(c.P(48, 53, 80, 69), fill=0); c.im.putalpha(Image.composite(c.im.getchannel('A'), Image.new('L', c.im.size, 0), mask))
    for (x, y, col) in [(32, 50, '#FFD54F'), (92, 56, '#7EE6FF'), (60, 40, '#FFFFFF'), (74, 80, '#FFD54F'), (36, 72, '#7EE6FF'), (98, 42, '#FFFFFF'), (52, 82, '#9DFFB0'), (84, 70, '#FFFFFF')]:
        c.line([(x, y), (x + 6, y + 2)], hexc(col), 3)
    c.save('doughnut')
def croissant():
    c = C(); c.ell(12, 98, 116, 116, (0, 0, 0, 40))
    segs = [(10, 72, 38, 100), (26, 54, 58, 96), (46, 44, 84, 92), (70, 54, 102, 96), (90, 72, 118, 100)]
    cols = ['#C9822F', '#D99A45', '#E6AE5A', '#D99A45', '#C9822F']
    for (x0, y0, x1, y1), col in zip(segs, cols): c.ell(x0, y0, x1, y1, hexc(col), hexc('#A8691F'), 1.6)
    for (x0, y0, x1, y1) in segs[1:4]: c.arc((x0 + 6, y0 + 4, x1 - 6, y1 - 4), 200, 340, hexc('#A8691F', 150), 1.6)
    c.ell(46, 48, 70, 60, (255, 240, 200, 120)); c.save('croissant')
def cheesecake():
    c = C(); c.ell(14, 98, 114, 116, (0, 0, 0, 40))
    c.poly([(16, 88), (112, 66), (112, 100), (16, 108)], hexc('#8A5A36'))     # alas biskuit
    c.poly([(16, 62), (112, 40), (112, 70), (16, 90)], hexc('#FFF1CC')); c.poly([(16, 62), (112, 40), (112, 48), (16, 70)], hexc('#E2354F'))  # krim + selai
    c.ell(58, 22, 82, 46, hexc('#E2354F'), hexc('#B71C32'), 1.6); c.poly([(60, 26), (80, 26), (70, 20)], hexc('#43A047'))
    c.ell(66, 30, 70, 34, hexc('#FFD54F')); c.line([(16, 62), (16, 108)], hexc('#6B4226'), 1.6); c.line([(16, 62), (112, 40)], hexc('#D9C9A4'), 1.5); c.save('cheesecake')
def beans():
    c = C(); c.ell(16, 100, 112, 118, (0, 0, 0, 40))
    for (cx, cy, rot) in [(46, 80, -25), (78, 78, 18), (62, 50, 0)]:
        b = Image.new('RGBA', (N * K, N * K), (0, 0, 0, 0)); d = ImageDraw.Draw(b)
        d.ellipse([int((cx - 22) * K), int((cy - 30) * K), int((cx + 22) * K), int((cy + 30) * K)], fill=hexc('#6B4226'), outline=hexc('#3A200F'), width=int(2 * K))
        d.arc([int((cx - 14) * K), int((cy - 30) * K), int((cx + 14) * K), int((cy + 30) * K)], 100, 260, fill=hexc('#2F1A0C'), width=int(3.4 * K))
        d.ellipse([int((cx - 15) * K), int((cy - 24) * K), int((cx - 4) * K), int((cy - 10) * K)], fill=(255, 255, 255, 40))
        b = b.rotate(rot, center=(cx * K, cy * K), resample=Image.BICUBIC); c.im.alpha_composite(b)
    c.save('beans')
def milk():
    c = C(); c.ell(26, 108, 102, 122, (0, 0, 0, 36))
    c.poly([(34, 40), (94, 40), (94, 112), (34, 112)], hexc('#FFFFFF'), hexc('#CFD8DC'), 1.6); c.poly([(34, 40), (64, 14), (94, 40)], hexc('#EEF3F6'), hexc('#CFD8DC'), 1.6)
    c.rr(34, 62, 94, 90, 0, hexc('#4FC3F7')); c.ell(54, 66, 74, 86, hexc('#FFFFFF')); c.poly([(64, 66), (58, 78), (70, 78)], hexc('#FFFFFF'))
    c.poly([(34, 40), (44, 40), (44, 112), (34, 112)], (0, 0, 0, 14)); c.save('milk')
def flour():
    c = C(); c.ell(20, 106, 108, 122, (0, 0, 0, 36))
    c.poly([(30, 36), (98, 36), (108, 108), (20, 108)], hexc('#F1E2BE'), hexc('#CDB98A'), 1.6); c.ell(20, 98, 108, 118, hexc('#E6D4A8'), hexc('#CDB98A'), 1.4)
    c.poly([(40, 36), (88, 36), (82, 24), (46, 24)], hexc('#E3CF9E'), hexc('#CDB98A'), 1.4); c.line([(46, 30), (82, 30)], hexc('#C0392B'), 3.4)
    for dx in (-8, 0, 8):
        c.line([(64 + dx, 90), (64 + dx, 60)], hexc('#B8892E'), 2.2)
        for j in range(4): c.ell(64 + dx - 5, 60 + j * 6, 64 + dx + 1, 66 + j * 6, hexc('#D9A441'))
    c.save('flour')
for f in (espresso, americano, macchiato, cappuccino, latte, doughnut, croissant, cheesecake, beans, milk, flour): f()
sheet = Image.new('RGBA', (N * 6, N * 2), (240, 225, 200, 255))
for i, n in enumerate(['espresso', 'americano', 'macchiato', 'cappuccino', 'latte', 'doughnut', 'croissant', 'cheesecake', 'beans', 'milk', 'flour']):
    sheet.alpha_composite(Image.open(f'{OUT}/{n}.png'), ((i % 6) * N, (i // 6) * N))
sheet.convert('RGB').save('/tmp/icons.png'); print('ok')
