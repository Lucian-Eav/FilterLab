"""Build the home study plates once from the bundled mountain. No runtime dependencies."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

assets = Path(__file__).resolve().parents[1] / 'app' / 'assets'
source = Image.open(assets / 'welcome-mountain.jpg').convert('RGB')
# All three chips use the same 224 x 144 source pixels, pixel indices start at zero.
x, y, w, h = 163, 422, 224, 144
patch = source.crop((x, y, x+w, y+h))
patch.save(assets / 'ridge-original.png')
rgb = np.asarray(patch, dtype=np.float64) / 255
y_luma = rgb @ [0.299, 0.587, 0.114]
# Taper the luminance patch to reduce boundary leakage in the display spectrum.
window = np.outer(np.hanning(h), np.hanning(w))
spectrum = np.log1p(np.abs(np.fft.fftshift(np.fft.fft2(y_luma * window))))
level = np.percentile(spectrum, 99.7)
Image.fromarray(np.uint8(np.rint(255 * np.clip(spectrum / level, 0, 1)))).save(assets / 'ridge-spectrum.png')
# Reflect borders before Gaussian low-pass filtering so opposite sides do not bleed together.
margin, sigma = 20, 4.0
padded = np.pad(rgb, ((margin,margin),(margin,margin),(0,0)), mode='reflect')
fy = np.fft.fftfreq(padded.shape[0])[:, None]
fx = np.fft.fftfreq(padded.shape[1])[None, :]
transfer = np.exp(-2*np.pi**2*sigma**2*(fx**2+fy**2))
filtered = np.fft.ifft2(np.fft.fft2(padded, axes=(0,1)) * transfer[:,:,None], axes=(0,1)).real
filtered = filtered[margin:margin+h, margin:margin+w]
Image.fromarray(np.uint8(np.rint(255 * np.clip(filtered, 0, 1)))).save(assets / 'ridge-lowpass.png')
# Four unobtrusive registration corners identify the sampled ridge on the overview.
overview = source.copy()
draw = ImageDraw.Draw(overview)
for xx, dx in [(x,1),(x+w-1,-1)]:
    for yy, dy in [(y,1),(y+h-1,-1)]:
        lines=[(xx+dx*15,yy),(xx,yy),(xx,yy+dy*15)]
        draw.line(lines, fill=(33,48,48), width=4)
        draw.line(lines, fill=(220,245,230), width=2)
overview.crop((0,100,600,700)).save(assets / 'ridge-overview.jpg', quality=90)
print('Built mountain overview and three same-region study images.')
