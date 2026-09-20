/// Tipo de foto de evidencia de una celda.
enum PhotoTag {
  evidence('Evidencia', 'Foto general'),
  before('Antes', 'Estado en que llegó la celda'),
  after('Después', 'Tras la restauración'),
  failure('Fallo', 'Daño o defecto encontrado'),
  other('Otra', 'Otro tipo de foto');

  const PhotoTag(this.label, this.description);

  final String label;
  final String description;

  static PhotoTag fromName(String? name) => PhotoTag.values.firstWhere(
        (t) => t.name == name,
        orElse: () => PhotoTag.evidence,
      );
}

/// Foto de evidencia de una celda.
///
/// Una celda puede tener varias (cómo llegó, cómo quedó, un fallo concreto):
/// la primera foto histórica vivía en `celdas.foto_path`, que se conserva como
/// **portada** para las etiquetas, los informes y las listas.
class CeldaFoto {
  const CeldaFoto({
    this.id,
    required this.celdaId,
    required this.path,
    this.etiqueta = PhotoTag.evidence,
    required this.fecha,
    this.nota,
  });

  final int? id;
  final int celdaId;

  /// Ruta local del archivo (dentro de la carpeta de fotos de la app).
  final String path;
  final PhotoTag etiqueta;
  final DateTime fecha;
  final String? nota;

  CeldaFoto copyWith({
    int? id,
    int? celdaId,
    String? path,
    PhotoTag? etiqueta,
    DateTime? fecha,
    String? nota,
  }) =>
      CeldaFoto(
        id: id ?? this.id,
        celdaId: celdaId ?? this.celdaId,
        path: path ?? this.path,
        etiqueta: etiqueta ?? this.etiqueta,
        fecha: fecha ?? this.fecha,
        nota: nota ?? this.nota,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'celda_id': celdaId,
        'path': path,
        'etiqueta': etiqueta.name,
        'fecha': fecha.millisecondsSinceEpoch,
        'nota': nota,
      };

  factory CeldaFoto.fromMap(Map<String, Object?> m) => CeldaFoto(
        id: m['id'] as int?,
        celdaId: (m['celda_id'] as int?) ?? 0,
        path: m['path'] as String? ?? '',
        etiqueta: PhotoTag.fromName(m['etiqueta'] as String?),
        fecha: DateTime.fromMillisecondsSinceEpoch(
          (m['fecha'] as int?) ?? 0,
        ),
        nota: m['nota'] as String?,
      );
}
