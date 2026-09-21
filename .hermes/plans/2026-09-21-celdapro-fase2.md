# Plan — CeldaPro Fase 2 (sin BMS por Bluetooth)

> **Fecha:** 2026-09-21
> **Autor:** Roxy (asistente)
> **Estado:** ✅ **Steve dio luz verde a seguir ("continua con el desarrollo"). F0 ejecutado en v0.9.0; F1–F4 pendientes**
> **Punto de partida:** v0.8.0 (M1–M6 cerrados, APK firmado con la clave real)
> **Plan base:** `2026-09-18-celdapro-mejoras.md` (§2, puntos 13/14/16)
> **Excluido por decisión de Steve:** BMS por Bluetooth (punto 15)

---

## 0. Qué entra y qué no

Entra: **etiqueta de una línea con lectura por OCR** (petición de Steve durante la ejecución),
**agrupación/balanceo**, **armado de packs** y **análisis de degradación**.
No entra: **BMS por Bluetooth** (a petición de Steve) ni packs con conexión a hardware.

### 🏷️ F0 — Etiqueta de una línea + lectura por OCR ✅ Hecho en v0.9.0

**Lo que pidió Steve:** «agrega otra forma para que quede en una línea, esto puede hacer referencia
al código de una celda, para colocarlo en cada celda que se esté restaurando; cuando se escanee este
código el móvil debe usar OCR para leer los dígitos de los textos y buscarlo en la aplicación».

- ✅ **Formato `unaLinea`** (50 × 12 mm, 60 por hoja A4): tira con el código en texto grande y el
  código de barras al lado.
- ✅ **Pantalla de lectura por OCR**: foto → reconocimiento de texto → búsqueda en la base.
- ✅ **Lógica de interpretación** (`lib/core/ocr_code.dart`): corrige las confusiones típicas del OCR
  (`O`↔`0`, `I`↔`1`, `S`↔`5`, `B`↔`8`, `Z`↔`2`), tolera que se pierda el guion, y ordena los
  candidatos para que la lectura corregida gane a la cruda.
- ✅ **Nunca deja al operador sin salida**: si no acierta, enseña lo que leyó, propone los códigos
  más parecidos del inventario y permite escribirlo a mano.
- ✅ **El OCR va 100 % en el teléfono**: verificado que el modelo (`Latn_ctc`, ~11 MB) y la librería
  nativa viajan **dentro del APK**, así que no hace falta conexión ni se envían fotos a ningún sitio.
- ✅ **Verificado con OCR real**: la etiqueta se renderizó a 300 ppp y se pasó por un OCR
  (tesseract): lee `c-0001` y `SAMSUNG-A12`. El texto que devolvió ese OCR real quedó como caso de
  prueba en `test/ocr_code_test.dart`.

**🐛 Dos fallos reales encontrados al hacerlo, ya corregidos:**

1. **El código de barras impreso no coincidía con la vista previa de la app.** El pintor del PDF
   dibujaba los elementos en coordenadas de 0–100 **sin escalarlas** a su caja: el código salía a
   100 pt (~36 mm) de ancho, ignorando el tamaño pedido y cortándose por el borde. El de pantalla
   (`CodePainter`) sí escalaba. Afectaba a **todas** las etiquetas ya publicadas (M2). Ahora ambos
   usan el mismo criterio.
2. **El escáner no encontraba celdas fuera de la primera página.** Buscaba el código en la lista
   cargada en memoria, que desde la paginación de M5 es solo una tanda (y encima filtrada): una
   celda existente y fuera de esa tanda se daba por inexistente y ofrecía **crear un duplicado**.
   Ahora escáner y OCR buscan en la base (`CeldaRepository.byCodigo`).

---

## 1. Hallazgo que cambia el plan anterior

El plan de mejoras decía que `pack-builder.ts` son «1 544 líneas reutilizables». **No es así, y lo
comprobé antes de prometerlo:**

| Archivo | Líneas | Referencias a 3D/DOM | ¿Portable a Flutter? |
|---|---|---|---|
| `pack-builder.ts` | 1 544 | **204** (158 con Three.js) | ❌ Es un **visor 3D de navegador**. Ni una función sirve tal cual. |
| `degradation-engine.ts` | 285 | 0 | ✅ Lógica pura, portable directa. |
| `balancing-engine.ts` | 157 | 0 | ✅ Lógica pura, portable directa. |
| `parallel-engine.ts` | 168 | 0 | ✅ Lógica pura, portable directa. |

**Consecuencia honesta:** de `pack-builder.ts` solo se aprovecha **la aritmética** (tensión, capacidad,
energía, peso, coste, corriente máxima), que son ~30 líneas. Lo demás hay que escribirlo. El plan
original subestimaba el trabajo de packs; este lo corrige.

**Lo bueno:** las tres que sí son lógica pura son justo las partes con **física real** detrás
(Arrhenius, reparto de corriente, balanceo), y ya traen los parámetros calibrados por química.

---

## 2. Lo que ya existe y encaja sin forzar

Comprobado en el código, no supuesto:

- **`CellState` ya tiene `balanced` y `repacked`** («Balanceada», «Reempacada: Montada en un pack»).
  El flujo de packs ya estaba previsto en el modelo desde el MVP.
- **`CellTest` guarda `capacidadMedidaMah`, `resistenciaInternaMohm` y `voltajeV`.** Es decir: los
  datos reales que hacen falta para agrupar celdas **ya se están midiendo y guardando**.
- **`Thresholds`** ya es el patrón de «valores por defecto + personalizables» que Steve pidió.
- **La capa de datos y las migraciones ya están probadas** contra SQLite real (46 pruebas, M5), así
  que añadir tabla `packs` es seguro.

---

## 3. Los tres entregables

### 🧩 F1 — Agrupación y balanceo de celdas · v0.9.0

**Por qué:** un pack que mezcla una celda al 95 % con otra al 62 % se degrada por la peor. Es el
error más caro del taller y hoy se evita «a ojo».

- **Lógica pura** (`lib/core/agrupacion.dart`): puntuación de compatibilidad entre celdas y armado
  de grupos por similitud.
- **Criterios, con la medición real de cada celda** (no la nominal del catálogo):
  - química: **debe coincidir** exactamente (no negociable),
  - capacidad medida: dentro de tolerancia,
  - resistencia interna medida: dentro de tolerancia,
  - SoH: dentro de tolerancia,
  - voltaje actual: dentro de tolerancia.
- **Tolerancias configurables**, con valores por defecto de la app (mismo patrón que los umbrales
  de clasificación que ya aprobaste).
- **La pantalla dice por qué deja una celda fuera** («está 12 % por debajo del grupo»), en vez de
  solo descartarla. Sin eso el operador no confía en el resultado.
- Alcance: un lote, o el inventario filtrado.
- **Aceptación:** 20 celdas → grupos coherentes; una celda de 62 % SoH **nunca** cae en un grupo con
  celdas de 95 % salvo que se ensanche la tolerancia a mano; y una celda de química distinta no
  entra en ningún caso.

### 🔋 F2 — Armado de packs · v0.10.0

**Por qué:** es el producto final del taller. Ahora mismo la app termina en «celda clasificada».

- **Entidad `Pack`** (nueva tabla, BD **v5**): código, nombre, configuración **S×P**, química,
  celdas asignadas y en qué posición, notas, fecha, estado.
- **Tabla `pack_celdas`**: qué celda va en qué posición del pack. Es lo que permite desarmar y
  auditar después.
- **Especificaciones calculadas** (aritmética verificada, escrita limpia en Dart):
  tensión nominal y rango mín–máx, capacidad (Ah), energía (Wh/kWh), corriente máxima continua,
  potencia máxima (kW), peso (kg), coste.
- **Lista de materiales (BOM):** celdas, BMS, separadores, conectores, longitud estimada de nickel.
- **Validación:** que haya celdas suficientes, que el voltaje del pack esté dentro de lo que admite
  un BMS estándar de esa tensión, y **aviso si el pack mezcla grupos incompatibles** de F1.
- **Efecto en el flujo:** al cerrar un pack, sus celdas pasan a **`repacked`** con su evento
  auditado (el estado ya existe).
- **Informe PDF del pack** reutilizando `report_service.dart` (ya probado en M3).
- **Aceptación:** armar un 3S2P con 6 celdas → especificaciones correctas, las 6 celdas en
  `repacked`, PDF generado y BOM con la lista completa.

### 📉 F3 — Análisis de degradación · v0.11.0

**Por qué:** hoy el taller sabe cómo está una celda **hoy**, pero no cuánto le queda.

- **Port de `degradation-engine.ts`** a `lib/core/degradacion.dart` (lógica pura, testeable).
- **Modelo ya calibrado** (no inventado por mí): atrición Arrhenius por temperatura, exponente por
  C-rate y por profundidad de descarga. Referencias del propio motor:
  - LFP ≈ **2 000 ciclos** hasta 80 % a 25 °C / 1C / 80 % DoD,
  - NMC ≈ **500**, LTO ≈ **8 000**, NCA ≈ **400**.
- **Salida por pack y por celda:** ciclos hasta 80 % y 70 %, vida en años, coste por ciclo, curva de
  degradación, avisos («temperatura alta», «descarga profunda») y nivel (excelente → pobre).
- ⚠️ **Es una estimación, no una medición.** La UI lo dirá con esas palabras: sale de un modelo con
  condiciones que el taller declara, no de lo que la celda hará de verdad. Prometer precisión aquí
  sería mentir.
- **Aceptación:** con LFP en condiciones de referencia el resultado da ~2 000 ciclos (el valor
  calibrado del motor); con 45 °C el resultado empeora respecto a 25 °C.

### 🗂️ F4 — Filtros guardados · (viaja con F1)

Lo único que quedó pendiente de M5. Guardar combinaciones de filtros con nombre («Samsung 25R
pendientes»). Pequeño; lo meto con F1 en vez de hacer una versión por esto.

---

## 4. Cómo lo entrego

Una versión por entregable, con su release firmada y probada:

| Versión | Contenido |
|---|---|
| **v0.9.0** ✅ | F0: etiqueta de una línea + lectura por OCR |
| **v0.10.0** | F1 agrupación y balanceo + F4 filtros guardados |
| **v0.11.0** | F2 armado de packs |
| **v0.12.0** | F3 análisis de degradación |

En cada una: `flutter analyze` 0, suite verde, APK firmado con el keystore real, release publicada y
`TODO.md` actualizado. Si algo no sale, lo digo antes de seguir, no al final.

---

## 5. Opciones

### Opción A — Las tres, una por versión ⭐ *recomendada*

- **Ventajas:** cada entrega se puede probar en el teléfono antes de la siguiente. El orden es
  obligado (sin agrupar bien, armar packs es adivinar). Si algo del flujo no te encaja, se corrige
  antes de construir encima.
- **Desventajas:** tres tandas de trabajo, y la de degradación es la última en llegar.

### Opción B — Solo F1 + F2

- **Ventajas:** llegas antes a lo que se usa a diario (agrupar y armar packs); degradación es
  análisis, no producción.
- **Desventajas:** el pack queda sin su dato de vida útil, que es justo lo que se le enseña al
  cliente para justificar el precio.

### Opción C — Las tres de una vez

- **Ventajas:** una sola vuelta de pruebas; los packs nacen con degradación incluida.
- **Desventajas:** mucho tiempo sin nada que probar, y si el modelo de packs no encaja con cómo
  trabajas, el error se arrastra a las tres.

**Mi recomendación: A.** El orden F1→F2→F3 no es capricho: sin agrupación, el armado de packs sería
elegir celdas a ojo; y sin packs no hay nada que analizar en F3.

---

## 6. Riesgos y límites honestos

- **No tengo teléfono ni celdas reales.** Verifico con tests, análisis y compilación; la prueba en
  dispositivo es tuya. Ya pasó con MensajesPro.
- **Los packs no llevan esquema 3D.** Lo que había en `battery-tool` es un visor de navegador y no
  se puede reutilizar. Propongo **tabla de especificaciones + BOM** en esta fase.
- **La degradación es un modelo, no una medida.** Los números dependen de las condiciones que se
  declaren; la realidad depende del uso.
- **NiMH y «Otra» no tienen modelo de degradación** en el motor original (solo hay parámetros para
  NMC/LFP/LTO/NCA/Na-ion). Para esas dos químicas la app dirá **«sin modelo disponible»** en vez de
  inventar un número.
- **Sigue sin poder subirse el CI**: tu PAT no tiene scope `workflow`. Las releases las firmo a mano.
- **No toco la identidad visual ni el stack.** Todo es aditivo; nada de lo que ya funciona se
  reescribe salvo que un test demuestre un bug.

---

## 7. Decisiones que necesito de Steve

1. **¿Qué opción?** A (recomendada), B o C.
2. **Tolerancias de agrupación por defecto:** propongo **capacidad ±5 %**, **RI ±10 %**, **SoH ±5
   puntos**, **voltaje ±0,05 V** — todas editables. ¿Te sirven o las quieres distintas?
3. **¿El pack necesita un dibujo de la disposición** (esquema 2D de dónde va cada celda) o basta la
   tabla de especificaciones, el BOM y la posición en texto?
