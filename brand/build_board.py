#!/usr/bin/env python3
"""Genera el brand board de CeldaPro (HTML autocontenido) y lo exporta a PDF
y PNG con Chromium (Playwright)."""
import subprocess
import sys
from pathlib import Path

ROOT = Path('/root/proyectos/celdapro/brand')
SRC = ROOT / 'source'
OUT = ROOT / 'out'


def svg(nombre, clase=''):
    t = (SRC / f'{nombre}.svg').read_text()
    t = t.replace('<svg ', f'<svg class="{clase}" ', 1)
    return t


VERDE = '#2E7D32'
VERDE_OSC = '#1B5E20'
VERDE_CLARO = '#43A047'
AMBAR = '#FFB300'
TINTA = '#0F1F14'
GRIS = '#5F6B63'
BORDE = '#DCE3DD'
FONDO = '#F6F8F6'

PALETA = [
    ('Verde litio', VERDE, 'Primario. Marca, acciones principales, veredicto A.',
     '46 · 125 · 50', 'Energía recuperada'),
    ('Verde profundo', VERDE_OSC, 'Fondos oscuros, icono adaptativo, titulares.',
     '27 · 94 · 32', 'Profundidad'),
    ('Verde claro', VERDE_CLARO, 'Degradados y estados hover.',
     '67 · 160 · 71', 'Apoyo del primario'),
    ('Ámbar energía', AMBAR, 'Acento. Rayo del símbolo, avisos, veredicto C.',
     '255 · 179 · 0', 'Atención'),
    ('Azul veredicto B', '#1565C0', 'Clasificación B (celda aprovechable).',
     '21 · 101 · 192', 'Dato'),
    ('Rojo rechazo', '#C62828', 'Rechazo, errores, celdas agotadas.',
     '198 · 40 · 40', 'Peligro'),
    ('Tinta', TINTA, 'Texto principal sobre fondo claro.',
     '15 · 31 · 20', 'Lectura'),
    ('Gris texto', GRIS, 'Texto secundario, descripciones, pie de foto.',
     '95 · 107 · 99', 'Lectura'),
    ('Fondo', FONDO, 'Fondo de la app en tema claro.',
     '246 · 248 · 246', 'Superficie'),
    ('Borde', BORDE, 'Bordes de tarjetas y campos.',
     '220 · 227 · 221', 'Estructura'),
]

TIPOS = [
    ('Display', '72 / 76', '700', 'CeldaPro'),
    ('Título 1', '34 / 40', '700', 'Inventario de celdas'),
    ('Título 2', '24 / 30', '600', 'Samsung 25R (18650)'),
    ('Cuerpo', '16 / 24', '400', 'Capacidad medida 2 380 mAh · SoH 95 %'),
    ('Cuerpo pequeño', '14 / 20', '400', 'Test del 18 de septiembre'),
    ('Etiqueta', '12 / 16', '600', 'CLASIFICADA · LOTE L-2026-09-A'),
]


def fila_color(nombre, hexv, uso, rgb, rol):
    return f'''
    <div class="swatch">
      <div class="chip" style="background:{hexv}"></div>
      <div class="swatch-info">
        <strong>{nombre}</strong>
        <code>{hexv}</code>
        <span class="meta">RGB {rgb} · {rol}</span>
        <p>{uso}</p>
      </div>
    </div>'''


def fila_tipo(nombre, tam, peso, muestra):
    return f'''
    <div class="tipo">
      <div class="tipo-meta"><strong>{nombre}</strong><br>{tam} · peso {peso}</div>
      <div class="tipo-muestra" style="font-size:{tam.split(' / ')[0]}px;
           font-weight:{peso}; line-height:1.1">{muestra}</div>
    </div>'''


html = f'''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<title>CeldaPro — Brand Board</title>
<style>
  @page {{ size: A4; margin: 0; }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0; font-family: Inter, 'DejaVu Sans', sans-serif;
    color: {TINTA}; background: #fff; -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }}
  .pagina {{
    width: 210mm; height: 296mm; padding: 14mm 15mm 10mm;
    position: relative; page-break-after: always; overflow: hidden;
    background: #fff;
  }}
  .pagina:last-child {{ page-break-after: auto; }}
  .pnum {{
    position: absolute; bottom: 7mm; left: 15mm; right: 15mm;
    display: flex; justify-content: space-between;
    font-size: 9px; color: {GRIS}; letter-spacing: .08em;
    border-top: 1px solid {BORDE}; padding-top: 3mm;
  }}
  h1 {{ font-size: 30px; margin: 0 0 6px; letter-spacing: -.02em; }}
  h2 {{
    font-size: 13px; text-transform: uppercase; letter-spacing: .16em;
    color: {VERDE}; margin: 0 0 12px; padding-bottom: 6px;
    border-bottom: 2px solid {VERDE};
  }}
  h3 {{ font-size: 15px; margin: 22px 0 8px; }}
  p {{ margin: 0 0 8px; font-size: 12.5px; line-height: 1.55; }}
  .suave {{ color: {GRIS}; }}
  .cols {{ display: flex; gap: 14px; }}
  .cols > * {{ flex: 1; min-width: 0; }}
  .caja {{
    border: 1px solid {BORDE}; border-radius: 12px; padding: 14px;
    background: #fff;
  }}
  .caja.fondo {{ background: {FONDO}; }}
  .caja.verde {{ background: {VERDE}; border-color: {VERDE}; }}
  .caja.verde .rotulo {{ color: #fff; }}
  .caja.oscura {{ background: {VERDE_OSC}; border-color: {VERDE_OSC}; }}
  .rotulo {{
    font-size: 9.5px; text-transform: uppercase; letter-spacing: .12em;
    color: {GRIS}; margin-bottom: 10px;
  }}
  .marca-grande {{ display: block; width: 150px; margin: 0 auto; }}
  .portada {{ display: flex; flex-direction: column; justify-content: center;
             align-items: center; text-align: center; min-height: 250mm; }}
  .portada .lock {{ width: 300px; }}
  .portada h1 {{ font-size: 40px; margin-top: 26px; }}
  .tagline {{ font-size: 13px; letter-spacing: .2em; color: {GRIS};
             text-transform: uppercase; margin-top: 6px; }}
  .sello {{
    margin-top: 30px; font-size: 11px; color: {GRIS};
    border: 1px solid {BORDE}; border-radius: 999px; padding: 7px 16px;
  }}
  .swatch {{ display: flex; gap: 12px; align-items: flex-start;
            padding: 9px 0; border-bottom: 1px solid {BORDE}; }}
  .swatch:last-child {{ border-bottom: none; }}
  .chip {{ width: 52px; height: 52px; border-radius: 10px; flex: none;
          border: 1px solid rgba(0,0,0,.08); }}
  .swatch-info strong {{ font-size: 13px; display: block; }}
  .swatch-info code {{ font-size: 12px; color: {VERDE};
                      font-weight: 700; letter-spacing: .04em; }}
  .swatch-info .meta {{ font-size: 10px; color: {GRIS}; display: block;
                       margin: 1px 0 3px; }}
  .swatch-info p {{ font-size: 11px; margin: 0; color: {GRIS}; }}
  .tipo {{ display: flex; gap: 14px; align-items: baseline;
          padding: 10px 0; border-bottom: 1px solid {BORDE}; }}
  .tipo:last-child {{ border-bottom: none; }}
  .tipo-meta {{ width: 150px; flex: none; font-size: 10px; color: {GRIS};
               line-height: 1.4; }}
  .tipo-meta strong {{ color: {TINTA}; font-size: 11.5px; }}
  .tipo-muestra {{ flex: 1; min-width: 0; }}
  .iconos {{ display: flex; gap: 18px; align-items: flex-end; flex-wrap: wrap; }}
  .icono-item {{ text-align: center; }}
  .icono-item img {{ display: block; border-radius: 22%; }}
  .icono-item span {{ font-size: 9px; color: {GRIS}; display: block;
                     margin-top: 5px; }}
  .celda-marca {{ display: flex; align-items: center; gap: 10px;
                 margin-bottom: 12px; }}
  .si-no {{ display: flex; gap: 14px; }}
  .si-no > div {{ flex: 1; }}
  .si-no ul {{ margin: 0; padding-left: 18px; font-size: 11.5px;
              line-height: 1.7; }}
  .si {{ color: {VERDE}; }}
  .no {{ color: #C62828; }}
  .muestra-app {{
    border: 1px solid {BORDE}; border-radius: 14px; overflow: hidden;
    background: {FONDO};
  }}
  .app-bar {{ background: {VERDE}; color: #fff; padding: 10px 14px;
             font-weight: 700; font-size: 14px;
             display: flex; align-items: center; gap: 8px; }}
  .app-bar img {{ width: 20px; }}
  .app-cuerpo {{ padding: 12px; }}
  .tarjeta {{ background: #fff; border: 1px solid {BORDE};
             border-radius: 10px; padding: 10px; margin-bottom: 8px; }}
  .fila {{ display: flex; justify-content: space-between; font-size: 11px; }}
  .pildora {{ font-size: 9px; font-weight: 700; color: #fff;
             border-radius: 999px; padding: 2px 8px; }}
  .etiqueta-muestra {{
    border: 1.5px dashed {GRIS}; border-radius: 8px; padding: 10px;
    display: flex; gap: 12px; align-items: center; background: #fff;
  }}
  .barras {{ flex: none; }}
  .etiqueta-txt {{ font-size: 10px; line-height: 1.5; }}
  .etiqueta-txt strong {{ font-size: 12px; }}
  .aviso {{
    background: #FFF8E1; border-left: 3px solid {AMBAR};
    padding: 9px 12px; border-radius: 0 8px 8px 0; font-size: 11.5px;
    margin-top: 10px;
  }}
  .pie-marca {{ display: flex; justify-content: space-between;
               align-items: center; margin-bottom: 18px; }}
  .pie-marca img {{ height: 26px; }}
  .pie-marca span {{ font-size: 9px; color: {GRIS};
                    letter-spacing: .1em; text-transform: uppercase; }}
</style>
</head>
<body>

<!-- 1. PORTADA -->
<div class="pagina">
  <div class="portada">
    {svg('logo-vertical', 'lock')}
    <h1>Manual de marca</h1>
    <div class="tagline">Gestión de restauración de celdas de litio</div>
    <div class="sello">Versión 1.0 · Septiembre 2026 · Uso interno y del taller</div>
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>01</span></div>
</div>

<!-- 2. EL SÍMBOLO -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>El símbolo</span>
  </div>
  <h2>El símbolo</h2>
  <p>Una <strong>celda cilíndrica</strong> (18650) con un <strong>rayo ámbar</strong>
  en su interior —la energía que se recupera— rodeada por un <strong>anillo verde
  abierto</strong> con punta de flecha: el ciclo de restauración que avanza. El
  verde es la marca y el trabajo; el ámbar, la energía recuperada.</p>

  <div class="cols" style="margin-top:18px">
    <div class="caja fondo" style="text-align:center">
      <div class="rotulo">Completo · desde 48 px</div>
      {svg('logo-mark', 'marca-grande')}
      <p class="suave" style="font-size:10.5px">Uso principal: app, web, documentos.</p>
    </div>
    <div class="caja fondo" style="text-align:center">
      <div class="rotulo">Compacto · desde 24 px</div>
      {svg('logo-mark-compact', 'marca-grande')}
      <p class="suave" style="font-size:10.5px">Sin anillo, para tamaños pequeños.</p>
    </div>
    <div class="caja fondo" style="text-align:center">
      <div class="rotulo">Micro · 16 px</div>
      {svg('logo-mark-micro', 'marca-grande')}
      <p class="suave" style="font-size:10.5px">Favicon y notificaciones.</p>
    </div>
  </div>

  <h3>Tamaño mínimo y aire de respeto</h3>
  <p>Nunca por debajo de los tamaños indicados. Alrededor del símbolo debe quedar
  libre, como mínimo, el ancho del terminal de la celda (≈ 12 % del símbolo).</p>
  <div class="cols">
    <div class="caja">
      <div class="rotulo">Aire mínimo</div>
      <div style="display:flex;justify-content:center;padding:6px">
        <div style="border:1px dashed {GRIS};padding:14px;border-radius:8px">
          <div style="border:1px dashed {VERDE_CLARO};padding:12px;border-radius:6px">
            {svg('logo-mark', '')}
          </div>
        </div>
      </div>
      <p class="suave" style="font-size:10.5px;margin-top:6px">
      El recuadro verde marca la separación mínima respecto a otros elementos.</p>
    </div>
    <div class="caja">
      <div class="rotulo">Tamaños de referencia</div>
      <div class="iconos">
        <div class="icono-item">{svg('logo-mark', '')}
          <span>48 px</span></div>
      </div>
      <p class="suave" style="font-size:10.5px">En la app: 48 px en listas y
      cabeceras; 24 px en barras densas.</p>
    </div>
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>02</span></div>
</div>

<!-- 3. LOCKUPS -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>Composiciones</span>
  </div>
  <h2>Composiciones</h2>
  <p>La forma principal es el <strong>lockup horizontal</strong>: símbolo a la
  izquierda y nombre a la derecha. La palabra <em>Celda</em> va en tinta y
  <em>Pro</em> en verde: siempre junto, nunca partido en dos líneas.</p>

  <div class="caja fondo" style="margin-top:16px">
    <div class="rotulo">Horizontal · uso principal</div>
    {svg('logo-horizontal', '')}
  </div>

  <div class="caja oscura" style="margin-top:12px">
    <div class="rotulo" style="color:#A5D6A7">Horizontal · sobre fondo oscuro</div>
    {svg('logo-horizontal-oscuro', '')}
  </div>

  <div class="caja fondo" style="margin-top:12px;text-align:center">
    <div class="rotulo">Vertical · sellos y portadas</div>
    <div style="display:flex;justify-content:center">
      {svg('logo-vertical', '')}
    </div>
  </div>

  <div class="aviso">
    <strong>Sobre fondos oscuros</strong>, usa la versión clara: el verde profundo
    se pierde sobre verde o negro. Nunca pongas la versión de fondo claro encima
    de una fotografía sin una capa que garantice el contraste.
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>03</span></div>
</div>

<!-- 4. ICONO DE APP -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>Icono de app</span>
  </div>
  <h2>Icono de app</h2>
  <p>El icono aplica el símbolo sobre el verde de marca. En Android se usan las
  capas <strong>adaptativas</strong>: el sistema recorta la forma (círculo,
  cuadrado redondeado, gota…) y la marca vive dentro de la zona segura central,
  por lo que nunca queda cortada.</p>

  <div class="caja fondo" style="margin-top:14px">
    <div class="rotulo">Tamaños reales de lanzador</div>
    <div class="iconos">
      <div class="icono-item">
        <img src="icono-app.png" width="144" height="144">
        <span>144 px</span></div>
      <div class="icono-item">
        <img src="icono-app.png" width="96" height="96">
        <span>96 px</span></div>
      <div class="icono-item">
        <img src="icono-app.png" width="72" height="72">
        <span>72 px</span></div>
      <div class="icono-item">
        <img src="icono-app.png" width="48" height="48">
        <span>48 px</span></div>
      <div class="icono-item">
        <img src="icono-app-redondo.png" width="96" height="96">
        <span>redondo</span></div>
    </div>
  </div>

  <div class="cols" style="margin-top:12px">
    <div class="caja">
      <div class="rotulo">Capa de fondo</div>
      <img src="icono-adaptativo-fondo.png" width="120" height="120"
           style="border-radius:10px">
      <p class="suave" style="font-size:10.5px">Verde de marca sólido (#2E7D32).</p>
    </div>
    <div class="caja">
      <div class="rotulo">Capa de frente y zona segura</div>
      <div style="position:relative;width:120px;height:120px">
        <img src="icono-adaptativo-frente.png" width="120" height="120">
        <div style="position:absolute;inset:0;border:1px dashed {VERDE};
             border-radius:50%"></div>
      </div>
      <p class="suave" style="font-size:10.5px">La marca cabe en el círculo
      seguro del 66 %.</p>
    </div>
    <div class="caja">
      <div class="rotulo">Monocromo (Material You)</div>
      <img src="../brand/out/../out/icono-notificacion.png" width="64" height="64"
           style="background:#eee;border-radius:8px;padding:6px">
      <p class="suave" style="font-size:10.5px">Android 13+ lo tiñe con la
      paleta del usuario.</p>
    </div>
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>04</span></div>
</div>

<!-- 5. COLOR -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>Color</span>
  </div>
  <h2>Paleta</h2>
  <p>El verde de marca manda: cualquier pantalla debe leerse verde antes que
  ámbar. El ámbar es acento y aviso, nunca color de fondo grande.</p>
  <div style="margin-top:12px">{''.join(fila_color(*c) for c in PALETA)}</div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>05</span></div>
</div>

<!-- 6. TIPOGRAFÍA -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>Tipografía</span>
  </div>
  <h2>Tipografía</h2>
  <p><strong>Inter</strong> en toda la app: excelente en pantalla, cifras claras
  (importante para mAh, voltios y ohmios) y licencia libre. Pesos: 400, 500, 600
  y 700. Nunca en cursiva para datos técnicos.</p>
  <div style="margin-top:12px">{''.join(fila_tipo(*t) for t in TIPOS)}</div>

  <h3>Cifras y unidades</h3>
  <div class="caja fondo">
    <p style="font-size:13px;margin:0">
      Separador de miles con espacio fino: <strong>2 380 mAh</strong><br>
      Unidad separada por espacio: <strong>3.6 V · 13 mΩ · 25 A</strong><br>
      Porcentaje pegado a la cifra: <strong>95 %</strong> (con espacio fino, para
      que la cifra respire)<br>
      Decimales con punto, no con coma: <strong>3.6 V</strong>
    </p>
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>06</span></div>
</div>

<!-- 7. USO CORRECTO -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>Uso de la marca</span>
  </div>
  <h2>Uso de la marca</h2>
  <div class="si-no">
    <div class="caja">
      <div class="rotulo si">Correcto</div>
      <ul>
        <li>Usar los archivos originales (SVG o PNG).</li>
        <li>Mantener la proporción al escalar.</li>
        <li>Verde de marca sobre blanco o gris claro.</li>
        <li>Versión clara sobre fondos oscuros.</li>
        <li>Respetar el aire mínimo alrededor.</li>
        <li>Usar el símbolo compacto en tamaños pequeños.</li>
      </ul>
    </div>
    <div class="caja">
      <div class="rotulo no">Incorrecto</div>
      <ul>
        <li>Deformar, estirar o inclinar el símbolo.</li>
        <li>Cambiar los colores de marca.</li>
        <li>Separar <em>Celda</em> y <em>Pro</em> o cambiar la tipografía.</li>
        <li>Poner sombras, contornos o degradados añadidos.</li>
        <li>Usar el símbolo completo por debajo de 48 px.</li>
        <li>Colocarlo sobre una foto sin garantizar contraste.</li>
      </ul>
    </div>
  </div>

  <h3>Cómo se ve en la aplicación</h3>
  <div class="cols">
    <div class="muestra-app">
      <div class="app-bar">
        <img src="logo-mark-compact.png" alt=""> CeldaPro
      </div>
      <div class="app-cuerpo">
        <div class="tarjeta">
          <div class="fila">
            <strong>C-0001 · Samsung 25R</strong>
            <span class="pildora" style="background:{VERDE}">A</span>
          </div>
          <div class="fila suave" style="margin-top:4px">
            <span>2 380 mAh · 3.6 V</span><span>SoH 95.2 %</span>
          </div>
        </div>
        <div class="tarjeta">
          <div class="fila">
            <strong>C-0002 · LG HG2</strong>
            <span class="pildora" style="background:#1565C0">B</span>
          </div>
          <div class="fila suave" style="margin-top:4px">
            <span>2 100 mAh · 3.6 V</span><span>SoH 84.0 %</span>
          </div>
        </div>
        <div class="tarjeta">
          <div class="fila">
            <strong>C-0003 · Molicel P26A</strong>
            <span class="pildora" style="background:#C62828">Rechazo</span>
          </div>
          <div class="fila suave" style="margin-top:4px">
            <span>1 050 mAh · 3.6 V</span><span>SoH 42.0 %</span>
          </div>
        </div>
      </div>
    </div>
    <div>
      <div class="caja fondo">
        <div class="rotulo">Etiqueta de celda (impresa)</div>
        <div class="etiqueta-muestra">
          <img src="logo-mark-compact.png" width="34" height="34">
          <div class="etiqueta-txt">
            <strong>C-0001</strong><br>
            Samsung 25R · 18650<br>
            2 500 mAh · 3.6 V<br>
            Lote L-2026-09-A
          </div>
        </div>
        <p class="suave" style="font-size:10px;margin-top:8px">
        La etiqueta lleva el código en texto (para leerlo a mano) y el código de
        barras / QR (para escanearlo con la app).</p>
      </div>
      <div class="aviso">
        <strong>Nunca</strong> imprimas la etiqueta sin el código en texto: si el
        código de barras se moja, se raya o se despega, la celda debe seguir siendo
        identificable a ojo.
      </div>
    </div>
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>07</span></div>
</div>

<!-- 8. ARCHIVOS -->
<div class="pagina">
  <div class="pie-marca">
    {svg('logo-horizontal')}
    <span>Archivos</span>
  </div>
  <h2>Archivos entregados</h2>
  <p>Todo está en <code>brand/</code> dentro del repositorio. Los SVG son la
  fuente de verdad (escalan sin perder calidad); los PNG son copias listas para
  usar.</p>
  <div class="caja fondo" style="margin-top:12px">
    <p style="font-size:11.5px;line-height:2;margin:0">
      <code>brand/source/logo-mark.svg</code> — símbolo principal<br>
      <code>brand/source/logo-mark-compact.svg</code> — símbolo compacto<br>
      <code>brand/source/logo-mark-micro.svg</code> — símbolo micro<br>
      <code>brand/source/logo-mark-mono.svg</code> — una sola tinta<br>
      <code>brand/source/logo-horizontal.svg</code> — lockup horizontal<br>
      <code>brand/source/logo-horizontal-oscuro.svg</code> — lockup oscuro<br>
      <code>brand/source/logo-vertical.svg</code> — lockup vertical<br>
      <code>brand/source/icono-app.svg</code> — icono cuadrado<br>
      <code>brand/source/icono-app-redondo.svg</code> — icono redondo<br>
      <code>brand/source/icono-adaptativo-*.svg</code> — capas Android<br>
      <code>brand/build_brand.py</code> — regenera todo<br>
      <code>brand/verificar_logo.py</code> — comprueba la geometría
    </p>
  </div>
  <div class="aviso">
    <strong>Para regenerar todo</strong> tras cambiar un SVG fuente:
    <code>python3 brand/build_brand.py</code>. El script ajusta los lockups,
    exporta los PNG y actualiza los iconos de Android en un paso.
  </div>
  <div class="pnum"><span>CeldaPro — Manual de marca</span><span>08</span></div>
</div>

</body>
</html>
'''

(ROOT / 'brand-board.html').write_text(html)
print(f'HTML escrito: brand-board.html ({len(html)} bytes)')
