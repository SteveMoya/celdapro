# Plan — CeldaPro: gestión y organización de restauración de celdas de litio (MVP)

> **TODO 18.** Fecha: 2026-09-17. Estado: **pendiente de aprobación de Steve**.
>
> **Supuestos por defecto** (si algo no coincide, se cambia y sigo; no bloquean el arranque):
> 1. **Nombre:** `CeldaPro` (alternativas: LitioManager, CellRestore, TallerLitio).
> 2. **Alcance MVP:** solo **celdas sueltas** (recepción → test → clasificación → stock).
>    El armado de **packs** va en fase 2.
> 3. **BMS:** **registro manual primero**; captura real por **Bluetooth (JBD/Daly/JK/Ant)** en fase 2.
> 4. **Datos:** **offline-first 100% local** (SQLite en el teléfono) + exportar/importar CSV.
>    Sin cuentas, sin nube, sin costos.
> 5. **Plataforma:** **Android** (es el único toolchain disponible en este entorno; iOS requeriría Mac + cuenta Apple).

---

## 🎯 Objetivo
Digitalizar el taller de restauración de celdas de litio: **sustituir el cuaderno/Excel por una app**
que registre cada celda, su test, su clasificación y su trazabilidad, con métricas del proceso.

**Resultado esperado:** saber en 2 toques dónde está cualquier celda, qué se midió, si sirve (A/B/C)
o se rechaza, y cuántas celdas/lotes se procesaron este mes y con qué rendimiento.

## 🚫 Fuera del MVP (fase 2+)
- Armado de **packs** (BOM, layout serie/paralelo, validación eléctrica — reutilizable de `battery-tool`).
- **Captura BMS por Bluetooth** (protocolos JBD/Daly/JK/Ant ya investigados en `battery-tool`).
- Multi-operador en la nube / sync entre teléfonos, ventas y clientes, PDF avanzado.
- iOS.

## 🧱 Stack
- **Flutter 3.47 + Material 3** (mismo stack ya probado en `horas-trabajo` y `mensajespro`).
- **SQLite local** (`sqflite`) — sin backend, sin cuentas.
- **Escaneo QR/código de barras** (`mobile_scanner`) para alta rápida de celdas, con **entrada manual de respaldo**.
- **Fotos de evidencia** (`image_picker`) guardadas en el almacenamiento local de la app.
- **CSV** (`csv` + `share_plus`) para exportar/importar.
- Paleta de marca: **verde litio `#2E7D32`** + acento ámbar `#FFB300`; tipografía Noto Sans.

## 🔄 Flujo digitalizado (máquina de estados por celda)
```
Recepcionada → En test → Clasificada (A/B/C/Rechazo) → Balanceada → Reempacada → Aprobada QA
                     ↘ Rechazada (con motivo)
```
Cada cambio de estado queda **fechado y auditado** (quién/cuándo/nota) = trazabilidad real.

## 🗄️ Modelo de datos (SQLite)
- **lotes** — `id, codigo, proveedor, origen, fecha_recepcion, notas, total_celdas`
- **celdas** — `id, lote_id, codigo_interno (único), qr, marca, modelo, quimica (Li-ion/LFP/LTO/NiMH),
  capacidad_nominal_mAh, voltaje_nominal, fecha_fabricacion, estado, ubicacion, foto_path, notas`
- **tests** — `id, celda_id, fecha, voltaje_v, capacidad_medida_mAh, resistencia_interna_mohm,
  ciclos, corriente_descarga_a, temperatura_c, soh_pct (calculado), veredicto (A/B/C/rechazo), operador, notas`
- **eventos** — `id, celda_id, tipo (cambio de estado/nota/test), estado_anterior, estado_nuevo, fecha, nota`
- **ajustes** — umbrales de clasificación editables (p. ej. A ≥ 90 % SoH, B ≥ 75 %, C ≥ 60 %, < 60 % rechazo)

**Clasificación automática:** el veredicto se calcula desde `capacidad_medida / capacidad_nominal`
(SoH) contra los umbrales configurables; Steve puede ajustarlos sin recompilar.

## 📱 Pantallas (Material 3)
1. **Inicio / Dashboard** — celdas procesadas, % rechazo, capacidad promedio, celdas por veredicto, actividad reciente.
2. **Inventario** — lista de celdas con búsqueda y filtros (estado, veredicto, lote, rango de capacidad); orden configurable.
3. **Detalle de celda** — datos, foto, historial de tests y eventos, acciones (nuevo test, cambiar estado, editar, eliminar).
4. **Nuevo test** — formulario de medición; **calcula SoH y veredicto en vivo** mientras se escribe.
5. **Lotes** — lista de lotes con conteo/rendimiento; alta y detalle.
6. **Ajustes** — umbrales de clasificación, catálogo de motivos de rechazo, exportar/importar CSV, borrar datos.

*(Extra útil: “Exportar CSV” y “Compartir” accesibles desde Dashboard e Inventario.)*

## 📅 Fases de ejecución

### Fase 0 — Arranque (rápida, valida el entorno)
- Repo `SteveMoya/celdapro` (público), scaffold Flutter `me.stevemoya.celdapro`, `minSdk 26`.
- Tema M3 con la paleta, l10n `es`, README.
- **Compilar APK debug** para confirmar que el toolchain funciona.
- **Entregable:** repo con la app vacía que compila.

### Fase A — Datos
- Modelos (`lote`, `celda`, `test`, `evento`), `database_helper` con migraciones y versionado.
- Repositorios (CRUD) + **tests unitarios de la lógica de clasificación** (SoH/veredicto y umbrales).
- **Entregable:** capa de datos con tests verdes.

### Fase B — Núcleo funcional
- Alta de lote; alta de celda (individual, **escaneo QR/barras** o manual, y alta rápida en serie del mismo lote).
- Registro de test con **cálculo automático de SoH y veredicto**.
- Máquina de estados + registro de **eventos** (trazabilidad) y motivos de rechazo.
- **Entregable:** flujo recepción → test → clasificación funcionando.

### Fase C — Interfaz Material 3
- Pantallas 1–6 completas, con estados vacíos, errores y **modo claro/oscuro**.
- **Evidencia fotográfica** por celda (cámara/galería, guardada local).
- **Entregable:** app usable de punta a punta en el teléfono.

### Fase D — Reportes y datos
- Dashboard con métricas reales (por lote/periodo), **exportar CSV** y **compartir**.
- Importar CSV (carga inicial del inventario actual de Steve).
- **Entregable:** reportes y respaldo de datos.

### Fase E — QA y entrega
- `flutter analyze` en **0** y suite **verde**; pruebas del flujo completo con datos de ejemplo.
- APK **release** (arm64/arm32) y publicación como **GitHub Release**.
- **Entregable:** APK instalable + release publicada.

## ✅ Cómo se validará (evidencia real, no promesas)
- `flutter analyze` = 0 issues y `flutter test` verde en cada fase (se te reporta el número).
- **APK compilado de verdad** en este entorno (no solo código).
- Tests específicos de la clasificación con casos borde (capacidad 0, nominal ausente, umbrales límite).
- Prueba manual tuya en el teléfono con tus celdas reales.

## ⚠️ Riesgos y limitaciones (honesto)
- **Mediciones reales:** la app **no mide** la capacidad por sí sola; el dato lo da tu tester/charger.
  Conectarlo (BMS por Bluetooth o instrumento) es la **fase 2**, la parte más frágil y dependiente del hardware.
- **Umbrales de clasificación:** son una **convención del taller**, no un estándar universal; se ajustan en Ajustes.
- **Seguridad de celdas de litio:** la app organiza el proceso, **no sustituye** las normas de seguridad del taller
  (celdas hinchadas, dañadas o sin tensión deben ir a rechazo/aislamiento, no a reempaque).
- **iOS** no se puede compilar aquí; requeriría Mac + cuenta Apple ($99/año).
- Sin nube: los datos viven en el teléfono → conviene exportar CSV como respaldo (la app lo facilita).

## ❓ Confirmaciones que cambian el plan
1. Nombre definitivo (si no, `CeldaPro`).
2. ¿Solo celdas o también **packs** en el MVP? (por defecto: solo celdas)
3. ¿BMS manual o **Bluetooth real** desde el inicio? (por defecto: manual)
4. ¿Offline local o **nube Supabase**? (por defecto: local)
5. ¿Plataforma **Android** solamente? (por defecto: Android)

**Si apruebas tal cual, respondo “sí” a este plan y lo ejecuto en el orden 0 → A → B → C → D → E,
reportándote al cierre de cada fase.** Los puntos abiertos se pueden corregir a mitad de camino.
