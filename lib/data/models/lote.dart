/// Lote de celdas recibido (agrupa celdas de un mismo origen/compra).
class Lote {
  const Lote({
    this.id,
    required this.codigo,
    this.proveedor,
    this.origen,
    required this.fechaRecepcion,
    this.notas,
  });

  final int? id;

  /// Código visible del lote (ej. "L-2026-09-A").
  final String codigo;
  final String? proveedor;
  final String? origen;
  final DateTime fechaRecepcion;
  final String? notas;

  Lote copyWith({
    int? id,
    String? codigo,
    String? proveedor,
    String? origen,
    DateTime? fechaRecepcion,
    String? notas,
  }) =>
      Lote(
        id: id ?? this.id,
        codigo: codigo ?? this.codigo,
        proveedor: proveedor ?? this.proveedor,
        origen: origen ?? this.origen,
        fechaRecepcion: fechaRecepcion ?? this.fechaRecepcion,
        notas: notas ?? this.notas,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'codigo': codigo,
        'proveedor': proveedor,
        'origen': origen,
        'fecha_recepcion': fechaRecepcion.millisecondsSinceEpoch,
        'notas': notas,
      };

  factory Lote.fromMap(Map<String, Object?> m) => Lote(
        id: m['id'] as int?,
        codigo: m['codigo'] as String? ?? '',
        proveedor: m['proveedor'] as String?,
        origen: m['origen'] as String?,
        fechaRecepcion: DateTime.fromMillisecondsSinceEpoch(
          (m['fecha_recepcion'] as int?) ?? 0,
        ),
        notas: m['notas'] as String?,
      );
}
