import '../../core/classification.dart';

/// Medición/test realizado a una celda.
class CellTest {
  const CellTest({
    this.id,
    required this.celdaId,
    required this.fecha,
    this.voltajeV,
    this.capacidadMedidaMah,
    this.resistenciaInternaMohm,
    this.ciclos,
    this.corrienteDescargaA,
    this.temperaturaC,
    this.sohPct,
    this.veredicto,
    this.operador,
    this.notas,
  });

  final int? id;
  final int celdaId;
  final DateTime fecha;
  final double? voltajeV;
  final double? capacidadMedidaMah;
  final double? resistenciaInternaMohm;
  final int? ciclos;
  final double? corrienteDescargaA;
  final double? temperaturaC;

  /// SoH calculado al momento del test (se guarda para histórico).
  final double? sohPct;
  final Verdict? veredicto;
  final String? operador;
  final String? notas;

  CellTest copyWith({
    int? id,
    int? celdaId,
    DateTime? fecha,
    double? voltajeV,
    double? capacidadMedidaMah,
    double? resistenciaInternaMohm,
    int? ciclos,
    double? corrienteDescargaA,
    double? temperaturaC,
    double? sohPct,
    Verdict? veredicto,
    String? operador,
    String? notas,
  }) =>
      CellTest(
        id: id ?? this.id,
        celdaId: celdaId ?? this.celdaId,
        fecha: fecha ?? this.fecha,
        voltajeV: voltajeV ?? this.voltajeV,
        capacidadMedidaMah: capacidadMedidaMah ?? this.capacidadMedidaMah,
        resistenciaInternaMohm:
            resistenciaInternaMohm ?? this.resistenciaInternaMohm,
        ciclos: ciclos ?? this.ciclos,
        corrienteDescargaA: corrienteDescargaA ?? this.corrienteDescargaA,
        temperaturaC: temperaturaC ?? this.temperaturaC,
        sohPct: sohPct ?? this.sohPct,
        veredicto: veredicto ?? this.veredicto,
        operador: operador ?? this.operador,
        notas: notas ?? this.notas,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'celda_id': celdaId,
        'fecha': fecha.millisecondsSinceEpoch,
        'voltaje_v': voltajeV,
        'capacidad_medida_mah': capacidadMedidaMah,
        'resistencia_interna_mohm': resistenciaInternaMohm,
        'ciclos': ciclos,
        'corriente_descarga_a': corrienteDescargaA,
        'temperatura_c': temperaturaC,
        'soh_pct': sohPct,
        'veredicto': veredicto?.name,
        'operador': operador,
        'notas': notas,
      };

  factory CellTest.fromMap(Map<String, Object?> m) => CellTest(
        id: m['id'] as int?,
        celdaId: (m['celda_id'] as int?) ?? 0,
        fecha: DateTime.fromMillisecondsSinceEpoch((m['fecha'] as int?) ?? 0),
        voltajeV: (m['voltaje_v'] as num?)?.toDouble(),
        capacidadMedidaMah: (m['capacidad_medida_mah'] as num?)?.toDouble(),
        resistenciaInternaMohm:
            (m['resistencia_interna_mohm'] as num?)?.toDouble(),
        ciclos: m['ciclos'] as int?,
        corrienteDescargaA: (m['corriente_descarga_a'] as num?)?.toDouble(),
        temperaturaC: (m['temperatura_c'] as num?)?.toDouble(),
        sohPct: (m['soh_pct'] as num?)?.toDouble(),
        veredicto: m['veredicto'] == null
            ? null
            : Verdict.fromName(m['veredicto'] as String?),
        operador: m['operador'] as String?,
        notas: m['notas'] as String?,
      );
}
