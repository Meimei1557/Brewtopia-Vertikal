"""Musik latar ceria (bossa nova, 116 BPM) - tidak bikin ngantuk."""
import numpy as np, subprocess, os
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, fftconvolve
SR = 32000; OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio'); rng = np.random.default_rng(11)
def t_(d): return np.arange(int(SR * d)) / SR
def lp(x, f): return sosfilt(butter(2, f, 'low', fs=SR, output='sos'), x)
def hp(x, f): return sosfilt(butter(2, f, 'high', fs=SR, output='sos'), x)
def bp(x, a, b): return sosfilt(butter(2, [a, b], 'band', fs=SR, output='sos'), x)
def noise(d): return rng.standard_normal(int(SR * d))
def fade(x, a=.004, r=.03):
    e = np.ones(len(x)); na = max(1, int(a * SR)); nr = max(1, int(r * SR)); e[:na] = np.linspace(0, 1, na); e[-nr:] = np.linspace(1, 0, nr); return x * e
def place(buf, x, at):
    i = int(at * SR)
    if i < len(buf): j = min(len(buf), i + len(x)); buf[i:j] += x[:j - i]
mf = lambda m: 440 * 2 ** ((m - 69) / 12)
def guitar(f, d, amp=1.0):
    t = t_(d); mod = 2.6 * np.exp(-t * 14); y = np.sin(2 * np.pi * f * t + mod * np.sin(2 * np.pi * f * t)) * np.exp(-t * 5.5) + .25 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 18)
    return fade(y * amp)
def marimba(f, d, amp=1.0):
    t = t_(d); y = np.sin(2 * np.pi * f * t) * np.exp(-t * 7) + .45 * np.sin(2 * np.pi * 4 * f * t) * np.exp(-t * 22) + .2 * np.sin(2 * np.pi * 9.9 * f * t) * np.exp(-t * 40)
    return fade(y * amp, .002, .02)
def bass(f, d, amp=1.0):
    t = t_(d); y = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2) + .35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 6)
    return fade(y * amp, .006, .04)
BPM = 116; beat = 60 / BPM; bars = 16; total = bars * 4 * beat; n = int(SR * total) + int(SR * 3)
chords = [[52, 55, 59, 62], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 65],   # Cmaj9 Am9 Dm9 G13
          [52, 55, 59, 62], [57, 61, 64, 67], [53, 57, 60, 64], [55, 59, 62, 67]]
roots = [48, 45, 50, 43, 48, 45, 50, 43]
mix = np.zeros(n); sw = .06 * beat
patt = [0, 1.5, 2.5, 3.5]   # strum bossa
for bar in range(bars):
    t0 = bar * 4 * beat; ch = chords[bar % 8]; r = mf(roots[bar % 8])
    for pi_, pb in enumerate(patt):
        for k, m in enumerate(ch): place(mix, guitar(mf(m), .9 * beat, .20 if pi_ else .26), t0 + pb * beat + k * .012 + (sw if pb % 1 else 0))
    for pb, fr in ((0, 1), (1.5, 1.5), (2, 1), (3.5, 1.5)): place(mix, bass(r * fr, .9 * beat, .55), t0 + pb * beat)
    for s in range(16):                                               # shaker 16th
        place(mix, hp(noise(.04), 7500) * np.exp(-t_(.04) * 90) * (.17 if s % 4 == 0 else (.11 if s % 2 == 0 else .07)), t0 + s * beat / 4 + (sw * .5 if s % 2 else 0))
    for pb in ([0, 1.5, 3] if bar % 2 == 0 else [1, 2]):              # rim click (clave bossa)
        place(mix, np.sin(2 * np.pi * 1700 * t_(.05)) * np.exp(-t_(.05) * 80) * .22 + hp(noise(.05), 3000) * np.exp(-t_(.05) * 70) * .1, t0 + pb * beat)
    for pb in (0, 2):                                                 # kick lembut
        kk = t_(.22); place(mix, np.sin(2 * np.pi * (52 + 90 * np.exp(-kk * 30)) * kk) * np.exp(-kk * 11) * .55, t0 + pb * beat)
    sn = t_(.1); place(mix, bp(noise(.1), 1500, 6000) * np.exp(-sn * 28) * .28, t0 + 3 * beat)   # clap tipis di beat 4
# melodi marimba: 2 frase berulang + variasi
scale = [72, 74, 76, 79, 81, 84, 86]; motif = [0, 2, 4, 2, 5, 4, 2, 0, 1, 3, 5, 3, 6, 5, 3, 1]
for bar in range(4, bars):
    t0 = bar * 4 * beat
    for s in range(8):
        idx = motif[(bar * 8 + s) % len(motif)]
        if (s % 2 == 0) or rng.random() < .55:
            m = scale[idx] - (12 if (bar % 4 == 3 and s < 2) else 0)
            place(mix, marimba(mf(m), .55 * beat, .30), t0 + s * .5 * beat + (sw if s % 2 else 0))
mix = lp(mix, 6500)
loop_n = int(SR * total); irn = int(SR * .5); ir = noise(.5) * np.exp(-np.arange(irn) / (SR * .1)); ir = lp(ir, 5000)
wet = fftconvolve(mix, ir)[:len(mix) + irn]; wet /= np.max(np.abs(wet)) + 1e-9
y = np.pad(mix, (0, irn)); m = min(len(y), len(wet)); y[:m] += wet[:m] * .12 * np.max(np.abs(mix))
out = y[:loop_n].copy(); tail = y[loop_n:loop_n + int(SR * 1.0)]; out[:len(tail)] += tail
out = out / (np.max(np.abs(out)) + 1e-9) * .82
wavfile.write('/tmp/bossa.wav', SR, (out * 32767).astype(np.int16))
subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', '/tmp/bossa.wav', '-c:a', 'libvorbis', '-q:a', '4', f'{OUT}/cafe_bossa.ogg'], check=True)
print('ok', round(total, 1), 's', 'rms', round(float(np.sqrt((out ** 2).mean())), 3))
