# CeldaPro

App Android para **gestionar y organizar la restauración de celdas de litio** en el taller:
registro por celda, test de capacidad, clasificación automática (A/B/C/Rechazo), trazabilidad
completa y métricas del proceso. **100% local** — sin backend, sin cuentas, sin costos.

Flutter 3.47 + Material 3 · SQLite (sqflite) · etiquetas con código de barras y QR · informes PDF
· respaldo completo · exportar/importar CSV.

## ✨ Funcionalidades

- 📚 **Catálogo de 102 celdas comerciales** (portado del proyecto `battery-tool`): eliges tu modelo
  y se rellenan solos la marca, el modelo, la química, la **capacidad nominal** (referencia del SoH),
  el voltaje y la **resistencia interna de fábrica**.
- 🏷️ **Inventario de celdas** con código interno único, QR, marca, modelo, química y ubicación.
- 📦 **Lotes**: agrupa celdas por origen/compra y mide su rendimiento.
- 🧪 **Tests de medición**: capacidad (mAh), voltaje, resistencia interna, ciclos, corriente, temperatura.
- 🎯 **Clasificación automática** por SoH (*capacidad medida ÷ nominal*) con **umbrales configurables**
  (por defecto A ≥ 90 %, B ≥ 75 %, C ≥ 60 %, por debajo rechazo).
- ⚡ **Diagnóstico de resistencia interna**: compara lo medido con la resistencia de fábrica del
  catálogo y avisa de desgaste (Normal / Elevada / Muy alta) aunque la capacidad aún parezca bien.
- 🔄 **Flujo por celda**: `Recepcionada → En test → Clasificada → Balanceada → Reempacada → Aprobada QA`
  (o `Rechazada` con motivo).
- 📜 **Trazabilidad**: cada cambio de estado y cada test queda registrado con fecha.
- 📸 **Evidencia fotográfica** por celda.
- 🖨️ **Etiquetas imprimibles**: cada celda se etiqueta con **código de barras** (identificador),
  **QR** (ficha completa) y los datos en texto. Tres tamaños, en PDF listo para imprimir o compartir.
- 📷 **Escaneo**: al leer una etiqueta abre la celda; si no existe en el teléfono, da de alta una
  nueva con los datos que traía la etiqueta.
- 🛡️ **Respaldo y restauración**: base de datos, fotos y ajustes en un solo archivo `.celdapro`,
  con vista previa antes de restaurar y copia de seguridad previa automática.
- 🧪 **Test masivo**: registra las mediciones de un lote entero en serie, sin volver al inventario.
  Escribe la medida, ve el veredicto en vivo y el botón «listo» del teclado pasa a la siguiente.
  El operador se mantiene para toda la sesión.
- 📷 **Varias fotos por celda** con etiqueta (antes / después / fallo / otra), visor con zoom y
  portada configurable.
- 📄 **Informes en PDF**: ficha completa de una celda (datos, mediciones y trazabilidad), informe
  de un lote y del inventario completo, con el logo de la marca, línea de firma y estadísticas
  (aptas, % rechazo, SoH medio/mínimo/máximo, capacidad aprovechable). Se imprimen o se comparten
  para entregárselos al cliente.
- 📊 **Dashboard** con celdas procesadas, % rechazo, SoH promedio y actividad reciente.
- 📤 **Exportar CSV** e **importar inventario** existente.
- 🎨 **Marca propia**: logo, icono y guía de marca en `brand/` (ver [BRAND.md](brand/BRAND.md)).

## 🔒 Privacidad

Toda la información (celdas, tests, fotos) se guarda **solo en el teléfono**. La app no envía
datos a ningún servidor y no requiere cuenta. No pide permiso de internet para funcionar.

## 📱 Requisitos

- Android 8.0 (API 26) o superior.

## 🚀 Desarrollo

```sh
flutter pub get
flutter analyze     # 0 issues
flutter test        # suite verde
flutter build apk --release --split-per-abi
```

### Firma de la release

El APK de release se firma con tu keystore propio. Sin él, Gradle cae a la clave de depuración
(sirve para probar, **no** para publicar).

```sh
./tools/generar_keystore.sh          # crea el keystore y te dice qué apuntar
cp android/key.properties.example android/key.properties   # y rellénalo
```

`android/key.properties` y los `.jks` **nunca** se suben al repositorio (están en `.gitignore`).

### Publicar una versión

Sube la versión en `pubspec.yaml` y en `lib/core/app_info.dart` (un test comprueba que coincidan),
crea el tag y el CI compila y publica el APK firmado solo:

```sh
git tag -a v0.3.0 -m "CeldaPro v0.3.0" "$(git rev-parse HEAD)"
git push origin v0.3.0
```

Secretos que necesita el workflow de release (Settings → Secrets → Actions):
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
Si faltan, el workflow **falla a propósito** en vez de publicar un APK mal firmado.

## 📂 Estructura

```text
lib/
├── core/
│   ├── theme.dart            # Material 3 (verde litio #2E7D32)
│   ├── classification.dart   # SoH + veredicto (lógica pura, testeada)
│   ├── diagnostics.dart      # Diagnóstico de resistencia interna
│   ├── cell_stats.dart       # Resumen numérico de celdas (informes y dashboard)
│   ├── batch_session.dart    # Cola del registro de mediciones en serie
│   ├── cell_code.dart        # Contenido de la etiqueta (barras + QR)
│   └── app_info.dart         # Nombre y versión (una sola fuente)
├── data/
│   ├── cell_catalog.dart     # 102 celdas comerciales (de battery-tool)
│   ├── models/               # lote, celda, cell_test, cell_event
│   ├── repositories/         # CRUD sobre SQLite
│   ├── database_helper.dart  # esquema + migraciones
│   └── preferences_store.dart# umbrales, motivos de rechazo, taller, respaldo
├── services/
│   ├── code_service.dart     # generación de códigos de barras y QR
│   ├── label_service.dart    # hojas de etiquetas en PDF
│   ├── report_service.dart   # informes PDF (celda, lote, inventario)
│   ├── pdf_fonts.dart        # Inter incrustada (acentos y Ω en los PDF)
│   ├── backup_service.dart   # respaldo y restauración (.celdapro)
│   ├── photo_service.dart    # fotos de evidencia
│   └── csv_service.dart      # exportar/importar inventario
├── state/                    # controladores (provider)
└── features/                 # pantallas Material 3
    ├── catalog/              # catálogo de celdas comerciales
    ├── dashboard/            # métricas
    ├── inventory/            # lista, detalle, formularios, escáner
    ├── labels/               # vista previa e impresión de etiquetas
    ├── reports/              # informes PDF con vista previa
    ├── tests/                # registro de mediciones en serie (test masivo)
    ├── lotes/                # lotes
    └── settings/             # umbrales, respaldo, CSV, privacidad

brand/                        # marca: logo, icono, brand board y guía
assets/fonts/                 # Inter (PDF)
assets/images/                # logo para los informes
tools/generar_catalogo.py     # regenera cell_catalog.dart desde battery-tool
tools/generar_keystore.sh     # crea el keystore de firma
```

## ⚠️ Aviso de seguridad

Esta app **organiza el proceso**, no sustituye las normas de seguridad del taller. Las celdas
hinchadas, dañadas o sin tensión deben ir a **rechazo/aislamiento**, nunca a reempaque.

## 📋 Estado

MVP completo + marca, respaldo, etiquetas, informes y trabajo por lote (TODO 18). Ver el plan de
mejoras en `.hermes/plans/2026-09-18-celdapro-mejoras.md`.

Pendiente: tests de la capa de datos, acciones en bloque sobre un lote,
captura de BMS por Bluetooth y armado de packs.
