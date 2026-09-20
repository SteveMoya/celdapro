# Plan de Mejora — CeldaPro

> **Fecha:** 2026-09-18
> **Autor:** Roxy (asistente)
> **Estado:** ⏳ **Pendiente de aprobación de Steve**
> **Versión actual de la app:** v0.2.0 (APK publicado, firma de depuración)
> **Plan base:** `2026-09-17-celdapro-mvp.md`

---

## 1. Diagnóstico: dónde estamos

CeldaPro v0.2.0 es un MVP funcional y probado:

| Métrica | Valor |
|---|---|
| Código Dart | ~6 800 líneas (lib + test) |
| Tests | 75/75 en verde |
| `flutter analyze` | 0 issues |
| Catálogo de celdas | 102 modelos comerciales (de `battery-tool`) |
| Pantallas | 10 |
| Arquitectura | Flutter M3 + SQLite, 100 % local |

**Lo que ya funciona:** alta de celdas (con catálogo auto-rellenado), lotes, tests de medición,
clasificación por SoH con umbrales configurables, diagnóstico de resistencia interna, flujo con
trazabilidad auditada, fotos de evidencia, escaneo QR, dashboard y exportar/importar CSV.

**Problema central:** es un MVP. Sirve para probarlo, **no todavía para llevar el taller a diario**.
Hay tres huecos que duelen en uso real: no se puede **respaldar** el trabajo, no se pueden **imprimir
etiquetas** para usar el escáner, y **no se entrega ningún papel** al cliente.

---

## 2. Hallazgos verificados

Todo lo siguiente lo comprobé en el código, no es suposición.

### 🔴 Críticos (riesgo de pérdida de datos o de no poder distribuir)

1. **Sin respaldo ni restauración.** Los datos viven en un SQLite dentro del teléfono. Si se
   pierde, se rompe o se desinstala la app, **se va el historial completo del taller**. Verificado:
   no existe ninguna función de backup/restore.
2. **APK firmado con clave de depuración.** Verificado con `apksigner`: `CN=Android Debug`.
   No se puede publicar en Google Play ni actualizar de forma limpia si algún día cambia la clave.
3. **Sin CI.** Cada análisis, test y compilación se hace a mano. No hay red de seguridad
   automática en el repo (`.github/workflows/` no existe).
4. **Metadatos de versión inconsistentes.** `pubspec.yaml` dice `0.1.0+1` mientras las releases
   publicadas son v0.1.0 y v0.2.0. El APK reporta `versionName 0.1.0`. Confunde para soporte.

### 🟠 Brechas de flujo de trabajo (impiden el uso diario)

5. **El escáner QR está a medias: se escanea pero no se genera.** Verificado: no hay generación
   de QR ni impresión de etiquetas. Sin etiquetas pegadas en las celdas, el escáner **no sirve
   para nada** en el taller.
6. **No hay reportes en PDF.** El taller no puede entregar un documento al cliente por celda
   o por lote. (Ya figuraba como pendiente en el TODO.)
7. **Una sola foto por celda.** El campo es `fotoPath` (singular). Un proceso de restauración
   necesita **antes / después / evidencia de fallo**, no una sola imagen.
8. **Registro de tests de uno en uno.** Un taller prueba cientos de celdas de un lote en una
   sesión; hoy hay que abrir el formulario celda por celda. No hay entrada masiva.

### 🟡 Calidad y escala

9. **La capa de datos (2 795 líneas) no tiene ni un test.** Los tests cubren lógica pura y
   pantallas, pero **ningún repositorio se ejecuta contra SQLite**. Incluye la migración
   v1→v2, que jamás se probó en automático.
10. **La lista de inventario carga todas las celdas en memoria**, sin paginación, y el dashboard
    lanza 5 consultas agregadas en cada refresco. Con miles de celdas empezará a ir lento.
11. **Filtros de inventario limitados**: solo texto, veredicto y estado. No se filtra por
    **rango de capacidad**, **rango de SoH**, lote ni fecha.
12. **Sin estadísticas por lote** (rendimiento, % aprovechable, capacidad media recuperada).

### ⚪ Fase 2 (ya previsto, depende de los anteriores)

13. **Agrupación/balanceo de celdas similares** — imprescindible antes de armar packs.
14. **Armado de packs** (`pack-builder.ts` de `battery-tool`, 1 544 líneas reutilizables).
15. **BMS por Bluetooth** (JBD/Daly/JK/Ant, `bms-database.ts`, 336 líneas).
16. **Análisis de degradación** (`degradation-engine.ts`, 285 líneas).

---

## 3. Propuesta: seis hitos

Ordenados por **riesgo y valor real**, no por lo divertido de programar.

### 🛡️ M1 — Blindar los datos *(el más importante)*

**Por qué:** una app 100 % local sin respaldo es una bomba de tiempo. Todo lo demás depende de esto.

- Respaldo completo a un **único archivo** (`.celdapro`): base de datos + fotos + ajustes.
- Restauración desde ese archivo, con **vista previa** de qué se va a restaurar (cuántas celdas,
  lotes, fotos) antes de confirmar.
- **Respaldo automático** periódico a la carpeta que elija el usuario (semanal, configurable).
- Compartir el respaldo por WhatsApp/Drive/correo con el botón de compartir del sistema.
- Aviso recordatorio si el último respaldo tiene más de X días.

**Entregable:** guardar, restaurar y automatizar el respaldo; probado con datos reales de ida y vuelta.
**Aceptación:** crear 50 celdas con fotos → respaldar → borrar la app → reinstalar → restaurar →
los 50 registros, sus tests y sus fotos están intactos.

### 🏷️ M2 — Etiquetas QR e identidad física

**Por qué:** hoy el escáner es un adorno sin etiquetas en las celdas.

- **Generar el QR** de cada celda (el dato ya se guarda).
- **Hoja de etiquetas imprimible**: elegir celdas de un lote y generar una página con N etiquetas,
  con código, marca, modelo y capacidad impresos bajo el QR.
- Opciones de tamaño (etiqueta pequeña para celda, grande para caja) y exportar a **PDF**.
- Escanear desde el formulario de test para no buscar la celda a mano.

**Entregable:** etiquetas QR imprimibles y escaneables, en PDF listo para imprimir.
**Aceptación:** imprimir la hoja, escanear una etiqueta con la app y que abra la celda correcta.

### 📄 M3 — Reportes en PDF

**Por qué:** el taller necesita entregar algo al cliente y archivar evidencia.

- **Informe por celda**: ficha técnica, historial de tests con evolución del SoH, veredicto,
  trazabilidad y foto de evidencia.
- **Informe por lote**: resumen de rendimiento, distribución A/B/C/rechazo y celdas destacadas.
- **Informe de inventario**: listado filtrado con totales.
- Compartir/imprimir con el sistema.
- Encabezado configurable con el **nombre del taller**, logo y datos de contacto.

**Entregable:** PDF por celda, por lote y de inventario, con logo del taller.
**Aceptación:** generar un informe de una celda con 3 tests, abrirlo y que todos los datos coincidan.

### 🧪 M4 — Trabajo por lote y evidencia múltiple

**Por qué:** es donde se va el tiempo del taller.

- **Entrada masiva de tests**: elegir un lote, ver sus celdas pendientes y registrar mediciones
  seguidas sin salir de la pantalla, viendo el veredicto en vivo de cada una.
- **Múltiples fotos por celda** con etiqueta (antes / después / fallo / otra) y visor con zoom.
- Duplicar una celda para casos repetidos.
- Marcar celdas de un lote en bloque (cambio de etapa, asignar ubicación).

**Entregable:** registrar un lote completo de forma fluida y adjuntar varias fotos por celda.
**Aceptación:** registrar 20 celdas de un lote seguido, sin volver al inventario, en menos de 3 minutos.

### 🔬 M5 — Calidad, escala y estadísticas

- **Tests de la capa de datos** con SQLite en memoria (`sqflite_common_ffi`): CRUD, filtros,
  agregados y **migración v1→v2** (que hoy no está probada).
- **Paginación / carga incremental** del inventario y consultas agregadas en una sola pasada.
- **Filtros avanzados**: rango de capacidad, rango de SoH, lote y fecha; guardar filtros favoritos.
- **Estadísticas por lote**: % aprovechable, capacidad media recuperada, comparación entre lotes.
- Arreglar los **metadatos de versión** (una sola fuente de verdad).
- **Accesibilidad y textos**: revisar contraste, tamaños y que ningún texto se corte en pantallas
  pequeñas.

**Entregable:** capa de datos probada, app ágil con miles de celdas y estadísticas por lote.
**Aceptación:** test que migra una BD v1 real a v2 sin perder datos; inventario con 5 000 celdas
que abre en menos de 1 segundo.

### 🚀 M6 — Distribución y automatización

- **Keystore de release** propio (firma real) + guardado seguro, fuera del repositorio.
- **CI en GitHub Actions**: `analyze` + `test` en cada push, y **APK release firmado como
  GitHub Release al crear un tag** (el mismo patrón que ya funciona en `horas-trabajo`).
- Guía de instalación y actualización para el taller.
- Ficha de privacidad (la app no envía nada a ningún servidor).

**Entregable:** releases firmadas y publicadas automáticamente con un tag.
**Aceptación:** crear el tag `v0.3.0` y que el APK firmado aparezca solo en la release.

---

## 4. Priorización y opciones

No todo cabe de una vez. Estas son las rutas posibles, con ventajas y desventajas.

### Opción A — Solo lo crítico (M1 + M6) ⭐ *recomendada para empezar*

- **Ventajas:** elimina el riesgo de perder el taller en un día malo y deja la app distribuible
  de verdad. Es el cimiento: sin respaldo, todo lo demás construye sobre arena. Poco código nuevo,
  mucha tranquilidad.
- **Desventajas:** el taller sigue sin poder imprimir etiquetas ni entregar reportes al cliente;
  las mejoras que más se *sienten* en el día a día quedan para después.

### Opción B — Valor de taller (M1 + M2 + M3 + M6)

- **Ventajas:** la app pasa de "prototipo" a **herramienta de trabajo real**: respaldada,
  con etiquetas escaneables y reportes que se entregan al cliente. Es el salto de utilidad más
  grande por esfuerzo invertido.
- **Desventajas:** es bastante más trabajo y más superficie nueva (generación de PDF, impresión);
  conviene probarlo por partes en el teléfono antes de dar el siguiente paso.

### Opción C — Completo (M1 → M6)

- **Ventajas:** la app queda madura, rápida a escala, con la capa de datos probada y lista para
  las funciones grandes de fase 2 (packs, BMS, degradación).
- **Desventajas:** mucho tiempo antes de que Steve vea un cambio útil en la mano; el riesgo es
  pulir cosas que aún no se usan mientras falta lo básico.

### Opción D — Ir directo a fase 2 (packs + BMS)

- **Ventajas:** es lo más llamativo y lo que más automatiza la medición; reutiliza motores ya
  escritos en `battery-tool`.
- **Desventajas:** ⚠️ **la menos recomendable ahora.** Construiría funciones avanzadas sobre datos
  que todavía no se respaldan, sin etiquetas para identificar celdas y sin forma de entregar un
  informe. El BMS por Bluetooth además es la parte más frágil (protocolos propietarios, se rompen
  entre versiones de firmware) y la de mayor coste de prueba: **no puedo probarla yo**, hace falta
  un BMS físico y una celda real en la mano.

**Mi recomendación:** empezar por **M1 + M6** (los cimientos y la distribución), y seguir con
**M2 + M3** en una segunda tanda. Así Steve gana algo tangible con cada entrega y nada se construye
sobre datos que aún no están protegidos.

---

## 5. Riesgos y límites honestos

- **No tengo teléfono ni celdas reales.** Todo lo verifico con tests, análisis estático y
  compilación; la prueba final en dispositivo la hace Steve. Ya pasó con MensajesPro: el envío con
  el teléfono bloqueado no se podía validar sin teléfono.
- **La impresión de PDF depende del teléfono.** Genero el PDF y lo comparto; el resultado final
  depende del visor/impresora del usuario. Probaré el contenido, no el papel.
- **El respaldo automático en Android está limitado** por las restricciones de segundo plano. Lo
  planteo como respaldo **manual/con recordatorio** garantizado, y automático "cuando se pueda".
  Prometerlo al 100 % sería mentir.
- **Los umbrales de clasificación siguen siendo convención de taller**, no norma. Son configurables.
- **Nada de esto sustituye las normas de seguridad de litio**: una celda hinchada se rechaza, no se
  reempaqueta.
- **No tocaré `.github/workflows/` con un token sin scope `workflow`** (ya nos pasó en
  `nextjs-dashboard`): para el CI hace falta el PAT correcto o que Steve lo suba a mano.

---

## 6. Qué NO haré sin aprobación explícita

- Cambiar el nombre, la identidad visual o el stack (Flutter M3 + SQLite se mantiene).
- Subir precios, publicar en Google Play o hacer público nada nuevo.
- Empezar fase 2 (packs / BMS) antes de cerrar M1.
- Reescribir pantallas que ya funcionan: las mejoras son aditivas salvo que un test demuestre un bug.

---

## 7. Cómo lo reportaría

Al cerrar **cada** hito: qué cambió, qué quedó verificado (`analyze` + tests + APK compilado),
qué falta y qué no pude probar. Un APK nuevo por hito, con su release y su número de versión.
Si algo se demora o no sale, lo digo antes de seguir, no al final.

---

## 8. Decisión que necesito de Steve

1. **¿Qué opción?** A, B, C o D (recomiendo **A** para arrancar ya, y seguir con B).
2. **¿Nombre y datos del taller** para los reportes PDF (nombre comercial, teléfono, logo)?
3. **¿Ya tiene celdas etiquetadas** con algún código/QR propio que haya que respetar?
4. **¿Cuántas celdas maneja hoy?** (para calibrar el trabajo de escala del M5).
