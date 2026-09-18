import '../../core/classification.dart';

/// Etapa del proceso de restauración en la que está una celda.
enum CellState {
  received('Recepcionada', 'Recibida del lote, sin testear'),
  testing('En test', 'En proceso de medición'),
  classified('Clasificada', 'Con veredicto asignado'),
  balanced('Balanceada', 'Voltaje igualado con el resto del pack'),
  repacked('Reempacada', 'Montada en un pack'),
  qaPassed('Aprobada QA', 'Superó el control de calidad final'),
  rejected('Rechazada', 'Descartada (no apta)');

  const CellState(this.label, this.description);

  final String label;
  final String description;

  static CellState fromName(String? name) => CellState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => CellState.received,
      );

  /// Estados considerados "activos" para métricas de avance.
  bool get isFinal => this == qaPassed || this == rejected;
}

/// Química de la celda.
enum Chemistry {
  liIon('Li-ion'),
  lfp('LiFePO4 (LFP)'),
  lto('LTO'),
  nimh('NiMH'),
  other('Otra');

  const Chemistry(this.label);
  final String label;

  static Chemistry fromName(String? name) => Chemistry.values.firstWhere(
        (c) => c.name == name,
        orElse: () => Chemistry.other,
      );
}

/// Celda individual en el taller.
class Celda {
  const Celda({
    this.id,
    this.loteId,
    required this.codigoInterno,
    this.qr,
    this.marca,
    this.modelo,
    this.quimica = Chemistry.liIon,
    this.capacidadNominalMah,
    this.voltajeNominal,
    this.fechaFabricacion,
    this.estado = CellState.received,
    this.veredicto,
    this.sohPct,
    this.ubicacion,
    this.fotoPath,
    this.notas,
    this.catalogRef,
    this.irNominalMohm,
    required this.createdAt,
  });

  final int? id;
  final int? loteId;

  /// Código interno único (etiqueta física de la celda).
  final String codigoInterno;
  final String? qr;
  final String? marca;
  final String? modelo;
  final Chemistry quimica;
  final double? capacidadNominalMah;
  final double? voltajeNominal;
  final DateTime? fechaFabricacion;
  final CellState estado;
  final Verdict? veredicto;
  final double? sohPct;
  final String? ubicacion;
  final String? fotoPath;
  final String? notas;

  /// Nombre del modelo en el catálogo de referencia (battery-tool), si se eligió.
  final String? catalogRef;

  /// Resistencia interna de fábrica (mΩ) — referencia para diagnosticar.
  final double? irNominalMohm;

  final DateTime createdAt;

  Celda copyWith({
    int? id,
    int? loteId,
    String? codigoInterno,
    String? qr,
    String? marca,
    String? modelo,
    Chemistry? quimica,
    double? capacidadNominalMah,
    double? voltajeNominal,
    DateTime? fechaFabricacion,
    CellState? estado,
    Verdict? veredicto,
    double? sohPct,
    String? ubicacion,
    String? fotoPath,
    String? notas,
    String? catalogRef,
    double? irNominalMohm,
    DateTime? createdAt,
  }) =>
      Celda(
        id: id ?? this.id,
        loteId: loteId ?? this.loteId,
        codigoInterno: codigoInterno ?? this.codigoInterno,
        qr: qr ?? this.qr,
        marca: marca ?? this.marca,
        modelo: modelo ?? this.modelo,
        quimica: quimica ?? this.quimica,
        capacidadNominalMah: capacidadNominalMah ?? this.capacidadNominalMah,
        voltajeNominal: voltajeNominal ?? this.voltajeNominal,
        fechaFabricacion: fechaFabricacion ?? this.fechaFabricacion,
        estado: estado ?? this.estado,
        veredicto: veredicto ?? this.veredicto,
        sohPct: sohPct ?? this.sohPct,
        ubicacion: ubicacion ?? this.ubicacion,
        fotoPath: fotoPath ?? this.fotoPath,
        notas: notas ?? this.notas,
        catalogRef: catalogRef ?? this.catalogRef,
        irNominalMohm: irNominalMohm ?? this.irNominalMohm,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'lote_id': loteId,
        'codigo_interno': codigoInterno,
        'qr': qr,
        'marca': marca,
        'modelo': modelo,
        'quimica': quimica.name,
        'capacidad_nominal_mah': capacidadNominalMah,
        'voltaje_nominal': voltajeNominal,
        'fecha_fabricacion': fechaFabricacion?.millisecondsSinceEpoch,
        'estado': estado.name,
        'veredicto': veredicto?.name,
        'soh_pct': sohPct,
        'ubicacion': ubicacion,
        'foto_path': fotoPath,
        'notas': notas,
        'catalog_ref': catalogRef,
        'ir_nominal_mohm': irNominalMohm,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Celda.fromMap(Map<String, Object?> m) => Celda(
        id: m['id'] as int?,
        loteId: m['lote_id'] as int?,
        codigoInterno: m['codigo_interno'] as String? ?? '',
        qr: m['qr'] as String?,
        marca: m['marca'] as String?,
        modelo: m['modelo'] as String?,
        quimica: Chemistry.fromName(m['quimica'] as String?),
        capacidadNominalMah: (m['capacidad_nominal_mah'] as num?)?.toDouble(),
        voltajeNominal: (m['voltaje_nominal'] as num?)?.toDouble(),
        fechaFabricacion: m['fecha_fabricacion'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['fecha_fabricacion'] as int),
        estado: CellState.fromName(m['estado'] as String?),
        veredicto: m['veredicto'] == null
            ? null
            : Verdict.fromName(m['veredicto'] as String?),
        sohPct: (m['soh_pct'] as num?)?.toDouble(),
        ubicacion: m['ubicacion'] as String?,
        fotoPath: m['foto_path'] as String?,
        notas: m['notas'] as String?,
        catalogRef: m['catalog_ref'] as String?,
        irNominalMohm: (m['ir_nominal_mohm'] as num?)?.toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (m['created_at'] as int?) ?? 0,
        ),
      );
}
