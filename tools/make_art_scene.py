"""Gambar latar kafe (dinding+lantai), counter, pintu, meja, kursi, tong sampah, dekor."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
import math, os
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'scene'); os.makedirs(OUT, exist_ok=True)
S = 2; W, H = 600, 1300
FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'; FS = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'; FR = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(p, size, k=S): return ImageFont.truetype(p, int(size * k))
def hexc(h, a=255): h = h.lstrip('#'); return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)
def mix(c1, c2, t): return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))

def _alpha(c): return isinstance(c, tuple) and len(c) == 4 and c[3] < 255

class Cv:
    def __init__(s, w, h, k=S, bg=(0, 0, 0, 0)):
        s.k = k; s.im = Image.new('RGBA', (int(w * k), int(h * k)), bg); s.d = ImageDraw.Draw(s.im)
    def P(s, *v): return [int(round(x * s.k)) for x in v]
    def _do(s, fn, *cols):
        if any(_alpha(c) for c in cols):   # blend warna semi-transparan (bukan menimpa)
            ov = Image.new('RGBA', s.im.size, (0, 0, 0, 0)); fn(ImageDraw.Draw(ov)); s.im.alpha_composite(ov)
        else: fn(s.d)
    def rect(s, x0, y0, x1, y1, fill=None, r=0, outline=None, w=0):
        s._do(lambda d: d.rounded_rectangle(s.P(x0, y0, x1, y1), radius=int(r * s.k), fill=fill, outline=outline, width=int(w * s.k)), fill, outline)
    def ell(s, x0, y0, x1, y1, fill=None, outline=None, w=0): s._do(lambda d: d.ellipse(s.P(x0, y0, x1, y1), fill=fill, outline=outline, width=int(w * s.k)), fill, outline)
    def poly(s, pts, fill=None, outline=None): s._do(lambda d: d.polygon([int(round(v * s.k)) for p in pts for v in p], fill=fill, outline=outline), fill, outline)
    def line(s, pts, fill, w=1): s._do(lambda d: d.line([int(round(v * s.k)) for p in pts for v in p], fill=fill, width=max(1, int(w * s.k)), joint='curve'), fill)
    def text(s, xy, t, f, fill, anchor='la'): s._do(lambda d: d.text(s.P(*xy), t, font=f, fill=fill, anchor=anchor), fill)
    def arch(s, x0, y0, x1, y1, fill):
        r = (x1 - x0) / 2
        s._do(lambda d: (d.pieslice(s.P(x0, y0, x1, y0 + 2 * r), 180, 360, fill=fill), d.rectangle(s.P(x0, y0 + r, x1, y1), fill=fill)), fill)
    def vgrad(s, x0, y0, x1, y1, c1, c2):
        for i in range(int((y1 - y0) * s.k)):
            tt = i / max(1, (y1 - y0) * s.k); s.d.line([int(x0 * s.k), int(y0 * s.k) + i, int(x1 * s.k), int(y0 * s.k) + i], fill=mix(c1, c2, tt))
    def alpha_paste(s, other, x, y): s.im.alpha_composite(other, (int(x * s.k), int(y * s.k)))
    def save(s, name, down=None):
        im = s.im
        if down: im = im.resize((int(im.width * down), int(im.height * down)), Image.LANCZOS)
        im.save(f'{OUT}/{name}.png', optimize=True); return im

def shadow(cv, box, blur=6, alpha=90):
    m = Image.new('L', cv.im.size, 0); ImageDraw.Draw(m).rounded_rectangle(cv.P(*box), radius=int(6 * cv.k), fill=alpha)
    m = m.filter(ImageFilter.GaussianBlur(blur * cv.k)); sh = Image.new('RGBA', cv.im.size, (30, 15, 5, 0)); sh.putalpha(m); cv.im.alpha_composite(sh)

def cutout(cv, shape_fn):
    m = Image.new('L', cv.im.size, 0); shape_fn(ImageDraw.Draw(m), cv.k); inv = ImageChops.invert(m)
    a = ImageChops.multiply(cv.im.getchannel('A'), inv); cv.im.putalpha(a)

# ---------------------------------------------------------------- WALL + FLOOR
def make_wall():
    c = Cv(W, H); k = S
    c.vgrad(0, 0, W, 540, hexc('#F7EAD8'), hexc('#EEDABF'))
    for x in range(0, W, 36): c.rect(x, 0, x + 1.5, 300, (200, 160, 120, 22))
    # wainscot terracotta
    c.rect(0, 296, W, 548, hexc('#B35F3B')); c.vgrad(0, 296, W, 548, hexc('#BD6842'), hexc('#A4532F'))
    for i in range(0, 7):
        x = 14 + i * 86; c.rect(x, 322, x + 74, 520, None, 4, hexc('#CC7A52'), 2.2); c.rect(x + 7, 329, x + 67, 513, None, 3, (120, 55, 30, 90), 1.2)
    c.rect(0, 286, W, 306, hexc('#8B4B2B')); c.rect(0, 286, W, 291, hexc('#B06B45'))
    c.rect(0, 520, W, 548, hexc('#6A3A22')); c.rect(0, 520, W, 524, hexc('#8B5033'))
    # FLOOR (planks, perspective)
    fl = Cv(W, H - 548); fl.vgrad(0, 0, W, H - 548, hexc('#CFA06A'), hexc('#B98650'))
    vx, vy = 300, -440  # vanishing point relative to floor top
    for x0 in range(-900, 1500, 54):
        xt = x0; xb = 300 + (x0 - 300) * ((H - 548) - vy) / (0 - vy)
        fl.line([(xt, 0), (xb, H - 548)], (110, 70, 35, 55), 1.2)
    y = 0; step = 20
    while y < H - 548:
        fl.line([(0, y), (W, y)], (110, 70, 35, 40), 1); y += step; step *= 1.18
    for i in range(34):  # papan lebih terang acak
        import random; random.seed(i); xx = random.randint(-100, 560); yy = random.randint(0, 740); ww = random.randint(40, 130); hh = random.randint(8, 22) * (1 + yy / 500)
        fl.rect(xx, yy, xx + ww, yy + hh, (255, 220, 170, 26))
    c.im.alpha_composite(fl.im, (0, int(548 * k)))
    # bayangan kaki dinding
    sh = Image.new('RGBA', c.im.size, (0, 0, 0, 0)); ImageDraw.Draw(sh).rectangle([0, int(548 * k), c.im.width, int(560 * k)], fill=(60, 30, 10, 70)); c.im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4 * k)))
    # CHALKBOARD
    bx0, by0, bx1, by1 = 196, 62, 346, 266
    shadow(c, (bx0 + 2, by0 + 6, bx1 + 2, by1 + 8), 5, 80)
    c.rect(bx0, by0, bx1, by1, hexc('#7B4A2A'), 6); c.rect(bx0 + 7, by0 + 7, bx1 - 7, by1 - 7, hexc('#272C2B'), 3); c.rect(bx0 + 7, by0 + 7, bx1 - 7, by1 - 7, None, 3, (255, 255, 255, 20), 1)
    ch = (245, 240, 225, 235); cx = (bx0 + bx1) / 2
    c.text((cx, by0 + 12), 'MENU', font(FS, 19), ch, 'ma')
    c.text((bx0 + 16, by0 + 40), 'COFFEE', font(FB, 8.5), (255, 213, 120, 230))
    items = [('Espresso', 12), ('Americano', 15), ('Macchiato', 20), ('Cappuccino', 22), ('Latte', 25)]
    for i, (n, p) in enumerate(items):
        yy = by0 + 54 + i * 12.6; c.text((bx0 + 16, yy), n, font(FR, 8.6), ch); c.text((bx1 - 16, yy), str(p), font(FR, 8.6), ch, 'ra')
        c.line([(bx0 + 16 + len(n) * 5.4, yy + 8.5), (bx1 - 28, yy + 8.5)], (245, 240, 225, 70), .8)
    c.text((bx0 + 16, by0 + 122), 'BAKERY', font(FB, 8.5), (255, 213, 120, 230))
    for i, (n, p) in enumerate([('Doughnut', 10), ('Croissant', 14), ('Cheesecake', 20)]):
        yy = by0 + 136 + i * 12.6; c.text((bx0 + 16, yy), n, font(FR, 8.6), ch); c.text((bx1 - 16, yy), str(p), font(FR, 8.6), ch, 'ra')
        c.line([(bx0 + 16 + len(n) * 5.4, yy + 8.5), (bx1 - 28, yy + 8.5)], (245, 240, 225, 70), .8)
    # WINDOW (lubang transparan -> langit digambar Flutter)
    wx0, wy0, wx1, wy1 = 22, 66, 150, 272
    frame = Cv(W, H); frame.arch(wx0 - 9, wy0 - 9, wx1 + 9, wy1 + 9, hexc('#7A4A2A')); 
    shadow(c, (wx0 - 7, wy0 - 3, wx1 + 11, wy1 + 9), 6, 70); c.im.alpha_composite(frame.im)
    def win_hole(d, kk):
        r = (wx1 - wx0) / 2; d.pieslice([int(wx0 * kk), int(wy0 * kk), int(wx1 * kk), int((wy0 + 2 * r) * kk)], 180, 360, fill=255); d.rectangle([int(wx0 * kk), int((wy0 + r) * kk), int(wx1 * kk), int(wy1 * kk)], fill=255)
    cutout(c, win_hole)
    mid = (wx0 + wx1) / 2; c.rect(mid - 3, wy0, mid + 3, wy1, hexc('#7A4A2A')); c.rect(wx0, wy0 + 100, wx1, wy0 + 106, hexc('#7A4A2A')); c.arch(wx0 - 1, wy0 - 1, wx1 + 1, wy1 + 1, None) if False else None
    c.rect(wx0 - 14, wy1 + 4, wx1 + 14, wy1 + 16, hexc('#6A3A22'), 3); c.rect(wx0 - 14, wy1 + 4, wx1 + 14, wy1 + 8, hexc('#9B6540'), 3)
    # DOOR FRAME (lubang transparan)
    dx0, dy0, dx1, dy1 = 458, 196, 574, 548
    shadow(c, (dx0 - 12, dy0 - 10, dx1 + 14, dy1), 6, 70)
    c.rect(dx0 - 12, dy0 - 12, dx1 + 12, dy1, hexc('#6A3A22'), 10); c.rect(dx0 - 12, dy0 - 12, dx1 + 12, dy0 - 6, hexc('#8B5033'), 6)
    cutout(c, lambda d, kk: d.rounded_rectangle([int(dx0 * kk), int(dy0 * kk), int(dx1 * kk), int(dy1 * kk)], radius=int(4 * kk), fill=255))
    c.rect(dx0 - 16, 540, dx1 + 16, 552, hexc('#5A3018'), 2)   # ambang
    c.save('wall')
    return c

# ---------------------------------------------------------------- COUNTER FG
def make_counter():
    c = Cv(W, H)
    # panel depan
    shadow(c, (0, 560, 452, 600), 8, 110)
    c.vgrad(0, 458, 440, 578, hexc('#7A4A2C'), hexc('#5E3520'))
    for i in range(6):
        x = 12 + i * 71; c.rect(x, 474, x + 62, 560, None, 4, hexc('#9A6340'), 2); c.rect(x + 6, 480, x + 56, 554, (0, 0, 0, 28), 3)
    c.rect(0, 566, 440, 580, hexc('#3F2314')); c.rect(432, 444, 448, 580, hexc('#4D2B18'), 2)
    # slab atas
    c.rect(-6, 440, 448, 462, hexc('#E2C193'), 5); c.rect(-6, 440, 448, 446, hexc('#F3DDB8'), 5); c.rect(-6, 458, 448, 463, hexc('#B98E5E'), 2)
    # OVEN (bata)
    shadow(c, (10, 322, 136, 446), 6, 90)
    c.rect(12, 318, 132, 446, hexc('#A04C33'), 34)
    for row in range(0, 13):
        y = 330 + row * 9.5; c.line([(20, y), (124, y)], (230, 190, 160, 110), 1)
        for xx in range(20 + (row % 2) * 9, 124, 18): c.line([(xx, y), (xx, y + 9.5)], (230, 190, 160, 90), 1)
    c.rect(26, 348, 118, 428, hexc('#3A3A3E'), 34); c.rect(33, 355, 111, 424, hexc('#1F1411'), 30)
    glow = Image.new('RGBA', c.im.size, (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
    for i in range(14):
        a = int(130 * (1 - i / 14)); gd.ellipse(c.P(40 + i * 1.5, 400 + i * .5 - 18, 104 - i * 1.5, 425), fill=(255, 140 - i * 3, 40, a))
    c.im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(3 * c.k)))
    c.rect(20, 424, 124, 446, hexc('#6E5648'), 3); c.ell(92, 331, 108, 347, hexc('#EDE6D6'), hexc('#333333'), 1.5); c.line([(100, 339), (104, 334)], (180, 30, 30, 255), 1.5)
    c.rect(86, 292, 108, 322, hexc('#44474B'), 3); c.rect(82, 286, 112, 296, hexc('#2C2E31'), 3)
    # DISPLAY CASE
    shadow(c, (140, 376, 266, 448), 5, 80)
    c.rect(142, 372, 262, 446, (255, 246, 228, 135), 6, hexc('#7A4A2A'), 4.5)
    c.rect(146, 376, 258, 380, (255, 230, 170, 140)); c.rect(144, 408, 260, 412, hexc('#8A5A36'))
    c.rect(142, 436, 262, 446, hexc('#6B3F25'), 3)
    for xx in (170, 205): c.poly([(xx, 376), (xx + 12, 376), (xx - 14, 436), (xx - 26, 436)], (255, 255, 255, 34))
    # ESPRESSO MACHINE
    shadow(c, (306, 340, 428, 448), 5, 90)
    c.rect(310, 352, 422, 436, hexc('#F1E6D2'), 10); c.rect(310, 410, 422, 436, hexc('#C26A40'), 6); c.rect(310, 352, 422, 358, hexc('#FFF6E4'), 4)
    c.rect(314, 340, 418, 354, hexc('#A7ADB3'), 4)
    for cx in (330, 362, 394): c.rect(cx - 9, 330, cx + 9, 342, hexc('#FFFFFF'), 3, hexc('#D8D0C2'), 1)
    c.ell(354, 362, 378, 386, hexc('#FFFFFF'), hexc('#55595E'), 2); c.line([(366, 374), (372, 367)], (200, 40, 40, 255), 1.5)
    for cx in (330, 402): c.ell(cx - 6, 368, cx + 6, 380, hexc('#4A4D52'))
    for cx in (342, 392):
        c.rect(cx - 10, 398, cx + 10, 406, hexc('#2A2A2E'), 3); c.rect(cx + (8 if cx < 360 else -34), 400, cx + (34 if cx < 360 else -8), 404, hexc('#2A2A2E'), 2)
        c.rect(cx - 9, 418, cx + 9, 434, hexc('#FFFFFF'), 4, hexc('#D8D0C2'), 1); c.rect(cx - 7, 420, cx + 7, 426, hexc('#6A3A22'), 3)
    c.rect(312, 434, 420, 446, hexc('#9AA0A6'), 3)
    for xx in range(318, 416, 8): c.line([(xx, 437), (xx, 443)], (60, 62, 66, 200), 1.4)
    c.line([(420, 372), (432, 384), (434, 430)], hexc('#B8BEC4'), 3)
    c.save('counter')

# ---------------------------------------------------------------- DOOR
def make_door():
    k = 4; c = Cv(116, 352, k)
    c.rect(0, 0, 116, 352, hexc('#8B5A35'), 6); c.rect(5, 5, 111, 347, None, 4, hexc('#A9703F'), 2)
    c.rect(14, 16, 102, 156, (190, 225, 240, 150), 28, hexc('#5A3018'), 5)   # kaca
    c.poly([(26, 24), (44, 24), (24, 150), (14, 150)], (255, 255, 255, 60))
    c.rect(14, 174, 102, 336, None, 4, hexc('#6A3D1F'), 4); c.rect(24, 184, 92, 326, (0, 0, 0, 24), 3)
    c.ell(86, 210, 98, 222, hexc('#D6B36A'), hexc('#8A6A2A'), 1.5)
    sign = Cv(60, 28, k); sign.rect(0, 0, 60, 28, hexc('#2B2F2E'), 4, hexc('#C19A6B'), 2); sign.text((30, 14), 'OPEN', font(FB, 12, k), (255, 213, 120, 255), 'mm')
    c.im.alpha_composite(sign.im, (int(28 * k), int(60 * k)))
    c.save('door', 1 / k * S)

# ---------------------------------------------------------------- TABLE / CHAIR / BIN
def make_table(idx, cloth, trim):
    k = 4; c = Cv(150, 120, k)
    c.ell(24, 96, 126, 116, (0, 0, 0, 60))                       # bayangan
    c.rect(66, 46, 84, 100, hexc('#6A3A22'), 5); c.ell(36, 92, 114, 110, hexc('#5A3018'))
    c.ell(10, 24, 140, 70, hexc(trim))                           # tepi tebal
    c.ell(10, 20, 140, 62, hexc(trim)); c.ell(14, 22, 136, 58, hexc(cloth))
    c.ell(24, 28, 126, 52, None, (255, 255, 255, 90), 1.2); c.ell(38, 33, 112, 47, None, (0, 0, 0, 24), 1)
    c.save(f'table_{idx}', 1 / k * S)

def make_chair():
    k = 4; c = Cv(100, 150, k)
    c.ell(14, 134, 86, 148, (0, 0, 0, 50))
    for x in (16, 76): c.rect(x, 80, x + 8, 140, hexc('#5A3018'), 3)
    c.rect(8, 6, 92, 100, hexc('#8B5A35'), 18, hexc('#5A3018'), 3)
    for x in (22, 38, 54, 70): c.rect(x, 18, x + 10, 94, hexc('#A9703F'), 4)
    c.rect(14, 10, 86, 20, hexc('#C08A55'), 6)
    c.save('chair', 1 / k * S)

def make_bin():
    k = 4; c = Cv(70, 96, k)
    c.ell(8, 84, 62, 94, (0, 0, 0, 60))
    c.poly([(10, 26), (60, 26), (54, 88), (16, 88)], hexc('#6B7480')); c.poly([(10, 26), (22, 26), (26, 88), (16, 88)], (255, 255, 255, 40))
    for x in (24, 35, 46): c.line([(x, 34), (x - 1 + (x - 35) * .05, 82)], (40, 44, 52, 200), 2)
    c.ell(6, 16, 64, 36, hexc('#8A939E'), hexc('#4B535C'), 2); c.ell(26, 10, 44, 20, None, hexc('#4B535C'), 3)
    c.ell(24, 56, 46, 74, None, (120, 220, 140, 230), 2.2)
    c.save('bin', 1 / k * S)

# ---------------------------------------------------------------- DECOR
def leaf(w, h, col):
    k = 4; c = Cv(w, h, k); c.ell(0, 0, w, h, hexc(col)); c.line([(w / 2, 2), (w / 2, h - 2)], (255, 255, 255, 70), 1.2)
    c.poly([(w * .5, h * .5), (w, h * .5), (w * .5, h)], (0, 0, 0, 22)); return c.im
def make_plant(name, w, h, nleaf, cols):
    import random; random.seed(len(name)); k = 4; c = Cv(w, h, k)
    c.ell(w * .22, h - 12, w * .78, h - 2, (0, 0, 0, 55))
    for i in range(nleaf):
        a = -70 + 140 * i / max(1, nleaf - 1) + random.uniform(-8, 8); L = random.uniform(.5, .78) * h * .62; lf = leaf(int(w * .24), int(L), random.choice(cols))
        lf = lf.rotate(a, expand=True, resample=Image.BICUBIC, center=(lf.width / 2, lf.height)); 
        ox = w / 2 * k + math.sin(math.radians(a)) * 0; c.im.alpha_composite(lf, (int(w / 2 * k - lf.width / 2 + math.sin(math.radians(a)) * L * k * .5), int((h - 34) * k - lf.height + 10 * k)))
    c.poly([(w * .26, h - 46), (w * .74, h - 46), (w * .66, h - 8), (w * .34, h - 8)], hexc('#C46A44')); c.rect(w * .22, h - 52, w * .78, h - 42, hexc('#D77B52'), 4)
    c.poly([(w * .26, h - 46), (w * .34, h - 46), (w * .42, h - 8), (w * .34, h - 8)], (255, 255, 255, 30))
    c.save(name, 1 / k * S)

def make_rug():
    k = 3; c = Cv(440, 150, k)
    for i, col in enumerate(['#8E3F2A', '#E9D2A8', '#2F6F73', '#E9D2A8', '#C26A40']):
        m = i * 12; c.ell(m, m * .34, 440 - m, 150 - m * .34, hexc(col, 235))
    c.ell(70, 28, 370, 122, None, (255, 255, 255, 80), 1.5); 
    for a in range(0, 360, 20): 
        x = 220 + 120 * math.cos(math.radians(a)); y = 75 + 36 * math.sin(math.radians(a)); c.ell(x - 4, y - 2, x + 4, y + 2, hexc('#E9D2A8', 200))
    c.save('rug', 1 / k * S)

def make_frames():
    k = 4; c = Cv(60, 150, k)
    for y, kind in ((0, 0), (80, 1)):
        c.rect(0, y, 60, y + 68, hexc('#6A3A22'), 3); c.rect(5, y + 5, 55, y + 63, hexc('#F3E3C8'), 2)
        if kind == 0:
            c.rect(20, y + 24, 40, y + 46, hexc('#FFFFFF'), 5, hexc('#C26A40'), 2); c.arc = None
            c.line([(40, y + 30), (46, y + 30), (46, y + 40), (40, y + 40)], hexc('#C26A40'), 2); c.line([(26, y + 20), (28, y + 12)], (170, 140, 110, 255), 1.5); c.line([(34, y + 20), (36, y + 12)], (170, 140, 110, 255), 1.5)
        else:
            c.poly([(8, y + 58), (24, y + 30), (36, y + 48), (44, y + 24), (53, y + 58)], hexc('#2F6F73')); c.ell(38, y + 10, 50, y + 22, hexc('#E9A93A'))
    c.save('frames', 1 / k * S)

def make_neon():
    k = 4; w, h = 130, 62; base = Cv(w, h, k)
    base.text((w / 2, 24), 'OPEN', font(FB, 30, k), (255, 90, 160, 255), 'mm'); base.rect(8, 6, w - 8, h - 14, None, 14, (110, 230, 255, 255), 2.4)
    base.line([(30, h - 8), (100, h - 8)], (255, 90, 160, 255), 3)
    glow = base.im.filter(ImageFilter.GaussianBlur(7 * k)); out = Image.new('RGBA', base.im.size, (0, 0, 0, 0)); out.alpha_composite(glow); out.alpha_composite(glow); out.alpha_composite(base.im)
    out.resize((int(w * S), int(h * S)), Image.LANCZOS).save(f'{OUT}/neon.png')

def make_jukebox():
    k = 4; w, h = 92, 150; c = Cv(w, h, k)
    c.ell(8, 140, 84, 150, (0, 0, 0, 55))
    c.rect(8, 8, 84, 146, hexc('#8E3F2A'), 38); c.rect(14, 14, 78, 140, None, 34, hexc('#E9A93A'), 3)
    c.rect(22, 28, 70, 76, hexc('#FFE6A8'), 24, hexc('#D6B36A'), 3); c.ell(30, 36, 62, 68, None, (200, 90, 50, 255), 3); c.ell(40, 46, 52, 58, hexc('#2A1A14'))
    for i in range(6): c.line([(22, 88 + i * 6), (70, 88 + i * 6)], (40, 20, 12, 220), 2)
    for i, col in enumerate(['#FF5A8F', '#6EE7FF', '#FFD54F']): c.ell(24 + i * 17, 124, 36 + i * 17, 136, hexc(col))
    c.poly([(12, 40), (18, 14), (24, 14), (18, 40)], (255, 255, 255, 50))
    c.save('jukebox', 1 / k * S)

if __name__ == '__main__':
    make_wall(); make_counter(); make_door()
    make_table(0, '#F3E3C8', '#8B5A35'); make_table(1, '#C9E4DE', '#6A3A22'); make_table(2, '#F2C6C2', '#6A3A22'); make_chair(); make_bin()
    make_plant('plant_big', 100, 190, 9, ['#2F7D4A', '#3E9A5C', '#256B3E']); make_plant('plant_small', 60, 100, 6, ['#3E9A5C', '#4DB06C']); make_rug(); make_frames(); make_neon(); make_jukebox()
    print('ok')
