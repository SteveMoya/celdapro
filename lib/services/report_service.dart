import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/cell_stats.dart';
import '../core/classification.dart';
import '../data/models/celda.dart';
import '../data/models/cell_event.dart';
import '../data/models/cell_test.dart';
import '../data/models/lote.dart';
import 'pdf_fonts.dart';

/// Informes en PDF: ficha de una celda, informe de un lote y del inventario.
///
/// Se generan en el teléfono, sin conexión, y se pueden imprimir o compartir
/// para entregárselos a un cliente.
class ReportService {
  const ReportService();

  /// Verde de marca y acento ámbar (los mismos de la app).
  static final _verde = PdfColor.fromHex('#2E7D32');
  static final _ambar = PdfColor.fromHex('#FFB300');
  static final _gris = PdfColor.fromHex('#5F6368');
  static final _grisClaro = PdfColor.fromHex('#F1F3F4');
  static final _rojo = PdfColor.fromHex('#C62828');

  // ---------- Ficha de una celda ----------

  /// Ficha completa de una celda: datos, historial de tests y trazabilidad.
  Future<Uint8List> fichaCelda({
    required Celda celda,
    Lote? lote,
    List<CellTest> tests = const [],
    List<CellEvent> eventos = const [],
    String? nombreTaller,
    String? logoPath,
    Uint8List? foto,
  }) async {
    final fuentes = await PdfFonts.load();
    final marca = await _logo(logoPath);
    final doc = pw.Document(title: 'Celda ${celda.codigoInterno} — CeldaPro');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(14 * PdfPageFormat.mm,
            12 * PdfPageFormat.mm, 14 * PdfPageFormat.mm, 14 * PdfPageFormat.mm),
        header: (ctx) => ctx.pageNumber == 1
            ? _encabezado(fuentes, marca, 'Ficha de celda', nombreTaller)
            : pw.SizedBox(),
        footer: (ctx) => _pie(fuentes, ctx),
        build: (ctx) => [
          _tituloCelda(fuentes, celda, lote),
          pw.SizedBox(height: 4 * PdfPageFormat.mm),
          if (foto != null) ...[
            pw.Center(
              child: pw.Container(
                height: 45 * PdfPageFormat.mm,
                child: pw.Image(pw.MemoryImage(foto), fit: pw.BoxFit.contain),
              ),
            ),
            pw.SizedBox(height: 4 * PdfPageFormat.mm),
          ],
          _seccion(fuentes, 'Identificación'),
          _tablaDatos(fuentes, [
            ['Código interno', celda.codigoInterno],
            [
              'Lote',
              lote == null
                  ? '—'
                  : [
                      lote.codigo,
                      if (lote.proveedor != null && lote.proveedor!.isNotEmpty)
                        lote.proveedor!,
                    ].join(' · '),
            ],
            if (celda.qr != null && celda.qr!.isNotEmpty) ['Código QR', celda.qr!],
            ['Ubicación', celda.ubicacion ?? '—'],
            ['Registrada', _fecha(celda.createdAt)],
          ]),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          _seccion(fuentes, 'Datos técnicos'),
          _tablaDatos(fuentes, [
            ['Marca', celda.marca ?? '—'],
            ['Modelo', celda.modelo ?? '—'],
            ['Química', celda.quimica.label],
            ['Capacidad nominal', formatMah(celda.capacidadNominalMah ?? 0)],
            ['Voltaje nominal', _voltaje(celda.voltajeNominal)],
            if (celda.irNominalMohm != null)
              ['RI de fábrica', '${celda.irNominalMohm} mΩ'],
            if (celda.fechaFabricacion != null)
              ['Fecha de fabricación', _fecha(celda.fechaFabricacion!)],
          ]),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          _seccion(fuentes, 'Resultado de la restauración'),
          _tablaDatos(fuentes, [
            ['Estado actual', celda.estado.label],
            ['Veredicto', _veredictoTexto(celda.veredicto)],
            ['SoH', formatSoh(celda.sohPct)],
            ['Mediciones registradas', '${tests.length}'],
            if (celda.notas != null && celda.notas!.isNotEmpty)
              ['Notas', celda.notas!],
          ]),
          if (tests.isNotEmpty) ...[
            pw.SizedBox(height: 5 * PdfPageFormat.mm),
            _seccion(fuentes, 'Historial de mediciones'),
            _tablaHistorial(fuentes, tests),
          ],
          if (eventos.isNotEmpty) ...[
            pw.SizedBox(height: 5 * PdfPageFormat.mm),
            _seccion(fuentes, 'Trazabilidad'),
            _tablaEventos(fuentes, eventos),
          ],
          pw.SizedBox(height: 8 * PdfPageFormat.mm),
          _firma(fuentes),
        ],
      ),
    );

    return doc.save();
  }

  // ---------- Informe de un lote ----------

  /// Informe de todos los lotes o de uno concreto.
  ///
  /// Si [lote] es null se genera el informe del inventario completo.
  Future<Uint8List> informe({
    required List<Celda> celdas,
    Map<int, Lote> lotesById = const {},
    Lote? lote,
    Thresholds thresholds = const Thresholds(),
    String? nombreTaller,
    String? logoPath,
    String? operador,
  }) async {
    final fuentes = await PdfFonts.load();
    final marca = await _logo(logoPath);
    final stats = CellStats.from(celdas);
    final titulo = lote == null ? 'Informe de inventario' : 'Informe de lote';
    final doc = pw.Document(
      title: lote == null ? 'Inventario — CeldaPro' : '${lote.codigo} — CeldaPro',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(14 * PdfPageFormat.mm,
            12 * PdfPageFormat.mm, 14 * PdfPageFormat.mm, 14 * PdfPageFormat.mm),
        header: (ctx) => ctx.pageNumber == 1
            ? _encabezado(fuentes, marca, titulo, nombreTaller)
            : pw.SizedBox(),
        footer: (ctx) => _pie(fuentes, ctx),
        build: (ctx) => [
          pw.Text(
            lote == null ? 'Inventario completo' : 'Lote ${lote.codigo}',
            style: fuentes.style(fontSize: 16, bold: true, color: _verde),
          ),
          if (lote != null) ...[
            pw.SizedBox(height: 1 * PdfPageFormat.mm),
            pw.Text(
              [
                if (lote.proveedor != null && lote.proveedor!.isNotEmpty)
                  'Proveedor: ${lote.proveedor}',
                if (lote.origen != null && lote.origen!.isNotEmpty)
                  'Origen: ${lote.origen}',
                'Recibido: ${_fecha(lote.fechaRecepcion)}',
              ].join('  ·  '),
              style: fuentes.style(fontSize: 9, color: _gris),
            ),
          ],
          pw.SizedBox(height: 5 * PdfPageFormat.mm),
          _seccion(fuentes, 'Resumen'),
          _tablaResumen(fuentes, stats),
          pw.SizedBox(height: 5 * PdfPageFormat.mm),
          _seccion(fuentes, 'Celda por celda'),
          _tablaCeldas(fuentes, celdas, lotesById),
          pw.SizedBox(height: 4 * PdfPageFormat.mm),
          pw.Text(
            'Clasificación aplicada: A ≥ ${_num(thresholds.aMin)} % · '
            'B ≥ ${_num(thresholds.bMin)} % · C ≥ ${_num(thresholds.cMin)} % · '
            'por debajo, rechazo.',
            style: fuentes.style(fontSize: 7.5, color: _gris),
          ),
          pw.SizedBox(height: 8 * PdfPageFormat.mm),
          _firma(fuentes, operador: operador),
        ],
      ),
    );

    return doc.save();
  }

  // ---------- Piezas compartidas ----------

  /// Carga el logo del informe.
  ///
  /// Si el taller tiene su propio logo (versión Pro) se usa ese; si no, el
  /// logo de CeldaPro. Devuelve null solo si no se puede leer ninguno: en ese
  /// caso el informe sale igual, con el nombre escrito.
  Future<pw.MemoryImage?> _logo(String? logoPath) async {
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final f = File(logoPath);
        if (await f.exists()) return pw.MemoryImage(await f.readAsBytes());
      } catch (_) {
        // Se cae al logo de CeldaPro: un logo ilegible no debe impedir
        // entregarle el informe al cliente.
      }
    }
    try {
      final data = await _assetPng('assets/images/logo-lockup.png');
      return pw.MemoryImage(data);
    } catch (_) {
      return null;
    }
  }

  pw.Widget _encabezado(
    PdfFonts fuentes,
    pw.MemoryImage? logo,
    String titulo,
    String? nombreTaller,
  ) {
    final taller = (nombreTaller ?? '').trim();
    final hayTaller = taller.isNotEmpty;

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Expanded(
                flex: 3,
                child: pw.Image(logo, height: 11 * PdfPageFormat.mm,
                    alignment: pw.Alignment.centerLeft),
              )
            else
              pw.Expanded(
                flex: 3,
                child: pw.Text(hayTaller ? taller : 'CeldaPro',
                    style: fuentes.style(fontSize: 16, bold: true, color: _verde)),
              ),
            pw.Expanded(
              flex: 4,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(titulo,
                      style: fuentes.style(fontSize: 12, bold: true)),
                  // El nombre del taller es opcional (versión Pro): sin él el
                  // informe sale igual, solo con la marca de CeldaPro.
                  if (hayTaller && logo != null)
                    pw.Text(taller,
                        style: fuentes.style(fontSize: 9, bold: true)),
                  pw.Text('Generado el ${_fecha(DateTime.now())}',
                      style: fuentes.style(fontSize: 8, color: _gris)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2 * PdfPageFormat.mm),
        pw.Container(height: 1.2, color: _verde),
        pw.SizedBox(height: 5 * PdfPageFormat.mm),
      ],
    );
  }

  pw.Widget _pie(PdfFonts fuentes, pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 4 * PdfPageFormat.mm),
        padding: const pw.EdgeInsets.only(top: 2 * PdfPageFormat.mm),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _grisClaro, width: 1)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('CeldaPro — gestión de restauración de celdas',
                style: fuentes.style(fontSize: 7, color: _gris)),
            pw.Text('Generado con CeldaPro · Página ${ctx.pageNumber} de '
                '${ctx.pagesCount}',
                style: fuentes.style(fontSize: 7, color: _gris)),
          ],
        ),
      );

  pw.Widget _tituloCelda(PdfFonts fuentes, Celda celda, Lote? lote) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(celda.codigoInterno,
                    style: fuentes.style(fontSize: 20, bold: true)),
                if (celda.marca != null || celda.modelo != null)
                  pw.Text(
                    [celda.marca, celda.modelo].whereType<String>().join(' '),
                    style: fuentes.style(fontSize: 10, color: _gris),
                  ),
              ],
            ),
          ),
          if (celda.veredicto != null) _insignia(fuentes, celda.veredicto!),
        ],
      );

  /// Etiqueta de color con el veredicto (A/B/C/Rechazo).
  pw.Widget _insignia(PdfFonts fuentes, Verdict v) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: pw.BoxDecoration(
          color: _colorVeredicto(v),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(
          v.code,
          style: fuentes.style(fontSize: 13, bold: true, color: PdfColors.white),
        ),
      );

  pw.Widget _seccion(PdfFonts fuentes, String titulo) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 1.5 * PdfPageFormat.mm),
        child: pw.Text(titulo,
            style: fuentes.style(fontSize: 11, bold: true, color: _verde)),
      );

  /// Tabla de dos columnas (campo / valor) para las fichas.
  pw.Widget _tablaDatos(PdfFonts fuentes, List<List<String>> filas) =>
      pw.Table(
        border: pw.TableBorder.all(color: _grisClaro, width: 0.6),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(4),
        },
        children: [
          for (final f in filas)
            pw.TableRow(children: [
              pw.Container(
                color: _grisClaro,
                padding: const pw.EdgeInsets.all(3.5),
                child: pw.Text(f[0],
                    style: fuentes.style(fontSize: 8, bold: true)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(3.5),
                child: pw.Text(f[1], style: fuentes.style(fontSize: 8.5)),
              ),
            ]),
        ],
      );

  pw.Widget _tablaHistorial(PdfFonts fuentes, List<CellTest> tests) =>
      pw.TableHelper.fromTextArray(
        headers: const [
          'Fecha',
          'Capacidad',
          'SoH',
          'Veredicto',
          'Voltaje',
          'RI',
          'Ciclos',
        ],
        data: [
          for (final t in tests.reversed)
            [
              _fecha(t.fecha),
              formatMah(t.capacidadMedidaMah ?? 0),
              formatSoh(t.sohPct),
              t.veredicto?.code ?? '—',
              _voltaje(t.voltajeV),
              t.resistenciaInternaMohm == null
                  ? '—'
                  : '${_num(t.resistenciaInternaMohm!)} mΩ',
              t.ciclos?.toString() ?? '—',
            ],
        ],
        headerStyle: fuentes.style(fontSize: 8, bold: true, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: _verde),
        cellStyle: fuentes.style(fontSize: 8),
        cellPadding: const pw.EdgeInsets.all(3),
        border: pw.TableBorder.all(color: _grisClaro, width: 0.6),
      );

  pw.Widget _tablaEventos(PdfFonts fuentes, List<CellEvent> eventos) =>
      pw.TableHelper.fromTextArray(
        headers: const ['Fecha', 'Evento', 'Detalle'],
        data: [
          for (final e in eventos.reversed)
            [
              _fechaHora(e.fecha),
              e.tipo.label,
              e.nota ?? _estadoCambio(e),
            ],
        ],
        headerStyle: fuentes.style(fontSize: 8, bold: true, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: _verde),
        cellStyle: fuentes.style(fontSize: 8),
        cellPadding: const pw.EdgeInsets.all(3),
        columnWidths: const {
          0: pw.FlexColumnWidth(2.2),
          1: pw.FlexColumnWidth(2.4),
          2: pw.FlexColumnWidth(5),
        },
        border: pw.TableBorder.all(color: _grisClaro, width: 0.6),
      );

  pw.Widget _tablaResumen(PdfFonts fuentes, CellStats s) =>
      pw.TableHelper.fromTextArray(
        headers: const ['Concepto', 'Valor'],
        data: [
          ['Celdas en total', '${s.total}'],
          ['Clasificadas', '${s.clasificadas} (${_num(s.avancePct)} %)'],
          ['Sin clasificar', '${s.sinClasificar}'],
          ['Aptas para reutilizar', '${s.aptas}'],
          ['A — Excelente', '${s.de(Verdict.a)}'],
          ['B — Buena', '${s.de(Verdict.b)}'],
          ['C — Aceptable', '${s.de(Verdict.c)}'],
          ['Rechazadas', '${s.de(Verdict.reject)} (${_num(s.rechazoPct)} %)'],
          ['SoH medio', formatSoh(s.avgSoh)],
          [
            'SoH mínimo / máximo',
            s.minSoh == null
                ? '—'
                : '${formatSoh(s.minSoh)} / ${formatSoh(s.maxSoh)}',
          ],
          ['Capacidad nominal sumada', formatMah(s.capacidadNominalMah)],
          [
            'Capacidad aprovechable',
            '${formatMah(s.capacidadAprovechableMah)}'
                '${s.capacidadNominalMah > 0 ? ' (${_num(s.capacidadAprovechableMah / s.capacidadNominalMah * 100)} % de la nominal)' : ''}',
          ],
          ['Con foto de evidencia', '${s.conFoto}'],
        ],
        headerStyle: fuentes.style(fontSize: 8, bold: true, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: _verde),
        cellStyle: fuentes.style(fontSize: 8.5),
        cellPadding: const pw.EdgeInsets.all(3.2),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(3),
        },
        border: pw.TableBorder.all(color: _grisClaro, width: 0.6),
      );

  pw.Widget _tablaCeldas(
    PdfFonts fuentes,
    List<Celda> celdas,
    Map<int, Lote> lotesById,
  ) =>
      pw.TableHelper.fromTextArray(
        headers: const ['Código', 'Marca / modelo', 'Capacidad', 'SoH', 'V.', 'Estado'],
        data: [
          for (final c in celdas)
            [
              c.codigoInterno,
              [c.marca, c.modelo].whereType<String>().join(' '),
              formatMah(c.capacidadNominalMah ?? 0),
              formatSoh(c.sohPct),
              c.veredicto?.code ?? '—',
              c.estado.label,
            ],
        ],
        headerStyle: fuentes.style(fontSize: 8, bold: true, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: _verde),
        cellStyle: fuentes.style(fontSize: 7.5),
        cellPadding: const pw.EdgeInsets.all(3),
        columnWidths: const {
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(3.2),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(1),
          4: pw.FlexColumnWidth(0.7),
          5: pw.FlexColumnWidth(1.8),
        },
        border: pw.TableBorder.all(color: _grisClaro, width: 0.6),
      );

  /// Línea de firma para entregar el informe al cliente.
  pw.Widget _firma(PdfFonts fuentes, {String? operador}) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(height: 0.8, color: _gris),
                pw.SizedBox(height: 1 * PdfPageFormat.mm),
                pw.Text('Técnico responsable',
                    style: fuentes.style(fontSize: 7.5, color: _gris)),
                if (operador != null && operador.isNotEmpty)
                  pw.Text(operador, style: fuentes.style(fontSize: 8.5)),
              ],
            ),
          ),
          pw.SizedBox(width: 12 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(height: 0.8, color: _gris),
                pw.SizedBox(height: 1 * PdfPageFormat.mm),
                pw.Text('Recibido conforme',
                    style: fuentes.style(fontSize: 7.5, color: _gris)),
              ],
            ),
          ),
        ],
      );

  // ---------- Auxiliares ----------

  PdfColor _colorVeredicto(Verdict v) => switch (v) {
        Verdict.a => _verde,
        Verdict.b => PdfColor.fromHex('#1565C0'),
        Verdict.c => _ambar,
        Verdict.reject => _rojo,
      };

  String _veredictoTexto(Verdict? v) {
    if (v == null) return 'Sin clasificar';
    final nombre = v.isRejected ? 'Rechazada' : '${v.code} — ${v.label}';
    return nombre;
  }

  String _estadoCambio(CellEvent e) {
    if (e.estadoNuevo == null) return '—';
    final desde = e.estadoAnterior == null ? '' : '${_nombreEstado(e.estadoAnterior!)} → ';
    return '$desde${_nombreEstado(e.estadoNuevo!)}';
  }

  String _nombreEstado(String name) => CellState.fromName(name).label;

  String _fecha(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  String _fechaHora(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  String _voltaje(double? v) => v == null ? '—' : '${_num(v)} V';

  String _num(double d) {
    final redondeado = (d * 100).round() / 100;
    return redondeado == redondeado.roundToDouble()
        ? redondeado.toInt().toString()
        : redondeado.toStringAsFixed(2).replaceAll('.', ',');
  }

  static Future<Uint8List> _assetPng(String ruta) async {
    // Los assets van empaquetados dentro del APK: se leen del bundle, no del
    // sistema de archivos.
    final data = await rootBundle.load(ruta);
    return data.buffer.asUint8List();
  }
}
