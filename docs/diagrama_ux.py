#!/usr/bin/env python3
"""Genera el diagrama de flujo UI/UX de CeldaPro en SVG (y PNG).

Se escribe como script, y no como SVG a mano, para poder mover una caja o
cambiar un texto sin recalcular coordenadas.

Incluye un **verificador geométrico**: como el diagrama no se puede revisar a
ojo desde aquí, el propio script comprueba que ninguna caja se salga del
lienzo, que no se solapen sin querer y que ningún texto se desborde de su
caja. Si algo está mal, lo dice y falla.

Uso:
    python3 docs/diagrama_ux.py            # escribe el SVG y el PNG, y verifica
"""

import html
import pathlib
import subprocess
import sys

# ---------- Paleta de la marca (la misma de lib/core/theme.dart) ----------
VERDE = "#2E7D32"
VERDE_CLARO = "#E8F5E9"
VERDE_BORDE = "#A5D6A7"
AMBAR = "#FFB300"
AMBAR_CLARO = "#FFF8E1"
AZUL = "#1565C0"
AZUL_CLARO = "#E3F2FD"
ROJO = "#C62828"
ROJO_CLARO = "#FFEBEE"
GRIS = "#455A64"
GRIS_CLARO = "#ECEFF1"
GRIS_SUAVE = "#90A4AE"
TEXTO = "#263238"
FONDO = "#F7F9F8"
BLANCO = "#FFFFFF"
BORDE = "#DCE3E0"

ANCHO = 1680
MARGEN = 56

# Ancho medio de un carácter en Inter, en fracción del tamaño de fuente.
# Se sobreestima a propósito: prefiero que el verificador avise de más a que
# se me cuele un texto desbordado.
FACTOR_NORMAL = 0.545
FACTOR_BOLD = 0.585


def esc(s):
    return html.escape(str(s))


def solapan(a, b, margen=0):
    ax, ay, aw, ah = a[:4]
    bx, by, bw, bh = b[:4]
    return not (
        ax + aw <= bx + margen
        or bx + bw <= ax + margen
        or ay + ah <= by + margen
        or by + bh <= ay + margen
    )


class Lienzo:
    def __init__(self):
        self.partes = []
        self.cajas = []   # (x, y, w, h, etiqueta, verificar)
        self.textos = []  # (x, y_anclaje, ancho, alto, texto, ancla)

    def add(self, s):
        self.partes.append(s)

    # ---------- primitivas ----------

    def caja(self, x, y, w, h, relleno=BLANCO, borde=BORDE, radio=14, grosor=1.5,
             etiqueta=None, verificar=True):
        self.add(
            f'<rect x="{x:.0f}" y="{y:.0f}" width="{w:.0f}" height="{h:.0f}" '
            f'rx="{radio}" fill="{relleno}" stroke="{borde}" stroke-width="{grosor}"/>'
        )
        self.cajas.append((x, y, w, h, etiqueta or f"caja@{x:.0f},{y:.0f}",
                           verificar))
        return (x, y, w, h)

    def texto(self, x, y, s, tam=16, peso="400", color=TEXTO, ancla="start",
              espaciado=0, opacidad=1):
        extra = f' letter-spacing="{espaciado}"' if espaciado else ""
        extra += f' opacity="{opacidad}"' if opacidad != 1 else ""
        self.add(
            f'<text x="{x:.0f}" y="{y:.0f}" font-family="Inter" font-size="{tam:g}" '
            f'font-weight="{peso}" fill="{color}" text-anchor="{ancla}"{extra}>'
            f'{esc(s)}</text>'
        )
        factor = FACTOR_BOLD if str(peso) in ("600", "700", "800") else FACTOR_NORMAL
        ancho = len(str(s)) * tam * factor
        self.textos.append((x, y, ancho, tam, str(s), ancla))

    def linea(self, x1, y1, x2, y2, color=BORDE, grosor=2, guion=None):
        d = f' stroke-dasharray="{guion}"' if guion else ""
        self.add(
            f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" '
            f'stroke="{color}" stroke-width="{grosor}"{d} stroke-linecap="round"/>'
        )

    def flecha(self, x1, y1, x2, y2, color=VERDE, grosor=2.5):
        self.add(
            f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" '
            f'stroke="{color}" stroke-width="{grosor}" marker-end="url(#punta)" '
            f'stroke-linecap="round"/>'
        )

    def camino(self, d, color=VERDE, grosor=2.5):
        self.add(
            f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{grosor}" '
            f'marker-end="url(#punta)" stroke-linecap="round"/>'
        )

    def bateria(self, x, y, w, h, nivel, color):
        """El sello visual de la app: una batería rellena hasta su nivel."""
        self.add(
            f'<rect x="{x:.0f}" y="{y:.0f}" width="{w}" height="{h}" rx="4" '
            f'fill="none" stroke="{color}" stroke-width="2"/>'
        )
        self.add(
            f'<rect x="{x+w+2:.0f}" y="{y+h*0.32:.1f}" width="4" '
            f'height="{h*0.36:.1f}" rx="1.5" fill="{color}"/>'
        )
        interior = (w - 6) * max(0.0, min(1.0, nivel))
        if interior > 0:
            self.add(
                f'<rect x="{x+3:.0f}" y="{y+3:.0f}" width="{interior:.1f}" '
                f'height="{h-6}" rx="2" fill="{color}"/>'
            )

    # ---------- verificación geométrica ----------

    def verificar(self):
        """Comprueba el diagrama por geometría, ya que no se puede ver."""
        problemas = []

        for x, y, w, h, etiq, _ in self.cajas:
            if x < 0 or y < 0 or x + w > ANCHO or y + h > self.alto:
                problemas.append(
                    f"LA CAJA «{etiq}» SE SALE DEL LIENZO: "
                    f"x={x:.0f}..{x+w:.0f} (máx {ANCHO}), "
                    f"y={y:.0f}..{y+h:.0f} (máx {self.alto})"
                )

        verificables = [c for c in self.cajas if c[5]]
        for i in range(len(verificables)):
            for j in range(i + 1, len(verificables)):
                if solapan(verificables[i], verificables[j], margen=2):
                    problemas.append(
                        f"CAJAS SOLAPADAS: «{verificables[i][4]}» y "
                        f"«{verificables[j][4]}»"
                    )

        rects = []
        for tx, ty, ancho, alto, s, ancla in self.textos:
            if ancla == "middle":
                izq = tx - ancho / 2
            elif ancla == "end":
                izq = tx - ancho
            else:
                izq = tx
            der = izq + ancho
            rects.append((izq, ty - alto * 0.80, ancho, alto * 1.15, s))

            if izq < 2 or der > ANCHO - 2:
                problemas.append(
                    f"TEXTO FUERA DEL LIENZO: «{s[:46]}» "
                    f"({izq:.0f}..{der:.0f})"
                )

            # La caja más pequeña que contiene el punto de anclaje del texto.
            contenedoras = [
                c for c in self.cajas
                if c[0] <= tx <= c[0] + c[2] and c[1] <= ty - alto * 0.35
                <= c[1] + c[3]
            ]
            if not contenedoras:
                continue
            cx, cy, cw, ch, etiq, _ = min(
                contenedoras, key=lambda c: c[2] * c[3]
            )
            # Un poco de aire dentro del borde.
            if izq < cx + 3 or der > cx + cw - 3:
                problemas.append(
                    f"TEXTO DESBORDADO en «{etiq}»: «{s[:46]}» ocupa "
                    f"{izq:.0f}..{der:.0f} y la caja va de {cx+3:.0f} a "
                    f"{cx+cw-3:.0f}"
                )

        # Colisión entre textos: es el otro síntoma de un trazado roto. Se
        # pide un solape apreciable para no marcar textos que solo se rozan
        # (por ejemplo un título y su subtítulo, que van a distinta altura).
        for i in range(len(rects)):
            for j in range(i + 1, len(rects)):
                a, b = rects[i], rects[j]
                if not solapan(a, b):
                    continue
                solape_x = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
                solape_y = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
                if solape_x <= 0 or solape_y <= 0:
                    continue
                area = solape_x * solape_y
                menor = min(a[2] * a[3], b[2] * b[3])
                if menor > 0 and area / menor > 0.30:
                    problemas.append(
                        f"TEXTOS ENCIMADOS: «{a[4][:34]}» y «{b[4][:34]}»"
                    )

        return problemas

    def svg(self):
        cab = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{ANCHO}" height="{self.alto}"
 viewBox="0 0 {ANCHO} {self.alto}" font-family="Inter">
<defs>
  <marker id="punta" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6"
          markerHeight="6" orient="auto-start-reverse">
    <path d="M 0 0 L 10 5 L 0 10 z" fill="{VERDE}"/>
  </marker>
  <linearGradient id="energia" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0%" stop-color="{VERDE}"/>
    <stop offset="100%" stop-color="{AMBAR}"/>
  </linearGradient>
</defs>
<rect width="{ANCHO}" height="{self.alto}" fill="{FONDO}"/>
'''
        return cab + "\n".join(self.partes) + "\n</svg>\n"


def seccion(l, y, numero, titulo, subtitulo):
    l.add(f'<rect x="{MARGEN}" y="{y}" width="4" height="34" rx="2" fill="{VERDE}"/>')
    l.texto(MARGEN + 18, y + 17, f"{numero}. {titulo}", tam=23, peso="700")
    l.texto(MARGEN + 18, y + 38, subtitulo, tam=14, color=GRIS_SUAVE)
    return y + 62


def main():
    l = Lienzo()
    l.alto = 2600
    y = 0

    # ---------- Cabecera ----------
    l.add(f'<rect x="0" y="0" width="{ANCHO}" height="112" fill="{VERDE}"/>')
    l.texto(MARGEN, 52, "CeldaPro", tam=34, peso="700", color=BLANCO, espaciado="-0.5")
    l.texto(MARGEN, 82, "Flujo de usuario y mapa de pantallas · versión 0.10.0",
            tam=15, color="#C8E6C9")
    l.texto(ANCHO - MARGEN, 48, "Taller de restauración de celdas de litio",
            tam=14, color="#C8E6C9", ancla="end")
    l.texto(ANCHO - MARGEN, 72, "100 % local · sin cuentas · Android",
            tam=14, color="#C8E6C9", ancla="end")

    y = 160

    # ============================================================
    # 1. ARRANQUE
    # ============================================================
    y = seccion(l, y, 1, "Arranque",
                "Lo primero que ve el usuario decide si entiende la app o se pierde")
    cy = y

    l.caja(MARGEN, cy, 190, 84, VERDE_CLARO, VERDE_BORDE, etiqueta="abre-app")
    l.texto(MARGEN + 95, cy + 38, "Abre la app", tam=17, peso="700", color=VERDE,
            ancla="middle")
    l.texto(MARGEN + 95, cy + 60, "sin conexión", tam=13, color=GRIS, ancla="middle")

    dx = MARGEN + 280
    l.caja(dx, cy, 230, 84, AMBAR_CLARO, AMBAR, etiqueta="primera-vez")
    l.texto(dx + 115, cy + 40, "¿Es la primera vez?", tam=16, peso="700",
            color="#8D6E00", ancla="middle")
    l.texto(dx + 115, cy + 62, "preferencia onboarding_visto", tam=12, color=GRIS,
            ancla="middle")

    l.flecha(MARGEN + 190, cy + 42, dx, cy + 42)

    # Rama SÍ
    ox = dx + 120
    l.texto(dx + 40, cy + 100, "sí", tam=13, peso="700", color=VERDE)
    l.camino(f"M {dx+40} {cy+84} L {dx+40} {cy+150} L {ox} {cy+150}", color=VERDE)
    l.caja(ox, cy + 108, 300, 88, BLANCO, VERDE, etiqueta="onboarding")
    l.texto(ox + 150, cy + 142, "ONBOARDING", tam=17, peso="700", color=VERDE,
            ancla="middle")
    l.texto(ox + 150, cy + 164, "4 pantallas · se puede saltar", tam=13, color=GRIS,
            ancla="middle")
    l.texto(ox + 150, cy + 184, "se puede repetir desde Ajustes", tam=12,
            color=GRIS_SUAVE, ancla="middle")

    # Rama NO
    l.texto(dx + 250, cy + 100, "no", tam=13, peso="700", color=GRIS)
    l.linea(dx + 232, cy + 42, dx + 328, cy + 42, GRIS_SUAVE, 2)
    l.caja(dx + 330, cy, 220, 84, GRIS_CLARO, GRIS_SUAVE, etiqueta="hay-celdas")
    l.texto(dx + 440, cy + 40, "¿Hay celdas?", tam=16, peso="700", color=GRIS,
            ancla="middle")
    l.texto(dx + 440, cy + 62, "total en la base", tam=12, color=GRIS_SUAVE,
            ancla="middle")

    # Desde ¿hay celdas?
    rx = dx + 620
    l.texto(dx + 380, cy + 100, "sí", tam=13, peso="700", color=GRIS)
    l.camino(f"M {dx+380} {cy+84} L {dx+380} {cy+150} L {rx} {cy+150}",
             color=GRIS_SUAVE, grosor=2)
    l.caja(rx, cy + 108, 210, 88, BLANCO, GRIS_SUAVE, etiqueta="resumen")
    l.texto(rx + 105, cy + 142, "Resumen", tam=16, peso="700", color=GRIS,
            ancla="middle")
    l.texto(rx + 105, cy + 164, "hay trabajo que mirar", tam=12, color=GRIS_SUAVE,
            ancla="middle")

    l.texto(dx + 560, cy + 100, "no", tam=13, peso="700", color=VERDE)
    l.camino(f"M {dx+560} {cy+84} L {dx+560} {cy+244} L {ox} {cy+244}", color=VERDE)
    l.caja(ox, cy + 244, 300, 76, VERDE_CLARO, VERDE_BORDE, etiqueta="inventario-nuevo")
    l.texto(ox + 150, cy + 276, "Inventario", tam=16, peso="700", color=VERDE,
            ancla="middle")
    l.texto(ox + 150, cy + 298, "con el onboarding al frente", tam=12, color=GRIS,
            ancla="middle")

    # Nota del cambio (a la derecha, sin chocar con nada)
    l.caja(rx - 24, cy + 214, 470, 118, AMBAR_CLARO, AMBAR, etiqueta="nota-arranque")
    l.texto(rx + 16, cy + 242, "EL CAMBIO", tam=13, peso="700", color="#8D6E00")
    l.texto(rx + 16, cy + 266, "Hoy la app abre siempre en Resumen y, con el", tam=13)
    l.texto(rx + 16, cy + 286, "taller vacío, no resume nada: solo un icono", tam=13)
    l.texto(rx + 16, cy + 306, "gris. Un taller nuevo pasa a abrir donde", tam=13)
    l.texto(rx + 16, cy + 326, "tiene que empezar.", tam=13)

    y = cy + 372

    # ============================================================
    # 2. ONBOARDING
    # ============================================================
    y = seccion(l, y, 2, "Onboarding",
                "Cuatro pantallas que enseñan el oficio, no un muro de texto")
    cy = y

    pasos = [
        ("1", "Bienvenida", "Qué es CeldaPro", "batería que se llena"),
        ("2", "El viaje de una celda", "Las 7 etapas en secuencia", "línea de energía"),
        ("3", "Identificar y medir", "Etiqueta, OCR, test masivo", "pulso de escaneo"),
        ("4", "Entregar y proteger", "Informes, etiquetas, respaldo", "confirmación"),
    ]
    tam_caja = 336
    hueco = 34
    for i, (num, titulo, sub, anim) in enumerate(pasos):
        px = MARGEN + i * (tam_caja + hueco)
        l.caja(px, cy, tam_caja, 132, BLANCO, BORDE, etiqueta=f"paso-{num}")
        l.add(f'<circle cx="{px+34}" cy="{cy+36}" r="18" fill="{VERDE}"/>')
        l.texto(px + 34, cy + 42, num, tam=17, peso="700", color=BLANCO, ancla="middle")
        l.texto(px + 62, cy + 42, titulo, tam=16, peso="700")
        l.texto(px + 22, cy + 76, sub, tam=13.5, color=GRIS)
        l.add(f'<rect x="{px+22}" y="{cy+92}" width="{tam_caja-44}" height="26" rx="13"'
              f' fill="{VERDE_CLARO}"/>')
        l.texto(px + tam_caja / 2, cy + 110, f"animación: {anim}", tam=12.5,
                color=VERDE, ancla="middle", peso="600")
        if i < 3:
            l.flecha(px + tam_caja + 4, cy + 66, px + tam_caja + hueco - 4, cy + 66)

    by = cy + 156
    l.caja(MARGEN, by, 290, 56, VERDE, VERDE, etiqueta="saltar")
    l.texto(MARGEN + 145, by + 35, "Saltar  →", tam=16, peso="600", color=BLANCO,
            ancla="middle")
    l.texto(MARGEN + 306, by + 24, "Visible desde la primera pantalla.", tam=13.5)
    l.texto(MARGEN + 306, by + 46, "Obligar a ver cuatro pantallas molesta.", tam=13.5,
            color=GRIS_SUAVE)

    l.caja(MARGEN + 830, by, 400, 56, VERDE_CLARO, VERDE_BORDE, etiqueta="cta-final")
    l.texto(MARGEN + 1030, by + 35, "Registrar mi primera celda  →", tam=15.5,
            peso="700", color=VERDE, ancla="middle")
    l.texto(MARGEN + 1250, by + 24, "Termina en la acción,", tam=13.5)
    l.texto(MARGEN + 1250, by + 46, "no en un «listo».", tam=13.5, color=GRIS_SUAVE)

    y = by + 104

    # ============================================================
    # 3. LAS CUATRO SECCIONES
    # ============================================================
    y = seccion(l, y, 3, "Las cuatro secciones",
                "Qué hace el usuario en cada una y a dónde puede ir")
    cy = y

    secciones = [
        ("Resumen", "Métricas del taller", VERDE,
         ["Batería de progreso", "Pendientes de medir", "Celdas recientes",
          "Aviso de respaldo"], "Lleva a Inventario y Lotes"),
        ("Inventario", "El corazón de la app", VERDE,
         ["Ficha de celda", "Alta / edición", "Medir (test)",
          "Etiquetas · Informes", "Escanear QR", "Leer con OCR",
          "Test masivo", "Agrupar para packs"], "Lleva a 8 pantallas"),
        ("Lotes", "Trabajo en conjunto", AZUL,
         ["Alta de lote", "Ver sus celdas", "Cambios en bloque",
          "Test masivo", "Informe del lote", "Agrupar el lote"],
         "Lleva a 5 pantallas"),
        ("Ajustes", "Configurar y proteger", GRIS,
         ["Umbrales de SoH", "Motivos de rechazo", "Respaldo / restaurar",
          "Marca del taller (Pro)", "Actualizaciones", "Ver onboarding otra vez"],
         "Lleva a 2 pantallas"),
    ]

    ancho_sec = 372
    hueco = 24
    alto_max = 0
    for i, (nombre, desc, color, acciones, pie) in enumerate(secciones):
        px = MARGEN + i * (ancho_sec + hueco)
        alto_caja = 92 + len(acciones) * 30 + 46
        alto_max = max(alto_max, alto_caja)
        l.caja(px, cy, ancho_sec, alto_caja, BLANCO, color, radio=16, grosor=2,
               etiqueta=f"sec-{nombre}")
        # Cabecera de color: va dentro de la caja, así que no se verifica aparte.
        l.add(f'<path d="M {px} {cy+16} a 16 16 0 0 1 16 -16 h {ancho_sec-32} '
              f'a 16 16 0 0 1 16 16 v 46 h -{ancho_sec} z" fill="{color}"/>')
        l.texto(px + 20, cy + 32, nombre, tam=19, peso="700", color=BLANCO)
        l.texto(px + 20, cy + 52, desc, tam=12.5, color=BLANCO, opacidad=0.85)

        for j, accion in enumerate(acciones):
            ay = cy + 96 + j * 30
            l.add(f'<circle cx="{px+26}" cy="{ay+4}" r="4" fill="{color}"/>')
            l.texto(px + 42, ay + 9, accion, tam=14)

        l.linea(px + 16, cy + alto_caja - 42, px + ancho_sec - 16,
                cy + alto_caja - 42, BORDE, 1)
        l.texto(px + 20, cy + alto_caja - 16, pie, tam=12.5, color=GRIS_SUAVE,
                peso="600")

    y = cy + alto_max + 56

    # ============================================================
    # 4. EL VIAJE DE UNA CELDA
    # ============================================================
    y = seccion(l, y, 4, "El viaje de una celda",
                "Las 7 etapas del proceso, con la línea de energía que las une")
    cy = y

    etapas = [
        ("Recepcionada", "llega del lote", 0.10, GRIS_SUAVE),
        ("En test", "se mide", 0.35, VERDE),
        ("Clasificada", "A / B / C", 0.60, VERDE),
        ("Balanceada", "voltaje igualado", 0.75, VERDE),
        ("Reempacada", "montada en pack", 0.90, VERDE),
        ("Aprobada QA", "supera el control", 1.00, VERDE),
    ]

    ancho_et = 218
    hueco_et = 30
    x0 = MARGEN + 40
    ancho_total = len(etapas) * (ancho_et + hueco_et) - hueco_et
    x1 = MARGEN + ancho_total - 40

    # La línea de energía va por detrás: se dibuja antes de las cajas.
    l.add(f'<rect x="{x0}" y="{cy+62}" width="{x1-x0}" height="7" rx="3.5" '
          f'fill="{GRIS_CLARO}"/>')
    l.add(f'<rect x="{x0}" y="{cy+62}" width="{(x1-x0)*0.72:.0f}" height="7" '
          f'rx="3.5" fill="url(#energia)"/>')

    for i, (nombre, sub, nivel, color) in enumerate(etapas):
        ex = MARGEN + i * (ancho_et + hueco_et)
        l.caja(ex, cy, ancho_et, 56, BLANCO, color, radio=12,
               etiqueta=f"etapa-{nombre}")
        l.texto(ex + ancho_et / 2, cy + 26, nombre, tam=15.5, peso="700",
                color=color, ancla="middle")
        l.texto(ex + ancho_et / 2, cy + 45, sub, tam=11.5, color=GRIS_SUAVE,
                ancla="middle")
        l.add(f'<circle cx="{ex+ancho_et/2:.0f}" cy="{cy+65.5}" r="9" '
              f'fill="{BLANCO}" stroke="{color}" stroke-width="3"/>')
        l.bateria(ex + ancho_et / 2 - 42, cy + 92, 52, 22, nivel, color)
        l.texto(ex + ancho_et / 2 + 22, cy + 108, f"{int(nivel*100)} %", tam=12.5,
                color=color, peso="700", ancla="middle")

    # Rama de rechazo, debajo de las etapas.
    ry = cy + 158
    l.camino(f"M {MARGEN+320} {cy+56} L {MARGEN+320} {ry+14} L {MARGEN+200} {ry+14}",
             color=ROJO)
    l.caja(MARGEN, ry - 16, 190, 60, ROJO_CLARO, ROJO, radio=12, etiqueta="rechazada")
    l.texto(MARGEN + 95, ry + 10, "Rechazada", tam=15, peso="700", color=ROJO,
            ancla="middle")
    l.texto(MARGEN + 95, ry + 30, "con su motivo", tam=11.5, color=GRIS,
            ancla="middle")

    # Aviso a lo ancho completo, debajo de todo: así no choca con las etapas.
    ay = cy + 232
    l.caja(MARGEN, ay, ANCHO - MARGEN * 2, 104, AMBAR_CLARO, AMBAR,
           etiqueta="nota-etapas")
    l.texto(MARGEN + 24, ay + 30, "LO QUE FALTA HOY", tam=13, peso="700",
            color="#8D6E00")
    l.texto(MARGEN + 24, ay + 56,
            "La app conoce estas 7 etapas por dentro, pero el usuario solo ve la actual: no hay ninguna vista",
            tam=13.5)
    l.texto(MARGEN + 24, ay + 78,
            "que muestre el proceso entero, ni al principio ni después. El onboarding sería además el primer sitio",
            tam=13.5)
    l.texto(MARGEN + 24, ay + 98, "donde se explican juntas.", tam=13.5)

    y = ay + 148

    # ============================================================
    # 5. ESTADOS
    # ============================================================
    y = seccion(l, y, 5, "Los tres estados de cada pantalla",
                "Hoy los estados vacíos son un icono gris y un texto: no dicen qué hacer")
    cy = y

    estados = [
        ("Vacío", GRIS_SUAVE, GRIS_CLARO,
         ["Icono gris y un texto fijo", "No lleva a ninguna acción",
          "Aparece en 5 sitios de la app"],
         "Pasa a: ondas de carga y un botón que lo resuelve"),
        ("Con datos", VERDE, VERDE_CLARO,
         ["Es lo normal", "Listas paginadas de 100 en 100",
          "Al cargar, una rueda centrada"],
         "Pasa a: baterías que se llenan y esqueletos en su sitio"),
        ("Error", ROJO, ROJO_CLARO,
         ["Un mensaje y, a veces, reintentar", "A veces solo un texto seco",
          "Sin salida clara"],
         "Pasa a: mensaje claro y una acción de salida siempre"),
    ]

    ancho_es = 492
    hueco_es = 34
    for i, (nombre, color, relleno, rasgos, cambio) in enumerate(estados):
        ex = MARGEN + i * (ancho_es + hueco_es)
        l.caja(ex, cy, ancho_es, 196, BLANCO, color, radio=16, grosor=2,
               etiqueta=f"estado-{nombre}")
        l.texto(ex + 20, cy + 34, nombre, tam=17, peso="700", color=color)
        for j, r in enumerate(rasgos):
            l.texto(ex + 20, cy + 70 + j * 24, f"•  {r}", tam=13.5, color=GRIS)
        l.linea(ex + 16, cy + 148, ex + ancho_es - 16, cy + 148, BORDE, 1)
        l.texto(ex + 20, cy + 176, cambio, tam=12.5, peso="600", color=color)

    y = cy + 244

    # ============================================================
    # Pie: regla transversal
    # ============================================================
    l.caja(MARGEN, y, ANCHO - MARGEN * 2, 96, VERDE_CLARO, VERDE_BORDE, radio=16,
           etiqueta="regla")
    l.texto(MARGEN + 24, y + 32, "REGLA TRANSVERSAL", tam=13, peso="700", color=VERDE)
    l.texto(MARGEN + 24, y + 58,
            "Si el teléfono tiene activado «reducir animaciones» en Accesibilidad, la app las desactiva y todo aparece",
            tam=14)
    l.texto(MARGEN + 24, y + 78,
            "directamente en su valor final. Es un requisito, no un extra: quien lo activa tiene una razón.",
            tam=14)

    l.alto = y + 130
    l.texto(ANCHO / 2, l.alto - 40,
            "CeldaPro · plan de experiencia de usuario · Roxy para Steve Moya",
            tam=12.5, color=GRIS_SUAVE, ancla="middle")

    # ---------- verificar antes de escribir nada ----------
    problemas = l.verificar()
    if problemas:
        print(f"❌ El diagrama tiene {len(problemas)} problema(s):\n")
        for p in problemas:
            print(f"   · {p}")
        return 1

    print("✅ Verificación geométrica: sin problemas "
          "(nada fuera del lienzo, sin solapes, ningún texto desbordado)")

    destino = pathlib.Path(__file__).resolve().parent
    svg_path = destino / "diagrama-ux.svg"
    svg_path.write_text(l.svg(), encoding="utf-8")

    png_path = destino / "diagrama-ux.png"
    subprocess.run(
        ["rsvg-convert", "-w", "2400", "-o", str(png_path), str(svg_path)],
        check=True,
    )
    print(f"SVG: {svg_path} ({svg_path.stat().st_size} bytes)")
    print(f"PNG: {png_path} ({png_path.stat().st_size} bytes)")
    print(f"Lienzo: {ANCHO} × {l.alto}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
