#!/usr/bin/env python3
"""Verifica la geometría del símbolo de CeldaPro sobre los PNG renderizados.

No hay juicio visual disponible, así que comprobamos hechos medibles:
simetría, encuadre, proporción de colores de marca, que el rayo esté dentro
de la celda, y legibilidad a tamaños pequeños.

Uso: python3 verificar_logo.py
"""
import sys
from PIL import Image
import numpy as np

VERDE = (46, 125, 50)
VERDE_CLARO = (67, 160, 71)
VERDE_OSCURO = (27, 94, 32)
AMBAR = (255, 179, 0)
AMBAR_CLARO = (255, 197, 61)
CLARO = (255, 255, 255)
CLARO2 = (216, 233, 220)

fails = []


def check(cond, ok_msg, fail_msg):
    if cond:
        print(f'  ✓ {ok_msg}')
    else:
        fails.append(fail_msg)
        print(f'  ✗ {fail_msg}')


def load(path):
    img = Image.open(path).convert('RGBA')
    return img, np.array(img)


def count_colors(rgb, opaque, targets, tol=45):
    total = 0
    for t in targets:
        d = np.abs(rgb - np.array(t)).sum(axis=2)
        total += int(((d < tol) & opaque).sum())
    return total


def verificar_marca(path, nombre, requiere_claro=True, full_bleed=False):
    print(f'\n=== {nombre} ===')
    img, a = load(path)
    h, w = a.shape[:2]
    alpha = a[..., 3].astype(int)
    rgb = a[..., :3].astype(int)
    opaque = alpha > 40
    tinta = 100 * opaque.sum() / (w * h)
    print(f'{w}x{h}, tinta {tinta:.1f} %')

    check(opaque.sum() > 0.05 * w * h, 'dibujo presente', 'dibujo casi vacío')

    borde = 2
    toca = (opaque[:borde, :].any() or opaque[-borde:, :].any() or
            opaque[:, :borde].any() or opaque[:, -borde:].any())
    if full_bleed:
        check(toca, 'a sangre (fondo completo, esperado en el icono)',
              'el icono micro debería cubrir todo el lienzo')
    else:
        check(not toca, 'sin recorte en los bordes', 'el dibujo toca el borde')

    izq, der = opaque[:, :w // 2], np.fliplr(opaque[:, w - w // 2:])
    n = min(izq.shape[1], der.shape[1])
    sim = (izq[:, :n] == der[:, :n]).mean()
    check(sim > 0.90, f'simetría especular {sim:.0%}',
          f'poco simétrico ({sim:.0%})')

    verde = count_colors(rgb, opaque, [VERDE, VERDE_CLARO, VERDE_OSCURO])
    ambar = count_colors(rgb, opaque, [AMBAR, AMBAR_CLARO])
    claro = count_colors(rgb, opaque, [CLARO, CLARO2], 30)
    print(f'  verde {verde} px | ámbar {ambar} px | claro {claro} px')
    check(verde > 200, 'verde de marca presente', 'falta el verde de marca')
    check(ambar > 200, 'ámbar de acento presente', 'falta el ámbar de acento')
    if requiere_claro:
        check(claro > 200, 'cuerpo de celda presente', 'falta el cuerpo de celda')

    # El verde (anillo) debe dominar sobre el ámbar (acento).
    check(verde > ambar, 'el verde domina (color primario)',
          f'el ámbar domina al verde ({ambar} vs {verde})')

    # El rayo ámbar debe estar en el tercio central.
    ambar_mask = np.zeros_like(opaque)
    for t in (AMBAR, AMBAR_CLARO):
        ambar_mask |= (np.abs(rgb - np.array(t)).sum(axis=2) < 45) & opaque
    if ambar_mask.any():
        ay, ax = np.where(ambar_mask)
        cx, cy = (ax.min() + ax.max()) / 2, (ay.min() + ay.max()) / 2
        dx, dy = abs(cx - w / 2) / w, abs(cy - 0.56 * h) / h
        check(dx < 0.06 and dy < 0.12,
              f'rayo centrado en la celda (centro {cx:.0f},{cy:.0f})',
              f'rayo descentrado ({cx:.0f},{cy:.0f})')

    return img


def legibilidad(img, nombre, tamanos, esperado):
    """esperado: 'completa' (celda clara + anillo verde + rayo ámbar) o
    'compacta' (celda verde + rayo ámbar)."""
    print(f'\n=== Legibilidad en pequeño — {nombre} ===')
    for px in tamanos:
        small = img.resize((px, px), Image.LANCZOS)
        s = np.array(small)
        sa, srgb = s[..., 3].astype(int), s[..., :3].astype(int)
        smask = sa > 60
        if not smask.any():
            fails.append(f'{nombre}: a {px}px no queda nada')
            print(f'  ✗ {px}px: vacío')
            continue
        verde = count_colors(srgb, smask, [VERDE, VERDE_CLARO, VERDE_OSCURO], 90)
        ambar = count_colors(srgb, smask, [AMBAR, AMBAR_CLARO], 90)
        claro = count_colors(srgb, smask, [CLARO, CLARO2], 60)

        if esperado == 'completa':
            ok = (verde + ambar) >= 4 and claro >= 40
        elif esperado == 'micro':
            # A 16 px solo tiene que leerse el rayo sobre el verde.
            ok = verde >= 40 and ambar >= 20
        else:
            # En la compacta el rayo debe seguir leyéndose como ámbar
            # dentro de una celda verde.
            ok = verde >= 8 and ambar >= 2

        print(f'  {"✓" if ok else "✗"} {px}px: verde {verde}, ámbar {ambar}, '
              f'claro {claro}')
        if not ok:
            fails.append(f'{nombre}: ilegible a {px}px')


base = '/root/proyectos/celdapro/brand/out/'
full = verificar_marca(base + 'logo-mark-512.png', 'Marca completa (con anillo)')
legibilidad(full, 'completa', [48, 96, 192], 'completa')

compact = verificar_marca(base + 'logo-mark-compact-512.png',
                          'Marca compacta (sin anillo)', requiere_claro=False)
legibilidad(compact, 'compacta', [24, 32, 48], 'compacta')

micro = verificar_marca(base + 'logo-mark-micro-512.png',
                        'Marca micro (solo rayo)', requiere_claro=False,
                        full_bleed=True)
legibilidad(micro, 'micro', [16, 24, 32], 'micro')

print()
if fails:
    print(f'RESULTADO: {len(fails)} problema(s)')
    for f in fails:
        print(f'  - {f}')
    sys.exit(1)
print('RESULTADO: TODO OK')
