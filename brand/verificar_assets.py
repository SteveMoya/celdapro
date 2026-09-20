#!/usr/bin/env python3
"""Verifica los assets de marca: lockups, icono de app y capa adaptativa."""
import sys
from PIL import Image
import numpy as np

OUT = '/root/proyectos/celdapro/brand/out/'
SRC = '/root/proyectos/celdapro/brand/source/'
VERDE = np.array((46, 125, 50))
VERDE2 = np.array((67, 160, 71))
VERDE3 = np.array((27, 94, 32))
AMBAR = np.array((255, 179, 0))
AMBAR2 = np.array((255, 197, 61))
BLANCO = np.array((255, 255, 255))
TINTA = np.array((15, 31, 20))

fallos = []


def check(c, ok, mal):
    print(f'  {"✓" if c else "✗"} {ok if c else mal}')
    if not c:
        fallos.append(mal)


def load(p):
    a = np.array(Image.open(p).convert('RGBA'))
    return a, a[..., :3].astype(int), a[..., 3].astype(int)


def cnt(rgb, mask, targets, tol=48):
    t = 0
    for c in targets:
        t += int(((np.abs(rgb - c).sum(axis=2) < tol) & mask).sum())
    return t


print('=== Lockup horizontal ===')
a, rgb, al = load(OUT + 'logo-horizontal.png')
m = al > 40
check(m.any(), 'tiene contenido', 'vacío')
check(cnt(rgb, m, [VERDE, VERDE2, VERDE3]) > 500, 'verde presente',
      'sin verde')
check(cnt(rgb, m, [TINTA], 90) > 2000, 'tinta del nombre presente',
      'sin tinta del nombre')
# "Pro" (verde) debe estar a la derecha del símbolo.
ys, xs = np.where(m)
verde_mask = np.zeros_like(m)
for c in (VERDE, VERDE2, VERDE3):
    verde_mask |= (np.abs(rgb - c).sum(axis=2) < 48) & m
vy, vx = np.where(verde_mask)
check(vx.max() > 0.6 * a.shape[1], 'la marca va a la izquierda y "Pro" a la derecha',
      'la composición no está bien repartida')
check(xs.max() > a.shape[1] * 0.95, 'el lockup ocupa todo el ancho (viewBox ajustado)',
      'queda aire a la derecha: viewBox sin ajustar')

print('\n=== Lockup horizontal oscuro ===')
a, rgb, al = load(OUT + 'logo-horizontal-oscuro.png')
m = al > 40
blanco = cnt(rgb, m, [BLANCO], 60)
check(blanco > 2000, f'nombre en blanco ({blanco} px)', 'el nombre no es blanco')

print('\n=== Lockup vertical ===')
a, rgb, al = load(OUT + 'logo-vertical.png')
m = al > 40
h, w = m.shape
sup = m[:h // 2, :].sum()
inf = m[h // 2:, :].sum()
check(sup > 0 and inf > 0, 'símbolo arriba y texto abajo', 'composición vacía')

print('\n=== Icono de app (1024) ===')
a, rgb, al = load(OUT + 'icono-app.png')
m = al > 40
verde = cnt(rgb, m, [VERDE, VERDE2, VERDE3])
ambar = cnt(rgb, m, [AMBAR, AMBAR2])
blanco = cnt(rgb, m, [BLANCO], 30)
print(f'  verde {verde} | ámbar {ambar} | blanco {blanco}')
check(verde > 100000, 'fondo verde de marca', 'falta el fondo verde')
check(blanco > 5000, 'celda blanca', 'falta la celda blanca')
check(ambar > 1000, 'rayo ámbar', 'falta el rayo ámbar')
# Esquinas redondeadas: la esquina debe ser transparente.
check(al[3, 3] < 40, 'esquinas redondeadas (transparentes)',
      'las esquinas no están redondeadas')

print('\n=== Icono redondo ===')
a, rgb, al = load(OUT + 'icono-app-redondo.png')
h, w = al.shape
esquinas = [al[3, 3], al[3, w - 4], al[h - 4, 3], al[h - 4, w - 4]]
centro = al[h // 2, w // 2]
check(max(esquinas) < 40 and centro > 200,
      f'recorte circular (esquinas transparentes {esquinas}, centro {centro})',
      'no parece circular')

print('\n=== Capa adaptativa (frente) ===')
a, rgb, al = load(OUT + 'icono-adaptativo-frente.png')
m = al > 40
ys, xs = np.where(m)
# Android recorta a un círculo del 66 % central: la marca debe caber ahí.
cx, cy = a.shape[1] / 2, a.shape[0] / 2
radio_seguro = 0.33 * a.shape[0]
esquinas = max(
    np.hypot(x - cx, y - cy) for x, y in
    [(xs.min(), ys.min()), (xs.max(), ys.min()),
     (xs.min(), ys.max()), (xs.max(), ys.max())])
print(f'  marca hasta {esquinas:.0f} px del centro; zona segura {radio_seguro:.0f} px')
check(esquinas <= radio_seguro,
      'la marca cabe en la zona segura (no la recorta el sistema)',
      f'la marca sale de la zona segura ({esquinas:.0f} > {radio_seguro:.0f})')
check(al[0, 0] < 40, 'fondo transparente (el color va en la capa de fondo)',
      'la capa de frente no es transparente')

print('\n=== Icono a tamaño real de lanzador ===')
ico = Image.open(OUT + 'icono-app.png').convert('RGBA')
for px in (48, 72, 96):
    s = np.array(ico.resize((px, px), Image.LANCZOS))
    sm, srgb = s[..., 3] > 60, s[..., :3].astype(int)
    v = cnt(srgb, sm, [VERDE, VERDE2, VERDE3], 90)
    b = cnt(srgb, sm, [BLANCO], 60)
    am = cnt(srgb, sm, [AMBAR, AMBAR2], 90)
    ok = v > 100 and b > 20 and am > 1
    print(f'  {"✓" if ok else "✗"} {px}px: verde {v}, blanco {b}, ámbar {am}')
    if not ok:
        fallos.append(f'icono ilegible a {px}px')

print()
if fallos:
    print(f'RESULTADO: {len(fallos)} problema(s)')
    for f in fallos:
        print(f'  - {f}')
    sys.exit(1)
print('RESULTADO: TODO OK')
