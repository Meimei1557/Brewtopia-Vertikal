"""Varian pelanggan dari sprite man.png / woman.png: recolor per-wilayah + pecah badan & kaki."""
from PIL import Image, ImageDraw
import numpy as np, os
ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets')
OUT = f'{ROOT}/people'; os.makedirs(OUT, exist_ok=True)
SRC = {'m': os.path.join(os.path.dirname(__file__), 'source', 'man.png'), 'w': os.path.join(os.path.dirname(__file__), 'source', 'woman.png')}

def recolor(a, region, sample, target, tol=34):
    """Ganti piksel yang mirip `sample` di dalam region (y0,y1,x0,x1) ke warna `target` (pertahankan bayangan)."""
    y0, y1, x0, x1 = region; sub = a[y0:y1, x0:x1].astype(float)
    dist = np.sqrt(((sub[..., :3] - np.array(sample)) ** 2).sum(-1)); m = (dist < tol) & (sub[..., 3] > 0)
    luma = sub[..., :3].mean(-1) / np.mean(sample)
    for c in range(3): sub[..., c] = np.where(m, np.clip(target[c] * luma, 0, 255), sub[..., c])
    a[y0:y1, x0:x1] = sub.astype(np.uint8)

def split(a, name, hip, splitx):
    body = a.copy(); body[hip:, :, 3] = 0
    L = a.copy(); L[:hip, :, 3] = 0; L[:, splitx:, 3] = 0
    R = a.copy(); R[:hip, :, 3] = 0; R[:, :splitx, 3] = 0
    for n, x in (('body', body), ('legL', L), ('legR', R)): Image.fromarray(x).save(f'{OUT}/{name}_{n}.png', optimize=True)

man = np.array(Image.open(SRC['m']).convert('RGBA')); wom = np.array(Image.open(SRC['w']).convert('RGBA'))
M_SWEATER, M_HAIR, M_PANTS = (71, 49, 38), (104, 69, 49), None
# sampel celana pria
ys, xs = np.where(man[330:430, :, 3] > 200); M_PANTS = tuple(int(v) for v in man[380, 245, :3]) if man[380, 245, 3] > 200 else tuple(int(v) for v in man[360, 235, :3])
W_DRESS, W_HAIR = (102, 69, 52), (147, 98, 65)
men = [
    (None, None, None),
    ((44, 76, 138), (40, 30, 26), (80, 84, 92)),      # sweater biru, rambut hitam, celana abu
    ((214, 160, 48), None, (60, 58, 62)),               # kuning mustard
    ((72, 130, 84), (196, 150, 78), None),              # hijau, rambut pirang
]
women = [
    (None, None),
    ((38, 130, 134), (44, 32, 30)),                     # teal, rambut hitam
    ((130, 78, 150), (214, 170, 96)),                   # ungu, pirang
    ((218, 168, 52), (150, 58, 40)),                    # kuning, rambut merah
]
for i, (sw, hr, pn) in enumerate(men):
    a = man.copy()
    if sw: recolor(a, (160, 312, 150, 340), M_SWEATER, sw, 30)
    if hr: recolor(a, (30, 130, 150, 340), M_HAIR, hr, 26)
    if pn: recolor(a, (310, 440, 150, 340), M_PANTS, pn, 30)
    split(a, f'c{i}', 308, 250)
for i, (dr, hr) in enumerate(women):
    a = wom.copy()
    if dr: recolor(a, (180, 400, 150, 340), W_DRESS, dr, 22)
    if hr: recolor(a, (30, 270, 120, 380), W_HAIR, hr, 30)
    split(a, f'c{4 + i}', 396, 248)

# barista pria (apron) & wanita
def barista(a, shirt, name):
    recolor(a, (160, 312, 150, 340), M_SWEATER, shirt, 30)
    im = Image.fromarray(a); d = ImageDraw.Draw(im)
    d.polygon([(215, 190), (285, 190), (300, 312), (200, 312)], fill=(246, 238, 218, 255), outline=(120, 90, 60, 255))
    d.line([(222, 190), (236, 170)], fill=(246, 238, 218, 255), width=4); d.line([(278, 190), (264, 170)], fill=(246, 238, 218, 255), width=4)
    im.save(f'{OUT}/{name}.png', optimize=True)
barista(man.copy(), (44, 98, 72), 'barista_m')
a = wom.copy(); recolor(a, (180, 400, 150, 340), W_DRESS, (44, 98, 72), 28)
im = Image.fromarray(a); d = ImageDraw.Draw(im)
d.polygon([(222, 215), (278, 215), (292, 330), (208, 330)], fill=(246, 238, 218, 255), outline=(120, 90, 60, 255)); im.save(f'{OUT}/barista_f.png', optimize=True)

# preview
sheet = Image.new('RGBA', (500 * 5, 500 * 2), (225, 205, 175, 255))
for i in range(8):
    c = Image.new('RGBA', (500, 500))
    for part in ('legL', 'legR', 'body'): c.alpha_composite(Image.open(f'{OUT}/c{i}_{part}.png'))
    sheet.alpha_composite(c, ((i % 4) * 500, (i // 4) * 500))
sheet.alpha_composite(Image.open(f'{OUT}/barista_m.png'), (2000, 0)); sheet.alpha_composite(Image.open(f'{OUT}/barista_f.png'), (2000, 500))
sheet.convert('RGB').resize((1250, 500)).save('/tmp/people.png'); print('ok', M_PANTS)
