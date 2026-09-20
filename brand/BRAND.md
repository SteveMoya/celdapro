# CeldaPro — Brand Guidelines

> Guía de marca en texto. La versión visual (lámina imprimible) está en
> `brand/out/CeldaPro-Brand-Board.pdf`.

## 1. Qué es la marca

**CeldaPro** es la herramienta del taller para gestionar la restauración de celdas
de litio. La marca debe transmitir tres cosas, en este orden:

1. **Técnica** — hablamos de miliamperios, voltios y ohmios. Precisión ante todo.
2. **Confiable** — el taller guarda aquí su historial; nada de adornos frágiles.
3. **Sostenible** — recuperar una celda es evitar fabricar una nueva.

**Posicionamiento:** "el cuaderno del taller, pero que calcula".
**Tono:** directo, claro, en segunda persona y sin jerga innecesaria. En español.

## 2. El símbolo

Una **celda cilíndrica (18650)** con un **rayo ámbar** dentro —la energía que se
recupera— rodeada por un **anillo verde abierto** con punta de flecha: el ciclo de
restauración que avanza.

| Variante | Archivo | Cuándo |
|---|---|---|
| Completo | `source/logo-mark.svg` | Uso principal, **desde 48 px** |
| Compacto | `source/logo-mark-compact.svg` | **24–48 px**: listas, barras |
| Micro | `source/logo-mark-micro.svg` | **16–24 px**: favicon, notificación |
| Monocromo | `source/logo-mark-mono.svg` | Una sola tinta, grabados, sellos |

**Aire mínimo:** alrededor del símbolo, el ancho del terminal de la celda
(≈ 12 % del símbolo) libre de cualquier otro elemento.

**Nunca:** deformar, inclinar, cambiar los colores, añadir sombras o contornos,
ni usar el símbolo completo por debajo de 48 px.

## 3. Composiciones (lockups)

- **Horizontal** (`logo-horizontal.svg`): forma principal. Símbolo a la izquierda,
  nombre a la derecha.
- **Horizontal oscuro** (`logo-horizontal-oscuro.svg`): sobre fondos oscuros.
- **Vertical** (`logo-vertical.svg`): portadas, sellos, pie de página.

La palabra se escribe **CeldaPro** — una sola palabra, mayúscula inicial en
*Celda*, *Pro* con mayúscula. *Celda* en tinta, *Pro* en verde. Nunca partida en
dos líneas ni con espacio ("Celda Pro" ✗).

## 4. Color

El **verde manda**: cualquier pantalla debe leerse verde antes que ámbar. El ámbar
es acento y aviso, nunca fondo extenso.

| Nombre | HEX | Uso |
|---|---|---|
| Verde litio | `#2E7D32` | Primario: marca, acciones, veredicto A |
| Verde profundo | `#1B5E20` | Fondos oscuros, icono adaptativo |
| Verde claro | `#43A047` | Degradados |
| Ámbar energía | `#FFB300` | Rayo, avisos, veredicto C |
| Azul veredicto B | `#1565C0` | Clasificación B |
| Rojo rechazo | `#C62828` | Rechazo, errores |
| Tinta | `#0F1F14` | Texto principal |
| Gris texto | `#5F6B63` | Texto secundario |
| Fondo | `#F6F8F6` | Superficie clara |
| Borde | `#DCE3DD` | Bordes y separadores |

**Semáforo de veredictos** (no cambiar: son el lenguaje visual de la app):
A `#2E7D32` · B `#1565C0` · C `#F9A825` · Rechazo `#C62828`.

## 5. Tipografía

**Inter** (licencia libre), pesos 400, 500, 600 y 700.

| Rol | Tamaño / alto | Peso |
|---|---|---|
| Display | 72 / 76 | 700 |
| Título 1 | 34 / 40 | 700 |
| Título 2 | 24 / 30 | 600 |
| Cuerpo | 16 / 24 | 400 |
| Cuerpo pequeño | 14 / 20 | 400 |
| Etiqueta | 12 / 16 | 600 |

**Cifras y unidades** (importante por el tipo de datos que maneja la app):

- Separador de miles con espacio: `2 380 mAh`
- Unidad separada por espacio: `3.6 V · 13 mΩ · 25 A`
- Decimales con punto, no con coma: `3.6 V`
- Porcentaje con espacio fino: `95 %`

## 6. Icono de app

El símbolo sobre el verde de marca. En Android se usan capas **adaptativas**
(fondo verde sólido + marca en la zona segura del 66 % + capa monocroma para
Material You), así el sistema puede recortarlo en cualquier forma sin cortar la
marca. Los recursos ya están en `android/app/src/main/res/mipmap-*`.

## 7. Aplicación

- **En la app:** símbolo compacto en la barra superior (20 px), completo en
  pantallas de bienvenida y ajustes.
- **En etiquetas impresas:** símbolo compacto + código en texto **siempre**. Si el
  código de barras se moja o se raya, la celda debe seguir siendo identificable a
  ojo.
- **En informes PDF:** lockup horizontal en la cabecera, tamaño discreto.

## 8. Archivos y regeneración

```bash
# Regenera todos los PNG, lockups e iconos de Android desde los SVG fuente
python3 brand/build_brand.py

# Comprueba geometría, color y legibilidad del símbolo
python3 brand/verificar_logo.py
python3 brand/verificar_assets.py

# Exporta la lámina de marca a PDF y PNG
python3 brand/build_board.py && node brand/export_pdf.js
```

Los **SVG son la fuente de verdad**; los PNG son copias generadas. Para cualquier
cambio de marca, se edita el SVG y se vuelve a ejecutar el script.
