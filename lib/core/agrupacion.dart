/// Agrupación de celdas por similitud, para armar packs (lógica pura).
///
/// Un pack que mezcla una celda al 95 % con otra al 62 % se degrada por la
/// peor: la buena trabaja por las dos. Este archivo decide, con las mediciones
/// reales de cada celda, qué celdas se parecen lo suficiente para ir juntas.
///
/// **Qué compara** (siempre con la medición, no con el dato del catálogo):
/// - química: tiene que ser **idéntica**, no es negociable;
/// - capacidad medida, resistencia interna medida, SoH y voltaje actual:
///   dentro de las tolerancias que configure el taller.
///
/// **La garantía que da:** dentro de un grupo, dos celdas cualesquiera no
/// difieren más de lo que digan las tolerancias. No se compara contra una
/// «celda jefe» que podría irse desviando: cada candidata se mide **contra
/// todos los miembros** del grupo, así que el grupo entero queda apretado.
library;

import '../data/models/celda.dart';
import '../data/models/cell_test.dart';
import 'classification.dart';

/// Tolerancias de agrupación. Valores por defecto de la app, editables.
class ToleranciasAgrupacion {
  const ToleranciasAgrupacion({
    this.capacidadPct = 5.0,
    this.irPct = 10.0,
    this.sohPuntos = 5.0,
    this.voltajeV = 0.05,
  });

  /// Diferencia máxima de capacidad medida, en % de la mayor del par.
  final double capacidadPct;

  /// Diferencia máxima de resistencia interna medida, en % de la mayor.
  final double irPct;

  /// Diferencia máxima de SoH, en puntos porcentuales.
  final double sohPuntos;

  /// Diferencia máxima de voltaje, en voltios.
  final double voltajeV;

  ToleranciasAgrupacion copyWith({
    double? capacidadPct,
    double? irPct,
    double? sohPuntos,
    double? voltajeV,
  }) =>
      ToleranciasAgrupacion(
        capacidadPct: capacidadPct ?? this.capacidadPct,
        irPct: irPct ?? this.irPct,
        sohPuntos: sohPuntos ?? this.sohPuntos,
        voltajeV: voltajeV ?? this.voltajeV,
      );

  /// Deja las tolerancias en un rango sensato (nunca negativas, nunca absurdas).
  ToleranciasAgrupacion sanitized() {
    double clamp(double v, double max) => v.clamp(0, max).toDouble();
    return ToleranciasAgrupacion(
      capacidadPct: clamp(capacidadPct, 100),
      irPct: clamp(irPct, 100),
      sohPuntos: clamp(sohPuntos, 100),
      voltajeV: clamp(voltajeV, 5),
    );
  }

  Map<String, Object?> toMap() => {
        'capacidadPct': capacidadPct,
        'irPct': irPct,
        'sohPuntos': sohPuntos,
        'voltajeV': voltajeV,
      };

  /// Convierte un valor guardado a número, sin romperse si viene corrupto.
  static double? _aDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Lee las tolerancias guardadas.
  ///
  /// Tolera valores corruptos o ausentes: si algo no es un número, cae al
  /// valor por defecto en vez de reventar al abrir la pantalla. Una
  /// preferencia mal guardada no debe dejar la app inservible.
  factory ToleranciasAgrupacion.fromMap(Map<String, Object?> map) =>
      ToleranciasAgrupacion(
        capacidadPct: _aDouble(map['capacidadPct']) ?? 5.0,
        irPct: _aDouble(map['irPct']) ?? 10.0,
        sohPuntos: _aDouble(map['sohPuntos']) ?? 5.0,
        voltajeV: _aDouble(map['voltajeV']) ?? 0.05,
      ).sanitized();

  @override
  bool operator ==(Object other) =>
      other is ToleranciasAgrupacion &&
      other.capacidadPct == capacidadPct &&
      other.irPct == irPct &&
      other.sohPuntos == sohPuntos &&
      other.voltajeV == voltajeV;

  @override
  int get hashCode =>
      Object.hash(capacidadPct, irPct, sohPuntos, voltajeV);
}

/// Por qué una celda no entró en ningún grupo.
///
/// La pantalla lo muestra: decir «esta celda queda fuera» sin explicar por qué
/// hace que el operador no se fíe de la agrupación.
enum MotivoExclusion {
  sinMedicion('Sin medición', 'Nunca se le hizo un test'),
  sinCapacidad('Sin capacidad medida', 'El test no tiene capacidad'),
  sinSoh('Sin SoH', 'No se pudo calcular el SoH'),
  rechazada('Rechazada', 'Su veredicto es Rechazo'),
  descartada('Descartada', 'La celda está marcada como descartada'),
  yaEmpacada('Ya está en un pack', 'No conviene sacarla de su pack');

  const MotivoExclusion(this.label, this.description);

  final String label;
  final String description;
}

/// Una celda junto a su última medición: lo que la agrupación necesita saber.
class CeldaMedida {
  const CeldaMedida({
    required this.celda,
    this.capacidadMah,
    this.irMohm,
    this.voltajeV,
    this.sohPct,
  });

  final Celda celda;

  /// Capacidad **medida** en el último test (no la nominal del catálogo).
  final double? capacidadMah;

  /// Resistencia interna medida en el último test.
  final double? irMohm;

  /// Voltaje medido en el último test.
  final double? voltajeV;

  /// SoH del último test.
  final double? sohPct;

  String get codigo => celda.codigoInterno;

  /// Arma la celda medida a partir de la celda y su último test.
  factory CeldaMedida.de(Celda celda, CellTest? test) {
    final soh = test?.sohPct ??
        computeSoh(
          measuredMah: test?.capacidadMedidaMah,
          nominalMah: celda.capacidadNominalMah,
        );
    return CeldaMedida(
      celda: celda,
      capacidadMah: test?.capacidadMedidaMah,
      irMohm: test?.resistenciaInternaMohm,
      voltajeV: test?.voltajeV,
      sohPct: soh,
    );
  }
}

/// Celda que quedó fuera de la agrupación, con el motivo.
class CeldaExcluida {
  const CeldaExcluida({required this.celda, required this.motivo});

  final CeldaMedida celda;
  final MotivoExclusion motivo;
}

/// Un grupo de celdas compatibles entre sí.
class GrupoCompatibles {
  const GrupoCompatibles({required this.celdas});

  final List<CeldaMedida> celdas;

  int get tamano => celdas.length;

  /// ¿Sirve para armar un pack? Un grupo de una sola celda no.
  bool get esPackeable => celdas.length >= 2;

  /// Etiqueta de la química del grupo (todas son la misma).
  String get quimica => celdas.first.celda.quimica.label;

  List<double> _valores(double? Function(CeldaMedida) leer) => celdas
      .map(leer)
      .whereType<double>()
      .toList(growable: false);

  double _media(List<double> v) =>
      v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

  /// Capacidad media medida (mAh). Null si ninguna la tiene.
  double? get capacidadMediaMah {
    final v = _valores((c) => c.capacidadMah);
    return v.isEmpty ? null : _media(v);
  }

  /// SoH medio del grupo (%).
  double? get sohMedio {
    final v = _valores((c) => c.sohPct);
    return v.isEmpty ? null : _media(v);
  }

  /// Resistencia interna media medida (mΩ).
  double? get irMediaMohm {
    final v = _valores((c) => c.irMohm);
    return v.isEmpty ? null : _media(v);
  }

  /// Voltaje medio medido (V).
  double? get voltajeMedioV {
    final v = _valores((c) => c.voltajeV);
    return v.isEmpty ? null : _media(v);
  }

  /// Cuánto se separan la mejor y la peor del grupo (puntos de SoH).
  double? get sohSpreadPuntos {
    final v = _valores((c) => c.sohPct);
    if (v.length < 2) return null;
    return v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);
  }

  /// Cuánto se separan la mayor y la menor capacidad del grupo (%).
  ///
  /// Es la cifra que de verdad importa al armar el pack: la capacidad útil del
  /// conjunto la marca la celda más débil.
  double? get capacidadSpreadPct {
    final v = _valores((c) => c.capacidadMah);
    if (v.length < 2) return null;
    final mayor = v.reduce((a, b) => a > b ? a : b);
    final menor = v.reduce((a, b) => a < b ? a : b);
    return mayor == 0 ? 0 : ((mayor - menor) / mayor) * 100;
  }

  /// Capacidad aprovechable del grupo: la de la celda más débil, por el número
  /// de celdas. Lo que el pack entregará de verdad, no una media optimista.
  double? get capacidadAprovechableMah {
    final v = _valores((c) => c.capacidadMah);
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a < b ? a : b) * v.length;
  }

  /// Avisos sobre datos incompletos del grupo, para que la pantalla los diga.
  List<String> get avisos {
    final sinIr = celdas.where((c) => c.irMohm == null).length;
    final sinVoltaje = celdas.where((c) => c.voltajeV == null).length;
    final sinCapacidad = celdas.where((c) => c.capacidadMah == null).length;
    return [
      if (sinCapacidad > 0)
        '$sinCapacidad ${sinCapacidad == 1 ? 'celda' : 'celdas'} sin capacidad medida',
      if (sinIr > 0)
        '$sinIr ${sinIr == 1 ? 'celda' : 'celdas'} sin resistencia interna medida',
      if (sinVoltaje > 0)
        '$sinVoltaje ${sinVoltaje == 1 ? 'celda' : 'celdas'} sin voltaje medido',
    ];
  }

  /// Las celdas del grupo, ordenadas por capacidad de mayor a menor.
  List<CeldaMedida> get celdasOrdenadas {
    final copia = [...celdas];
    copia.sort((a, b) {
      final ca = a.capacidadMah ?? 0;
      final cb = b.capacidadMah ?? 0;
      final porCapacidad = cb.compareTo(ca);
      if (porCapacidad != 0) return porCapacidad;
      return a.codigo.compareTo(b.codigo);
    });
    return copia;
  }
}

/// Resultado completo de agrupar un conjunto de celdas.
class ResultadoAgrupacion {
  const ResultadoAgrupacion({
    required this.grupos,
    required this.excluidas,
    required this.tolerancias,
  });

  /// Todos los grupos, incluidos los de una sola celda.
  final List<GrupoCompatibles> grupos;

  /// Celdas que no se pudieron agrupar, con el motivo.
  final List<CeldaExcluida> excluidas;

  final ToleranciasAgrupacion tolerancias;

  /// Grupos que sirven para armar un pack (dos o más celdas).
  List<GrupoCompatibles> get gruposDePack =>
      grupos.where((g) => g.esPackeable).toList(growable: false);

  /// Celdas que quedaron solas: encajan consigo mismas y con nadie más.
  List<CeldaMedida> get sinCompania => grupos
      .where((g) => !g.esPackeable)
      .expand((g) => g.celdas)
      .toList(growable: false);

  /// Cuántas celdas entraron en algún grupo de pack.
  int get celdasAgrupadas =>
      gruposDePack.fold(0, (suma, g) => suma + g.tamano);

  bool get hayAlgo => grupos.isNotEmpty || excluidas.isNotEmpty;
}

/// ¿`a` y `b` difieren menos de [tolPct] por ciento de la mayor de las dos?
///
/// Se toma la mayor como referencia a propósito: es la lectura más prudente
/// («no se llevan más del X % de la mayor»), y así el resultado no cambia
/// según en qué orden se comparen.
bool _dentroPct(double a, double b, double tolPct) {
  final mayor = a.abs() > b.abs() ? a.abs() : b.abs();
  if (mayor == 0) return true; // las dos son cero: son iguales
  return ((a - b).abs() / mayor) * 100 <= tolPct;
}

/// ¿La celda entra en el grupo? Tiene que encajar con **todos** los miembros.
///
/// Comparar contra todos (y no solo contra la primera) es lo que garantiza que
/// el grupo entero quede apretado: así la diferencia entre la mejor y la peor
/// nunca supera la tolerancia.
bool esCompatible(
  CeldaMedida candidata,
  GrupoCompatibles grupo,
  ToleranciasAgrupacion tol,
) {
  final t = tol.sanitized();
  for (final miembro in grupo.celdas) {
    if (miembro.celda.quimica != candidata.celda.quimica) return false;

    final c1 = candidata.capacidadMah;
    final c2 = miembro.capacidadMah;
    if (c1 != null && c2 != null && !_dentroPct(c1, c2, t.capacidadPct)) {
      return false;
    }

    final s1 = candidata.sohPct;
    final s2 = miembro.sohPct;
    if (s1 != null && s2 != null && (s1 - s2).abs() > t.sohPuntos) return false;

    // La resistencia y el voltaje solo se comparan si las dos celdas tienen la
    // medición: no se puede exigir parecido en un dato que falta.
    final r1 = candidata.irMohm;
    final r2 = miembro.irMohm;
    if (r1 != null && r2 != null && !_dentroPct(r1, r2, t.irPct)) return false;

    final v1 = candidata.voltajeV;
    final v2 = miembro.voltajeV;
    if (v1 != null && v2 != null && (v1 - v2).abs() > t.voltajeV) return false;
  }
  return true;
}

/// Motivo por el que una celda no puede entrar en ningún grupo, o null si sí.
MotivoExclusion? motivoPara(CeldaMedida celda) {
  final estado = celda.celda.estado;
  if (estado == CellState.rejected) return MotivoExclusion.descartada;
  if (estado == CellState.repacked) return MotivoExclusion.yaEmpacada;
  if (celda.celda.veredicto?.isRejected ?? false) {
    return MotivoExclusion.rechazada;
  }
  if (celda.capacidadMah == null) {
    // Sin medición ninguna, o con un test que no traía capacidad.
    return celda.irMohm == null && celda.voltajeV == null
        ? MotivoExclusion.sinMedicion
        : MotivoExclusion.sinCapacidad;
  }
  if (celda.sohPct == null) return MotivoExclusion.sinSoh;
  return null;
}

/// Agrupa celdas por similitud.
///
/// El resultado es **determinista**: con las mismas celdas y tolerancias sale
/// siempre lo mismo, y el orden de la lista de entrada no cambia el resultado.
List<GrupoCompatibles> agrupar({
  required List<CeldaMedida> celdas,
  ToleranciasAgrupacion tolerancias = const ToleranciasAgrupacion(),
}) {
  final libre = [...celdas];
  // Orden fijo: por capacidad de mayor a menor y, a igualdad, por código. Si no
  // se fija, el resultado dependería del orden en que llegaron las celdas.
  libre.sort((a, b) {
    final ca = a.capacidadMah ?? 0;
    final cb = b.capacidadMah ?? 0;
    final porCapacidad = cb.compareTo(ca);
    if (porCapacidad != 0) return porCapacidad;
    return a.codigo.compareTo(b.codigo);
  });

  final grupos = <GrupoCompatibles>[];

  while (libre.isNotEmpty) {
    final grupo = GrupoCompatibles(celdas: [libre.removeAt(0)]);

    for (var i = 0; i < libre.length;) {
      final candidata = libre[i];

      // Poda: `libre` está ordenada de mayor a menor capacidad y los miembros
      // del grupo tienen todos capacidad mayor que la candidata. Si la
      // candidata se queda corta de capacidad respecto al miembro más débil,
      // las siguientes —aún más pequeñas— tampoco van a encajar nunca: se
      // puede cortar aquí en vez de seguir comparando una por una.
      //
      // Es lo que hace que agrupar siga siendo rápido con miles de celdas.
      final minCap = grupo.celdas
          .map((c) => c.capacidadMah)
          .whereType<double>()
          .fold<double?>(null, (a, b) => a == null || b < a ? b : a);
      final capCandidata = candidata.capacidadMah;
      if (minCap != null &&
          capCandidata != null &&
          !_dentroPct(capCandidata, minCap, tolerancias.capacidadPct)) {
        break;
      }

      if (esCompatible(candidata, grupo, tolerancias)) {
        grupo.celdas.add(candidata);
        libre.removeAt(i);
        continue;
      }
      i++;
    }
    grupos.add(grupo);
  }

  return grupos;
}

/// Agrupa y separa lo que no se pudo agrupar, con el motivo.
///
/// Es lo que usa la app: además del resultado, devuelve por qué quedó fuera
/// cada celda que no entró, para poder explicárselo al operador.
ResultadoAgrupacion agruparConMotivos({
  required List<CeldaMedida> celdas,
  ToleranciasAgrupacion tolerancias = const ToleranciasAgrupacion(),
}) {
  final agrupables = <CeldaMedida>[];
  final excluidas = <CeldaExcluida>[];

  for (final c in celdas) {
    final motivo = motivoPara(c);
    if (motivo == null) {
      agrupables.add(c);
    } else {
      excluidas.add(CeldaExcluida(celda: c, motivo: motivo));
    }
  }

  // La química nunca se mezcla: se agrupa cada una por separado y luego se
  // juntan los resultados, ordenados para que la salida sea estable.
  final porQuimica = <Chemistry, List<CeldaMedida>>{};
  for (final c in agrupables) {
    porQuimica.putIfAbsent(c.celda.quimica, () => []).add(c);
  }

  final grupos = <GrupoCompatibles>[];
  for (final quimica in Chemistry.values) {
    final lista = porQuimica[quimica];
    if (lista == null || lista.isEmpty) continue;
    grupos.addAll(agrupar(celdas: lista, tolerancias: tolerancias));
  }

  return ResultadoAgrupacion(
    grupos: grupos,
    excluidas: excluidas,
    tolerancias: tolerancias.sanitized(),
  );
}
