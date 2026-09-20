import '../data/models/celda.dart';

/// Cola de trabajo para registrar mediciones seguidas.
///
/// Es lógica pura (sin Flutter ni base de datos) para poder probarla directo:
/// recuerda por qué celda va el técnico, cuáles ya guardó y cuáles saltó.
class BatchSession {
  BatchSession(this.celdas);

  /// Celdas a recorrer, en el orden en que se van a mostrar.
  final List<Celda> celdas;

  int _index = 0;
  final List<Celda> _guardadas = [];
  final List<Celda> _saltadas = [];

  /// Celdas que todavía no tienen medición (SoH sin calcular).
  ///
  /// Es el criterio de "pendiente": una celda ya medida no vuelve a aparecer,
  /// así que reabrir la sesión continúa donde se quedó en vez de repetir.
  static List<Celda> pendientesDe(Iterable<Celda> todas) {
    final lista = todas.where((c) => c.sohPct == null).toList();
    lista.sort((a, b) => a.codigoInterno.compareTo(b.codigoInterno));
    return lista;
  }

  int get total => celdas.length;
  int get index => _index;
  int get guardadas => _guardadas.length;
  int get saltadas => _saltadas.length;
  int get hechas => _index;
  int get restantes => total - _index;

  bool get terminado => _index >= celdas.length;
  bool get vacio => celdas.isEmpty;

  /// Celda que toca ahora, o null si ya se terminó.
  Celda? get actual => terminado ? null : celdas[_index];

  /// De 0 a 1, para la barra de progreso.
  double get progreso => vacio ? 1 : _index / celdas.length;

  /// Celdas sin capacidad nominal: se les puede tomar la medida, pero no
  /// habrá SoH ni veredicto que calcular.
  List<Celda> get sinNominal =>
      celdas.where((c) => c.capacidadNominalMah == null).toList();

  List<Celda> get guardadasLista => List.unmodifiable(_guardadas);
  List<Celda> get saltadasLista => List.unmodifiable(_saltadas);

  /// Da la celda actual por registrada y avanza.
  void siguiente() => _avanzar(a: _guardadas);

  /// Deja la celda actual sin medir y avanza.
  void saltar() => _avanzar(a: _saltadas);

  /// Retrocede a la celda anterior, sin borrar lo ya guardado.
  ///
  /// Solo tiene sentido mientras queden celdas por delante: si ya se registró
  /// esa celda, volver a guardarla añadiría una segunda medición.
  void anterior() {
    if (_index > 0) _index--;
  }

  void _avanzar({required List<Celda> a}) {
    if (terminado) return;
    a.add(celdas[_index]);
    _index++;
  }

  /// Resumen para el cierre de la sesión.
  String get resumen {
    final partes = <String>['$guardadas de $total registradas'];
    if (saltadas > 0) partes.add('$saltadas sin medir');
    return partes.join(' · ');
  }
}
