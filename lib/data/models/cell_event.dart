/// Evento de trazabilidad: todo cambio relevante sobre una celda queda auditado.
enum EventType {
  created('Alta'),
  stateChanged('Cambio de estado'),
  tested('Test registrado'),
  edited('Editada'),
  note('Nota'),
  photo('Foto añadida');

  const EventType(this.label);
  final String label;

  static EventType fromName(String? name) => EventType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => EventType.note,
      );
}

/// Registro inmutable de un evento sobre una celda.
class CellEvent {
  const CellEvent({
    this.id,
    required this.celdaId,
    required this.tipo,
    this.estadoAnterior,
    this.estadoNuevo,
    required this.fecha,
    this.nota,
  });

  final int? id;
  final int celdaId;
  final EventType tipo;
  final String? estadoAnterior;
  final String? estadoNuevo;
  final DateTime fecha;
  final String? nota;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'celda_id': celdaId,
        'tipo': tipo.name,
        'estado_anterior': estadoAnterior,
        'estado_nuevo': estadoNuevo,
        'fecha': fecha.millisecondsSinceEpoch,
        'nota': nota,
      };

  factory CellEvent.fromMap(Map<String, Object?> m) => CellEvent(
        id: m['id'] as int?,
        celdaId: (m['celda_id'] as int?) ?? 0,
        tipo: EventType.fromName(m['tipo'] as String?),
        estadoAnterior: m['estado_anterior'] as String?,
        estadoNuevo: m['estado_nuevo'] as String?,
        fecha: DateTime.fromMillisecondsSinceEpoch((m['fecha'] as int?) ?? 0),
        nota: m['nota'] as String?,
      );
}
