#!/usr/bin/env python3
"""Genera todos los assets de marca de CeldaPro a partir de los SVG fuente.

- Lockups (horizontal y vertical, claro y oscuro) con viewBox ajustado al
  contenido real midiendo el PNG renderizado (nada de dejar aire de más).
- Icono de app (cuadrado, redondo y adaptativo Android).
- Set completo de PNG para Android (mipmaps) y PNG sueltos.

Requiere: rsvg-convert, Pillow, fonts-inter.
"""
import subprocess
import sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path('/root/proyectos/celdapro/brand')
SRC = ROOT / 'source'
OUT = ROOT / 'out'
OUT.mkdir(exist_ok=True)

TINTA = '#0F1F14'
VERDE = '#2E7D32'
AMBAR = '#FFB300'
BLANCO = '#FFFFFF'

log = []


def render(svg_path, png_path, w, h=None):
    h = h or w
    subprocess.run(
        ['rsvg-convert', '-w', str(w), '-h', str(h), str(svg_path),
         '-o', str(png_path)],
        check=True)
    return png_path


def ink_bbox(png_path, umbral=40):
    a = np.array(Image.open(png_path).convert('RGBA'))
    mask = a[..., 3] > umbral
    if not mask.any():
        return None
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max(), ys.max()


def lockup(nombre, vertical=False, on_dark=False):
    """Crea un lockup con viewBox ajustado al contenido."""
    ink = BLANCO if on_dark else TINTA
    verde = '#66BB6A' if on_dark else VERDE
    ambar = '#FFC53D' if on_dark else VERDE

    if vertical:
        W, H = 900, 700
        marca_uso = (W - 260) / 2
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <linearGradient id="r" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="{'#81C784' if on_dark else '#1B5E20'}"/>
      <stop offset="1" stop-color="{'#A5D6A7' if on_dark else '#43A047'}"/>
    </linearGradient>
    <linearGradient id="c" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#D8E9DC"/>
    </linearGradient>
    <linearGradient id="b" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFC53D"/><stop offset="1" stop-color="#FFA000"/>
    </linearGradient>
  </defs>
  <g transform="translate({(W - 512 * (260 / 512)) / 2}, 60) scale({260 / 512})">
    <path d="M 331 156 A 150 150 0 1 1 181 156" fill="none" stroke="url(#r)" stroke-width="30" stroke-linecap="round"/>
    <path d="M 209 137 L 163 143 L 186 181 Z" fill="{'#A5D6A7' if on_dark else '#2E7D32'}"/>
    <rect x="228" y="150" width="56" height="54" rx="14" fill="#FFFFFF"/>
    <rect x="196" y="192" width="120" height="184" rx="30" fill="url(#c)"/>
    <path d="M 278 226 L 220 298 L 248 298 L 234 356 L 294 280 L 264 280 Z" fill="url(#b)"/>
  </g>
  <text x="{W/2}" y="500" text-anchor="middle" font-family="Inter"
        font-weight="700" font-size="150" letter-spacing="-4">
    <tspan fill="{ink}">Celda</tspan><tspan fill="{verde}">Pro</tspan>
  </text>
  <text x="{W/2}" y="580" text-anchor="middle" font-family="Inter"
        font-weight="500" font-size="44" letter-spacing="6" fill="{'#A5D6A7' if on_dark else '#5F6B63'}">
    GESTIÓN DE CELDAS DE LITIO
  </text>
</svg>'''
    else:
        W, H = 1500, 520
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs>
    <linearGradient id="r" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="{'#81C784' if on_dark else '#1B5E20'}"/>
      <stop offset="1" stop-color="{'#A5D6A7' if on_dark else '#43A047'}"/>
    </linearGradient>
    <linearGradient id="c" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#D8E9DC"/>
    </linearGradient>
    <linearGradient id="b" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFC53D"/><stop offset="1" stop-color="#FFA000"/>
    </linearGradient>
  </defs>
  <g transform="translate(40, 60) scale({400 / 512})">
    <path d="M 331 156 A 150 150 0 1 1 181 156" fill="none" stroke="url(#r)" stroke-width="30" stroke-linecap="round"/>
    <path d="M 209 137 L 163 143 L 186 181 Z" fill="{'#A5D6A7' if on_dark else '#2E7D32'}"/>
    <rect x="228" y="150" width="56" height="54" rx="14" fill="#FFFFFF"/>
    <rect x="196" y="192" width="120" height="184" rx="30" fill="url(#c)"/>
    <path d="M 278 226 L 220 298 L 248 298 L 234 356 L 294 280 L 264 280 Z" fill="url(#b)"/>
  </g>
  <text x="490" y="300" font-family="Inter" font-weight="700"
        font-size="190" letter-spacing="-5">
    <tspan fill="{ink}">Celda</tspan><tspan fill="{verde}">Pro</tspan>
  </text>
</svg>'''

    tmp_svg = OUT / f'_{nombre}-tmp.svg'
    tmp_svg.write_text(svg)
    tmp_png = OUT / f'_{nombre}-tmp.png'
    render(tmp_svg, tmp_png, W * 2, H * 2)

    bbox = ink_bbox(tmp_png)
    if bbox is None:
        print(f'  ✗ {nombre}: no se detectó tinta')
        return None

    esc = (W * 2) / W  # escala del render
    x0, y0, x1, y1 = [v / esc for v in bbox]
    pad = 10
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(W, x1 + pad), min(H, y1 + pad)
    w2, h2 = x1 - x0, y1 - y0

    final = svg.replace(f'viewBox="0 0 {W} {H}"',
                        f'viewBox="{x0:.1f} {y0:.1f} {w2:.1f} {h2:.1f}"')
    final = final.replace(f'width="{W}" height="{H}"',
                          f'width="{w2:.0f}" height="{h2:.0f}"')
    dst_svg = SRC / f'{nombre}.svg'
    dst_svg.write_text(final)
    render(dst_svg, OUT / f'{nombre}.png', int(w2 * 3), int(h2 * 3))
    tmp_svg.unlink(missing_ok=True)
    tmp_png.unlink(missing_ok=True)

    log.append(f'{nombre}.svg  ({w2:.0f}x{h2:.0f} unidades)')
    print(f'  ✓ {nombre}: viewBox ajustado a {w2:.0f}x{h2:.0f}')
    return dst_svg


print('Lockups')
lockup('logo-horizontal')
lockup('logo-horizontal-oscuro', on_dark=True)
lockup('logo-vertical', vertical=True)

print('\nIcono de app')
# Cuadrado (fondo verde + marca), redondo y adaptativo Android.
ICON_BG = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#2E7D32"/><stop offset="1" stop-color="#1B5E20"/>
  </linearGradient></defs>
  <rect width="512" height="512" rx="{r}" fill="url(#g)"/>
</svg>'''


def icono(nombre, radio, escala, fondo=True, sombra=False):
    marca = (SRC / 'logo-mark.svg').read_text()
    inner = marca.split('>', 1)[1].rsplit('</svg>', 1)[0]
    bg = (f'<rect width="512" height="512" rx="{radio}" fill="url(#bg)"/>'
          if fondo else '<rect width="512" height="512" fill="none"/>')
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#2E7D32"/><stop offset="1" stop-color="#1B5E20"/>
    </linearGradient>
  </defs>
  {bg}
  <g transform="translate(256,256) scale({escala}) translate(-256,-256)">
    {inner}
  </g>
</svg>'''
    p = SRC / f'{nombre}.svg'
    p.write_text(svg)
    render(p, OUT / f'{nombre}.png', 1024)
    log.append(f'{nombre}.png (1024)')
    print(f'  ✓ {nombre}')
    return p


icono('icono-app', 112, 0.62)
icono('icono-app-redondo', 256, 0.62)
# Adaptativo: el fondo va aparte y la marca dentro de la zona segura (66 %).
icono('icono-adaptativo-frente', 0, 0.44, fondo=False)
(SRC / 'icono-adaptativo-fondo.svg').write_text(
    ICON_BG.replace('{r}', '0').replace('#2E7D32', '#2E7D32'))
render(SRC / 'icono-adaptativo-fondo.svg',
       OUT / 'icono-adaptativo-fondo.png', 1024)

print('\nTamaños de icono para Android')
MIPMAP = {
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96,
    'xxhdpi': 144, 'xxxhdpi': 192,
}
destino = Path('/root/proyectos/celdapro/android/app/src/main/res')
for dpi, px in MIPMAP.items():
    d = destino / f'mipmap-{dpi}'
    d.mkdir(parents=True, exist_ok=True)
    render(SRC / 'icono-app.svg', d / 'ic_launcher.png', px)
    render(SRC / 'icono-app-redondo.svg', d / 'ic_launcher_round.png', px)
    print(f'  ✓ mipmap-{dpi}: ic_launcher {px}px, round {px}px')
log.append('mipmaps Android (5 densidades)')

print('\nIcono de notificación (micro, blanco sobre transparente)')
mono = (SRC / 'logo-mark-micro.svg').read_text()
micro_blanco = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512">
  <path d="M 330 92 L 168 288 L 244 288 L 200 420 L 356 226 L 280 226 Z" fill="#FFFFFF"/>
</svg>'''
(SRC / 'icono-notificacion.svg').write_text(micro_blanco)
render(SRC / 'icono-notificacion.svg', OUT / 'icono-notificacion.png', 96)
log.append('icono-notificacion.png')
print('  ✓ icono-notificacion')

print('\nAssets generados:')
for e in log:
    print(f'  · {e}')
