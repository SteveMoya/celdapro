import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../core/classification.dart';
import '../data/models/celda.dart';
import '../data/models/lote.dart';

/// Importación/exportación de inventario en CSV.
class CsvService {
  const CsvService();

  static const _headers = <String>[
    'codigo_interno',
    'qr',
    'lote',
    'marca',
    'modelo',
    'quimica',
    'capacidad_nominal_mah',
    'voltaje_nominal',
    'estado',
    'veredicto',
    'soh_pct',
    'ubicacion',
    'notas',
  ];

  /// Genera el CSV del inventario (celdas + nombre de lote).
  String buildCsv({
    required List<Celda> celdas,
    required Map<int, Lote> lotesById,
  }) {
    final rows = <List<Object?>>[_headers];
    for (final c in celdas) {
      final lote = c.loteId == null ? null : lotesById[c.loteId];
      rows.add([
        c.codigoInterno,
        c.qr,
        lote?.codigo,
        c.marca,
        c.modelo,
        c.quimica.label,
        c.capacidadNominalMah,
        c.voltajeNominal,
        c.estado.label,
        c.veredicto?.code,
        c.sohPct,
        c.ubicacion,
        c.notas,
      ]);
    }
    return csv.encode(rows);
  }

  /// Escribe el CSV en un fichero temporal y abre el diálogo de compartir.
  Future<void> shareCsv(String csv, {String name = 'celdapro_inventario'}) async {
    final dir = Directory.systemTemp;
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .split('.')
        .first;
    final file = File('${dir.path}/${name}_$stamp.csv');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Inventario CeldaPro',
      ),
    );
  }

  /// Lee un CSV de celdas. Devuelve las celdas válidas y los errores por fila.
  ImportResult parseCsv(String content) {
    final rows = csv.decode(content.replaceAll('\r\n', '\n'));
    if (rows.isEmpty) {
      return const ImportResult(celdas: [], errors: ['El archivo está vacío']);
    }

    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
    int idx(String name) => header.indexOf(name);

    final iCodigo = idx('codigo_interno');
    if (iCodigo < 0) {
      return const ImportResult(
        celdas: [],
        errors: ['Falta la columna obligatoria "codigo_interno"'],
      );
    }

    final celdas = <Celda>[];
    final errors = <String>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) continue;

      String? cell(int at) {
        if (at < 0 || at >= row.length) return null;
        final v = row[at].toString().trim();
        return v.isEmpty ? null : v;
      }

      final codigo = cell(iCodigo);
      if (codigo == null) {
        errors.add('Fila ${i + 1}: sin codigo_interno');
        continue;
      }

      double? num(int at) {
        final raw = cell(at);
        if (raw == null) return null;
        return double.tryParse(raw.replaceAll(',', '.'));
      }

      celdas.add(
        Celda(
          codigoInterno: codigo,
          qr: cell(idx('qr')),
          marca: cell(idx('marca')),
          modelo: cell(idx('modelo')),
          quimica: _chemistryFromLabel(cell(idx('quimica'))),
          capacidadNominalMah: num(idx('capacidad_nominal_mah')),
          voltajeNominal: num(idx('voltaje_nominal')),
          estado: _stateFromLabel(cell(idx('estado'))),
          veredicto: Verdict.fromCode(cell(idx('veredicto'))),
          sohPct: num(idx('soh_pct')),
          ubicacion: cell(idx('ubicacion')),
          notas: cell(idx('notas')),
          createdAt: DateTime.now(),
        ),
      );
    }

    return ImportResult(celdas: celdas, errors: errors);
  }

  Chemistry _chemistryFromLabel(String? label) {
    if (label == null) return Chemistry.liIon;
    final l = label.toLowerCase();
    if (l.contains('lfp') || l.contains('lifepo')) return Chemistry.lfp;
    if (l.contains('lto')) return Chemistry.lto;
    if (l.contains('nimh')) return Chemistry.nimh;
    if (l.contains('li-ion') || l.contains('liion') || l.contains('li ion')) {
      return Chemistry.liIon;
    }
    return Chemistry.other;
  }

  CellState _stateFromLabel(String? label) {
    if (label == null) return CellState.received;
    final l = label.toLowerCase();
    for (final s in CellState.values) {
      if (s.label.toLowerCase() == l) return s;
    }
    return CellState.received;
  }
}

/// Resultado de importar un CSV.
class ImportResult {
  const ImportResult({required this.celdas, required this.errors});
  final List<Celda> celdas;
  final List<String> errors;

  /// Codifica a JSON para poder pasarlo por el selector de archivos.
  static ImportResult fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, Object?>;
    final list = (map['celdas'] as List?) ?? const [];
    return ImportResult(
      celdas: list
          .map((e) => Celda.fromMap((e as Map).cast<String, Object?>()))
          .toList(),
      errors: ((map['errors'] as List?) ?? const []).cast<String>(),
    );
  }
}
