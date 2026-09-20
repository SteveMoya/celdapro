"""Comprueba la migración v2 -> v3 de CeldaPro contra un SQLite real.

Simula una base de datos tal como la dejaba la versión anterior de la app,
aplica la migración escrita en `database_helper.dart` y verifica que:
  1. La tabla de fotos se crea.
  2. La foto que ya existía en `celdas.foto_path` aparece en la galería.
  3. No se pierde ni se duplica ninguna celda.
  4. Borrar una celda se lleva sus fotos por cascada.
"""
import os
import sqlite3
import sys

DB = "/tmp/celdapro-migracion.db"
if os.path.exists(DB):
    os.remove(DB)

V2 = """
CREATE TABLE lotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT NOT NULL, proveedor TEXT,
  origen TEXT, fecha_recepcion INTEGER NOT NULL, notas TEXT);
CREATE TABLE celdas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  lote_id INTEGER REFERENCES lotes(id) ON DELETE SET NULL,
  codigo_interno TEXT NOT NULL UNIQUE, qr TEXT, marca TEXT, modelo TEXT,
  quimica TEXT NOT NULL, capacidad_nominal_mah REAL, voltaje_nominal REAL,
  fecha_fabricacion INTEGER, estado TEXT NOT NULL, veredicto TEXT,
  soh_pct REAL, ubicacion TEXT, foto_path TEXT, notas TEXT, catalog_ref TEXT,
  ir_nominal_mohm REAL, created_at INTEGER NOT NULL);
CREATE TABLE tests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
  fecha INTEGER NOT NULL, capacidad_medida_mah REAL);
CREATE TABLE eventos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
  tipo TEXT NOT NULL, fecha INTEGER NOT NULL);
CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""

# Migración v3, copiada literalmente de database_helper.dart.
MIGRACION = [
    """
      CREATE TABLE celda_fotos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        etiqueta TEXT NOT NULL,
        fecha INTEGER NOT NULL,
        nota TEXT
      )
    """,
    "CREATE INDEX idx_fotos_celda ON celda_fotos(celda_id)",
    """
            INSERT INTO celda_fotos (celda_id, path, etiqueta, fecha)
            SELECT id, foto_path, 'evidence', created_at
            FROM celdas
            WHERE foto_path IS NOT NULL AND foto_path != ''
    """,
]

con = sqlite3.connect(DB)
con.execute("PRAGMA foreign_keys = ON")
con.executescript(V2)

# Datos de una instalación vieja: 3 celdas, solo 2 con foto.
con.executemany(
    "INSERT INTO celdas (codigo_interno, marca, quimica, estado, foto_path, "
    "created_at) VALUES (?,?,?,?,?,?)",
    [
        ("C-0001", "Samsung", "liIon", "classified", "/fotos/celda_1_aaa.jpg", 1000),
        ("C-0002", "LG", "liIon", "received", None, 2000),
        ("C-0003", "Molicel", "liIon", "received", "/fotos/celda_3_ccc.jpg", 3000),
    ],
)
con.commit()

antes = con.execute("SELECT COUNT(*) FROM celdas").fetchone()[0]
print(f"Antes de migrar: {antes} celdas, "
      f"{con.execute('SELECT COUNT(*) FROM celdas WHERE foto_path IS NOT NULL').fetchone()[0]} con foto")

# --- Migración ---
for sql in MIGRACION:
    con.execute(sql)
con.commit()

# --- Comprobaciones ---
fallos = []

tablas = {r[0] for r in con.execute(
    "SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
if "celda_fotos" not in tablas:
    fallos.append("no se creó la tabla celda_fotos")

despues = con.execute("SELECT COUNT(*) FROM celdas").fetchone()[0]
if despues != antes:
    fallos.append(f"se perdieron celdas: {antes} -> {despues}")

fotos = con.execute(
    "SELECT celda_id, path, etiqueta FROM celda_fotos ORDER BY celda_id"
).fetchall()
print(f"Después de migrar: {len(fotos)} fotos en la galería")
for f in fotos:
    print(f"   celda {f[0]} · {f[2]} · {f[1]}")

if len(fotos) != 2:
    fallos.append(f"se esperaban 2 fotos migradas, hay {len(fotos)}")
for celda_id, path, etiqueta in fotos:
    if etiqueta != "evidence":
        fallos.append(f"etiqueta inesperada en celda {celda_id}: {etiqueta}")
    if not path.startswith("/fotos/"):
        fallos.append(f"ruta perdida en celda {celda_id}: {path}")

# La celda sin foto no debe tener fila en la galería.
sin_foto = con.execute(
    "SELECT COUNT(*) FROM celda_fotos WHERE celda_id = 2").fetchone()[0]
if sin_foto != 0:
    fallos.append("se inventó una foto para una celda que no tenía")

# Borrar la celda 1 debe llevarse su foto por cascada.
con.execute("DELETE FROM celdas WHERE id = 1")
con.commit()
restantes = con.execute(
    "SELECT COUNT(*) FROM celda_fotos WHERE celda_id = 1").fetchone()[0]
if restantes != 0:
    fallos.append("borrar una celda no limpió sus fotos")

if fallos:
    print("\nFALLOS:")
    for f in fallos:
        print(" -", f)
    sys.exit(1)

print("\nMigración v2 -> v3 correcta: sin pérdidas, con las fotos ya "
      "existentes conservadas y el borrado en cascada funcionando.")
