#!/usr/bin/env python3
"""Planche de spectrogrammes — contrôle visuel du sound design."""
import sys, os, struct
import numpy as np
from PIL import Image, ImageDraw


def read_wav(path):
    with open(path, "rb") as f:
        d = f.read()
    i = d.index(b"fmt ") + 8
    ch, sr = struct.unpack("<HI", d[i + 2:i + 8])
    j = d.index(b"data", i) + 8
    a = np.frombuffer(d[j:], dtype="<i2").astype(np.float32) / 32768.0
    if ch > 1:
        a = a.reshape(-1, ch).mean(1)
    return a, sr


def spectrogram(x, sr, W=320, H=150, fmax=9000):
    nfft = 1024
    hop = max(1, (len(x) - nfft) // W)
    cols = []
    win = np.hanning(nfft).astype(np.float32)
    for i in range(W):
        s = i * hop
        seg = x[s:s + nfft]
        if len(seg) < nfft:
            seg = np.pad(seg, (0, nfft - len(seg)))
        cols.append(np.abs(np.fft.rfft(seg * win)))
    S = np.array(cols).T                                    # (freq, temps)
    freqs = np.fft.rfftfreq(nfft, 1 / sr)
    keep = freqs <= fmax
    S = S[keep]
    # échelle de fréquence logarithmique : plus proche de la perception
    n = S.shape[0]
    idx = np.unique(np.clip((np.logspace(0, np.log10(n - 1), H)).astype(int), 0, n - 1))
    S = np.array([S[max(0, idx[k] - 1):idx[k] + 2].mean(0) for k in range(len(idx))])
    S = 20 * np.log10(S + 1e-6)
    S = np.clip((S - S.max() + 80) / 80, 0, 1) ** 1.8
    S = np.flipud(S)
    img = np.zeros((S.shape[0], S.shape[1], 3), np.uint8)
    img[..., 0] = (np.clip(S * 1.5 - 0.15, 0, 1) * 255)
    img[..., 1] = (np.clip(S * 1.15, 0, 1) * 255)
    img[..., 2] = (np.clip(S * 0.65 + 0.10, 0, 1) * 255)
    return Image.fromarray(img).resize((W, H), Image.BILINEAR)


def main():
    files = sys.argv[1:-1]
    out = sys.argv[-1]
    cols, W, H, lab, pad = 3, 320, 150, 16, 5
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (W + pad) + pad, rows * (H + lab + pad) + pad), (12, 12, 14))
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(files):
        x, sr = read_wav(f)
        r, c = divmod(i, cols)
        px, py = pad + c * (W + pad), pad + r * (H + lab + pad)
        rms = float(np.sqrt((x ** 2).mean()))
        cen = float((np.abs(np.fft.rfft(x[:65536])) *
                     np.fft.rfftfreq(min(65536, len(x)), 1 / sr)).sum()
                    / (np.abs(np.fft.rfft(x[:65536])).sum() + 1e-9))
        d.text((px, py + 2), f"{os.path.basename(f)[:-4]}  {len(x)/sr:.1f}s "
                             f"rms={rms:.3f} centre={cen:.0f}Hz", fill=(190, 200, 185))
        sheet.paste(spectrogram(x, sr, W, H), (px, py + lab))
    sheet.save(out)
    print("sheet ->", out)


if __name__ == "__main__":
    main()
