"""Sintesis efek suara & musik lofi kafe untuk Brewtopia (numpy/scipy + ffmpeg)."""
import numpy as np, subprocess, os
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, fftconvolve

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets')
os.makedirs(f'{OUT}/sfx', exist_ok=True); os.makedirs(f'{OUT}/audio', exist_ok=True)
rng = np.random.default_rng(42)

def t_(d): return np.arange(int(SR * d)) / SR
def lp(x, f, o=2): return sosfilt(butter(o, f, 'low', fs=SR, output='sos'), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, 'high', fs=SR, output='sos'), x)
def bp(x, a, b, o=2): return sosfilt(butter(o, [a, b], 'band', fs=SR, output='sos'), x)
def noise(d): return rng.standard_normal(int(SR * d))
def fade(x, a=0.005, r=0.02):
    n = len(x); e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] = np.linspace(1, 0, nr); return x * e
def norm(x, peak=0.85): return x / (np.max(np.abs(x)) + 1e-9) * peak
def place(buf, x, at):
    i = int(at * SR); j = min(len(buf), i + len(x))
    if i < len(buf): buf[i:j] += x[:j - i]
def reverb(x, rt=0.9, mix=0.2):
    n = int(SR * rt); ir = noise(rt) * np.exp(-np.arange(n) / (SR * rt / 4.5))
    ir = lp(ir, 5000); wet = fftconvolve(x, ir)[:len(x) + n]; wet /= (np.max(np.abs(wet)) + 1e-9)
    out = np.zeros(len(wet)); out[:len(x)] += x * (1 - mix); out += wet * mix * np.max(np.abs(x)); return out
def bell(f, d, amp=1.0, parts=((1, 1), (2.76, .5), (5.4, .25), (8.9, .12)), decay=5.0):
    t = t_(d); y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t * decay * (0.6 + 0.4 * r)) for r, a in parts)
    return fade(y * amp, 0.002, 0.05)
def pluck(f, d, amp=1.0, bright=2.0):
    t = t_(d); mod = bright * np.exp(-t * 7); y = np.sin(2 * np.pi * f * t + mod * np.sin(2 * np.pi * f * t))
    return fade(y * np.exp(-t * 3.2) * amp, 0.002, 0.04)
def save(name, x, peak=0.85):
    x = norm(x, peak); wavfile.write(f'{OUT}/sfx/{name}.wav', SR, (x * 32767).astype(np.int16))

# ---------------- SFX ----------------
# pintu: bunyi klik kayu + lonceng pintu
d = 1.5; b = np.zeros(int(SR * d))
place(b, fade(lp(noise(.12), 500) * np.exp(-t_(.12) * 30) * 1.4, .001, .03), 0.0)           # klik gagang
place(b, fade(lp(noise(.35), 260) * np.exp(-t_(.35) * 9) * .5, .02, .1), 0.03)                # engsel
place(b, bell(2093, 1.3, .55), 0.14); place(b, bell(2637, 1.2, .45), 0.30)
save('door_open', reverb(b, .5, .12))
# lonceng meja (pesanan baru)
save('ding', reverb(bell(1760, 1.1, 1), .6, .15))
# lonceng oven selesai
b = np.zeros(int(SR * 1.2)); place(b, bell(2960, .5, 1), 0); place(b, bell(2960, .6, .9), .22); save('oven_ding', b)
# penggiling kopi
d = 1.4; t = t_(d); motor = (np.sin(2 * np.pi * 95 * t) + .5 * np.sin(2 * np.pi * 190 * t)) * (0.7 + 0.3 * np.sin(2 * np.pi * 26 * t))
crunch = bp(noise(d), 1200, 5200) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 17 * t))) ** 2
save('grind', fade(lp(motor * .5 + crunch * 1.1, 6000), .08, .15))
# espresso: pompa + aliran air
d = 2.2; t = t_(d); pump = np.sin(2 * np.pi * (70 + 12 * t) * t) * (0.8 + 0.2 * np.sin(2 * np.pi * 40 * t))
stream = bp(noise(d), 1500, 6500) * np.clip(t / 0.5, 0, 1) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t))
drip = np.zeros_like(t)
for k in np.arange(1.3, 2.1, .17): place(drip, pluck(900 + 80 * rng.random(), .12, .3, 1), k)
save('brew', fade(lp(pump * .35 + stream * .6, 7000) + drip, .12, .3))
# uap susu
d = 1.6; t = t_(d); hiss = hp(noise(d), 3000) * (np.sin(np.pi * t / d) ** .6); wh = np.sin(2 * np.pi * (1800 + 200 * np.sin(2 * np.pi * 3 * t)) * t) * .04
save('steam', fade(hiss * .8 + wh, .1, .3))
# tuang
d = 1.1; t = t_(d); glug = np.sin(2 * np.pi * (300 + 140 * np.abs(np.sin(2 * np.pi * 6 * t))) * t) * .3
save('pour', fade(bp(noise(d), 800, 4200) * .7 * np.sin(np.pi * t / d) ** .5 + glug, .1, .25))
# koin / kasir
b = np.zeros(int(SR * .9)); place(b, fade(hp(noise(.03), 2500) * np.exp(-t_(.03) * 90), .0005, .01) * .6, 0)
place(b, bell(1318, .5, 1, ((1, 1), (2.4, .6), (3.8, .3)), 7), 0.02); place(b, bell(1975, .7, 1, ((1, 1), (2.4, .6), (3.8, .3)), 6), 0.11)
save('coin', reverb(b, .35, .1))
# kombo: arpeggio naik berkilau
b = np.zeros(int(SR * 1.3))
for i, f in enumerate([784, 988, 1175, 1568, 1976]): place(b, bell(f, .7, .8, ((1, 1), (2, .4), (3, .2)), 6), i * .075)
place(b, hp(noise(.5), 6000) * np.exp(-t_(.5) * 7) * .08, .3); save('combo', reverb(b, .8, .22))
# sempurna
b = np.zeros(int(SR * 1.4))
for i, f in enumerate([659, 830, 988]): place(b, bell(f, 1.1, .8, ((1, 1), (2, .5), (3, .25)), 4), i * .09)
save('perfect', reverb(b, .9, .25))
# sampah: remas + whoosh + dentum tong
d = 1.0; b = np.zeros(int(SR * d))
crk = bp(noise(.4), 1500, 6000) * (rng.random(int(SR * .4)) > .985) * 8; crk = lp(crk, 5000) + bp(noise(.4), 2000, 5000) * .15 * np.exp(-t_(.4) * 6)
place(b, crk, 0)
t = t_(.35); sw = bp(noise(.35), 400, 3500) * np.sin(np.pi * t / .35); place(b, sw * .5, .12)
place(b, fade(np.sin(2 * np.pi * (140 - 40 * t_(.5)) * t_(.5)) * np.exp(-t_(.5) * 12) + bp(noise(.5), 500, 1400) * np.exp(-t_(.5) * 15) * .6, .001, .08) * 1.0, .42)
save('trash', reverb(b, .3, .1))
# salah/gagal
b = np.zeros(int(SR * .6)); place(b, pluck(260, .3, 1, 0.5), 0); place(b, pluck(196, .45, 1, .5), .16); save('error', lp(b, 2500))
# klik
save('tap', fade(np.sin(2 * np.pi * 820 * t_(.07)) * np.exp(-t_(.07) * 60) + lp(noise(.07), 3000) * np.exp(-t_(.07) * 90) * .4, .0005, .02), .6)
# pop
t = t_(.12); save('pop', np.sin(2 * np.pi * (380 + 2800 * t) * t) * np.exp(-t * 22), .6)
# naik level
b = np.zeros(int(SR * 2.2))
for i, f in enumerate([523, 659, 784, 1047]): place(b, bell(f, .6, .8, ((1, 1), (2, .45), (3, .2)), 5), i * .13)
for f in (523, 659, 784, 1047): place(b, bell(f, 1.5, .5, ((1, 1), (2, .4)), 3), .6)
save('levelup', reverb(b, 1.2, .3))
# event (lonceng tangan)
b = np.zeros(int(SR * 1.6))
for i in range(3): place(b, bell(1568, .5, .9), i * .18)
save('event', reverb(b, .5, .15))
# akhir hari
b = np.zeros(int(SR * 2.4))
for i, f in enumerate([659, 587, 523, 392]): place(b, bell(f, 1.2, .8, ((1, 1), (2, .4)), 3), i * .35)
save('day_end', reverb(b, 1.4, .3))

# ---------------- MUSIK LOFI ----------------
BPM = 76; beat = 60 / BPM; bars = 8; total = bars * 4 * beat
n = int(SR * total) + int(SR * 3)
mf = lambda m: 440 * 2 ** ((m - 69) / 12)
def rhodes(f, d, amp=1.0):
    t = t_(d); I = 2.3 * np.exp(-t * 4.0)
    y = np.sin(2 * np.pi * f * t + I * np.sin(2 * np.pi * f * t)) + .22 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 16)
    return fade(y * np.exp(-t * 1.7) * amp, .004, .12)
chords = [[52, 55, 59, 62], [57, 60, 64, 67], [53, 57, 60, 64], [53, 59, 62, 64],
          [55, 59, 62, 64], [55, 59, 60, 64], [57, 60, 64, 65], [53, 59, 62, 67]]
roots = [48, 45, 50, 43, 52, 45, 50, 43]
mix = np.zeros(n); sw = .13 * beat
for bar in range(bars):
    t0 = bar * 4 * beat
    for k, m in enumerate(chords[bar]): place(mix, rhodes(mf(m), 2.6 * beat, .30), t0 + k * .018)
    for k, m in enumerate(chords[bar][1:]): place(mix, rhodes(mf(m), 1.1 * beat, .20), t0 + 2.5 * beat + sw + k * .012)
    r = mf(roots[bar]); bt = lambda f, d: fade(np.sin(2 * np.pi * f * t_(d)) * np.exp(-t_(d) * 2.4) + .3 * np.sin(2 * np.pi * 2 * f * t_(d)) * np.exp(-t_(d) * 5), .01, .08)
    place(mix, bt(r, 1.6 * beat) * .5, t0); place(mix, bt(r, 1.0 * beat) * .4, t0 + 2 * beat + sw); place(mix, bt(r * 1.5, .8 * beat) * .3, t0 + 3 * beat)
    for bi in range(4):                                  # drum
        tb = t0 + bi * beat
        if bi in (0, 2):
            kk = t_(.28); place(mix, np.sin(2 * np.pi * (48 + 90 * np.exp(-kk * 28)) * kk) * np.exp(-kk * 9) * .9, tb)
        else:
            sn = t_(.22); place(mix, (bp(noise(.22), 1200, 5200) * np.exp(-sn * 16) * .4 + np.sin(2 * np.pi * 190 * sn) * np.exp(-sn * 22) * .25), tb)
        for h, off in ((0, 0), (1, .5 * beat + sw)):
            ht = t_(.05); place(mix, hp(noise(.05), 7000) * np.exp(-ht * 70) * (.14 if h == 0 else .09), tb + off)
mel = [74, 76, 79, 81, 84]; rs = np.random.default_rng(5)
for bar in range(bars):
    for s in range(8):
        if rs.random() < .34:
            m = mel[rs.integers(0, len(mel))] - (12 if rs.random() < .4 else 0)
            place(mix, pluck(mf(m), 1.2, .22, 1.2), bar * 4 * beat + s * .5 * beat + (sw if s % 2 else 0))
crack = (rng.random(n) > .9993) * rng.standard_normal(n) * .5; mix += hp(lp(crack, 6000), 800) * .5 + hp(noise(n / SR), 5000) * .004
mix = lp(mix, 3800)
loop_n = int(SR * total); wet = reverb(mix, 1.3, .22)
y = np.zeros(loop_n); y += wet[:loop_n]; tail = wet[loop_n:loop_n + int(SR * 2.5)]; y[:len(tail)] += tail
y = norm(y, .8); wavfile.write('/tmp/lofi.wav', SR, (y * 32767).astype(np.int16))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', '/tmp/lofi.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/audio/cafe_lofi.ogg'], check=True)
print('done', round(total, 1), 's')
