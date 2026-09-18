#!/usr/bin/env python3
"""Genera lib/data/cell_catalog.dart para CeldaPro desde la base de datos
de celdas del proyecto battery-tool (src/scripts/cell-database.ts)."""
import re, json, sys, pathlib

SRC = pathlib.Path('/root/proyectos/battery-tool/src/scripts/cell-database.ts')
OUT = pathlib.Path('/root/proyectos/celdapro/lib/data/cell_catalog.dart')

text = SRC.read_text()

# Cada entrada es un objeto de una línea: { name: '...', d: 18.4, ... }
entries = []
for m in re.finditer(r'\{\s*name:\s*\'([^\']+)\'(.*?)\},', text, re.S):
    name, rest = m.group(1), m.group(2)
    obj = {'name': name}
    for k, sval, nval in re.findall(r"(\w+):\s*(?:'([^']*)'|([\d.]+))", rest):
        if sval != '':
            obj[k] = sval
        elif nval != '':
            obj[k] = float(nval) if '.' in nval else int(nval)
    entries.append(obj)

if len(entries) < 90:
    sys.exit(f'Solo se parsearon {len(entries)} celdas; abortando.')

# Marca: primera palabra, con casos especiales.
SPECIAL = {
    'Tesla/Generic': 'Tesla',
    'K2': 'K2 Energy',
    'P42A': 'Re-wrap',
    'Generic': 'Genérica',
}
def brand_of(name: str) -> str:
    first = name.split()[0]
    return SPECIAL.get(first, first)

CHEM = {
    'li-ion': 'liIon', 'lfp': 'lfp', 'lto': 'lto',
    'nimh': 'nimh', 'na-ion': 'other', 'lipo': 'other', 'alk': 'other',
}

def format_of(e) -> str:
    m = re.search(r'\b(\d{4,5})\b', e['name'])
    if m:
        return m.group(1)
    if 'prismatic' in str(e.get('formFactor', '')).lower():
        return 'prismática'
    d, l = e.get('d'), e.get('l')
    if d and l:
        return f'{int(round(d))}{int(round(l))}0'
    return 'otra'

def model_of(name: str, brand: str) -> str:
    # Quita el prefijo de marca para que el modelo no lo repita.
    for pref in (brand, 'Generic', 'Tesla/Generic'):
        if name.startswith(pref + ' '):
            return name[len(pref) + 1:]
    return name

rows = []
for e in entries:
    b = brand_of(e['name'])
    rows.append({
        'name': e['name'],
        'brand': b,
        'model': model_of(e['name'], b),
        'format': format_of(e),
        'cap': int(round(e.get('cap', 0))),
        'v': e.get('v', 0),
        'ir': e.get('ir', 0),
        'chem': CHEM.get(e.get('type', ''), 'other'),
        'amp': e.get('amp'),
        'pulse': e.get('pulseAmp'),
        'charge': e.get('chargeAmp'),
        'd': e.get('d'),
        'l': e.get('l'),
        'w': e.get('w'),
        'rth': e.get('rTh'),
    })

def num(v):
    if v is None:
        return 'null'
    if isinstance(v, float) and v == int(v):
        return str(int(v))
    return str(v)

lines = []
for r in rows:
    lines.append(
        "  CellCatalogEntry(\n"
        f"    name: {r['name']!r},\n"
        f"    brand: {r['brand']!r},\n"
        f"    model: {r['model']!r},\n"
        f"    format: {r['format']!r},\n"
        f"    chemistry: Chemistry.{r['chem']},\n"
        f"    capacityMah: {r['cap']},\n"
        f"    voltage: {num(r['v'])},\n"
        f"    irMohm: {num(r['ir'])},\n"
        f"    maxDischargeA: {num(r['amp'])},\n"
        f"    pulseDischargeA: {num(r['pulse'])},\n"
        f"    chargeA: {num(r['charge'])},\n"
        f"    diameterMm: {num(r['d'])},\n"
        f"    lengthMm: {num(r['l'])},\n"
        f"    weightG: {num(r['w'])},\n"
        f"    thermalResistance: {num(r['rth'])},\n"
        "  ),"
    )

header = '''import 'models/celda.dart';

/// Entrada del catálogo de celdas de referencia.
///
/// Datos portados desde el proyecto **battery-tool** (base de 102 celdas
/// comerciales) para poder dar de alta una celda real indicando solo su modelo:
/// capacidad nominal, voltaje, química y resistencia interna de referencia.
class CellCatalogEntry {
  const CellCatalogEntry({
    required this.name,
    required this.brand,
    required this.model,
    required this.format,
    required this.chemistry,
    required this.capacityMah,
    required this.voltage,
    required this.irMohm,
    this.maxDischargeA,
    this.pulseDischargeA,
    this.chargeA,
    this.diameterMm,
    this.lengthMm,
    this.weightG,
    this.thermalResistance,
  });

  /// Nombre completo (ej. "Samsung 25R (18650)").
  final String name;
  final String brand;
  final String model;

  /// Formato/código de tamaño (18650, 21700, 26650…).
  final String format;
  final Chemistry chemistry;

  /// Capacidad nominal de fábrica (mAh) — la referencia para el SoH.
  final int capacityMah;
  final double voltage;

  /// Resistencia interna de fábrica (mΩ) — referencia de diagnóstico.
  final double irMohm;

  final double? maxDischargeA;
  final double? pulseDischargeA;
  final double? chargeA;
  final double? diameterMm;
  final double? lengthMm;
  final double? weightG;
  final double? thermalResistance;

  /// Etiqueta corta para listas: "Samsung 25R".
  String get shortName => model.isEmpty ? name : '$brand $model';
}
'''

builder = '''
/// Catálogo de celdas de referencia (102 modelos comerciales).
class CellCatalog {
  const CellCatalog._();

  static const List<CellCatalogEntry> all = [
'''

footer = '''  ];

  /// Marcas disponibles, ordenadas alfabéticamente.
  static List<String> get brands {
    final set = all.map((e) => e.brand).toSet().toList()..sort();
    return set;
  }

  /// Formatos disponibles (18650, 21700…), ordenados.
  static List<String> get formats {
    final set = all.map((e) => e.format).toSet().toList()..sort();
    return set;
  }

  /// Busca en el catálogo por texto (nombre, marca, modelo o formato), con
  /// filtros opcionales de química y formato.
  static List<CellCatalogEntry> search(
    String query, {
    Chemistry? chemistry,
    String? format,
  }) {
    final q = query.trim().toLowerCase();
    Iterable<CellCatalogEntry> out = all;

    if (chemistry != null) {
      out = out.where((e) => e.chemistry == chemistry);
    }
    if (format != null && format.isNotEmpty) {
      out = out.where((e) => e.format == format);
    }
    if (q.isNotEmpty) {
      out = out.where((e) =>
          e.name.toLowerCase().contains(q) ||
          e.brand.toLowerCase().contains(q) ||
          e.model.toLowerCase().contains(q) ||
          e.format.toLowerCase().contains(q) ||
          e.capacityMah.toString().contains(q));
    }
    return out.toList();
  }

  /// Busca el mejor candidato para un nombre de celda escrito a mano.
  static CellCatalogEntry? matchByName(String text) {
    final q = text.trim().toLowerCase();
    if (q.length < 3) return null;
    for (final e in all) {
      if (e.name.toLowerCase() == q || e.shortName.toLowerCase() == q) return e;
    }
    final hits = search(q);
    return hits.isEmpty ? null : hits.first;
  }
}
'''

body = header + builder + '\n'.join(lines) + '\n' + footer

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(body)

print(f'OK — {len(rows)} celdas escritas en {OUT}')
print('Ramas:', sorted({r["brand"] for r in rows}))
print('Formatos:', sorted({r["format"] for r in rows}))
print('Químicas:', sorted({r["chem"] for r in rows}))
