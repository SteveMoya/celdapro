# CeldaPro

App Android para **gestionar y organizar la restauración de celdas de litio** en el taller:
registro por celda, test de capacidad, clasificación automática (A/B/C/Rechazo), trazabilidad
completa y métricas del proceso. **100% local** — sin backend, sin cuentas, sin costos.

Flutter 3.47 + Material 3 · SQLite (sqflite) · escaneo QR/código de barras · exportar/importar CSV.

## ✨ Funcionalidades

- 🏷️ **Inventario de celdas** con código interno único, QR, marca, modelo, química y ubicación.
- 📦 **Lotes**: agrupa celdas por origen/compra y mide su rendimiento.
- 🧪 **Tests de medición**: capacidad (mAh), voltaje, resistencia interna, ciclos, corriente, temperatura.
- 🎯 **Clasificación automática** por SoH (*capacidad medida ÷ nominal*) con **umbrales configurables**
  (por defecto A ≥ 90 %, B ≥ 75 %, C ≥ 60 %, por debajo rechazo).
- 🔄 **Flujo por celda**: `Recepcionada → En test → Clasificada → Balanceada → Reempacada → Aprobada QA`
  (o `Rechazada` con motivo).
- 📜 **Trazabilidad**: cada cambio de estado y cada test queda registrado con fecha.
- 📸 **Evidencia fotográfica** por celda.
- 📊 **Dashboard** con celdas procesadas, % rechazo, SoH promedio y actividad reciente.
- 📤 **Exportar CSV** e **importar inventario** existente.

## 🔒 Privacidad

Toda la información (celdas, tests, fotos) se guarda **solo en el teléfono**. La app no envía
datos a ningún servidor y no requiere cuenta.

## 📱 Requisitos

- Android 8.0 (API 26) o superior.

## 🚀 Desarrollo

```sh
flutter pub get
flutter analyze     # 0 issues
flutter test        # suite verde
flutter build apk --release --split-per-abi
```

## 📂 Estructura

```text
lib/
├── core/
│   ├── theme.dart            # Material 3 (verde litio #2E7D32)
│   └── classification.dart   # SoH + veredicto (lógica pura, testeada)
├── data/
│   ├── models/               # lote, celda, cell_test, cell_event
│   ├── repositories/         # CRUD sobre SQLite
│   ├── database_helper.dart  # esquema + migraciones
│   └── preferences_store.dart# umbrales y motivos de rechazo
├── services/                 # fotos, QR, CSV
├── state/                    # controladores (provider)
└── features/                 # pantallas Material 3
```

## ⚠️ Aviso de seguridad

Esta app **organiza el proceso**, no sustituye las normas de seguridad del taller. Las celdas
hinchadas, dañadas o sin tensión deben ir a **rechazo/aislamiento**, nunca a reempaque.

## 📋 Estado

MVP en desarrollo (TODO 18). Fase 0 (arranque) y A (datos) completadas.
