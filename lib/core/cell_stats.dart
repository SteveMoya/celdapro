import '../data/models/celda.dart';
import 'classification.dart';

/// Resumen numérico de un conjunto de celdas.
///
/// Es lógica pura (sin base de datos ni PDF) para poder probarla directamente
/// y para que los informes y el resumen de la app cuenten siempre lo mismo.
class CellStats {
  const CellStats({
    required this.total,
    required this.byVerdict,
    required this.byEstado,
    required this.clasificadas,
    required this.sinClasificar,
    required this.avgSoh,
    required this.minSoh,
    required this.maxSoh,
    required this.capacidadNominalMah,
    required this.capacidadAprovechableMah,
    required this.conFoto,
  });

  final int total;

  /// Cuántas celdas hay en cada veredicto (solo las clasificadas).
  final Map<Verdict, int> byVerdict;

  /// Cuántas celdas hay en cada estado del proceso.
  final Map<CellState, int> byEstado;

  /// Celdas con veredicto asignado.
  final int clasificadas;

  /// Celdas sin veredicto todavía (recepcionadas o en test).
  final int sinClasificar;

  /// SoH medio de las celdas clasificadas (null si no hay ninguna).
  final double? avgSoh;
  final double? minSoh;
  final double? maxSoh;

  /// Suma de la capacidad nominal de todas las celdas.
  final double capacidadNominalMah;

  /// Capacidad realmente aprovechable: suma de nominal × SoH de las celdas
  /// clasificadas y no rechazadas. Es el número que dice cuánta energía se
  /// recuperó de verdad del lote.
  final double capacidadAprovechableMah;

  /// Celdas con foto de evidencia.
  final int conFoto;

  /// Porcentaje de rechazo sobre las celdas clasificadas (0 si no hay ninguna).
  double get rechazoPct {
    if (clasificadas == 0) return 0;
    return ((byVerdict[Verdict.reject] ?? 0) / clasificadas) * 100;
  }

  /// Porcentaje del lote que ya está clasificado.
  double get avancePct => total == 0 ? 0 : (clasificadas / total) * 100;

  /// Cuántas celdas hay con un veredicto concreto.
  int de(Verdict v) => byVerdict[v] ?? 0;

  /// Cuántas celdas hay en un estado concreto.
  int en(CellState e) => byEstado[e] ?? 0;

  /// Celdas aptas para reutilizar (A, B o C).
  int get aptas => clasificadas - de(Verdict.reject);

  /// Calcula el resumen de una lista de celdas.
  static CellStats from(List<Celda> celdas) {
    var clasificadas = 0;
    var nominal = 0.0;
    var aprovechable = 0.0;
    var conFoto = 0;
    var sumaSoh = 0.0;
    double? minSoh;
    double? maxSoh;

    final byVerdict = <Verdict, int>{};
    final byEstado = <CellState, int>{};

    for (final c in celdas) {
      byEstado[c.estado] = (byEstado[c.estado] ?? 0) + 1;
      if (c.fotoPath != null && c.fotoPath!.isNotEmpty) conFoto++;

      final nominalCelda = c.capacidadNominalMah ?? 0;
      nominal += nominalCelda;

      final soh = c.sohPct;
      if (c.veredicto == null || soh == null) continue;

      clasificadas++;
      byVerdict[c.veredicto!] = (byVerdict[c.veredicto!] ?? 0) + 1;
      sumaSoh += soh;
      minSoh = minSoh == null ? soh : (soh < minSoh ? soh : minSoh);
      maxSoh = maxSoh == null ? soh : (soh > maxSoh ? soh : maxSoh);

      // Una celda rechazada no aporta capacidad aprovechable.
      if (!c.veredicto!.isRejected) {
        aprovechable += nominalCelda * (soh / 100);
      }
    }

    return CellStats(
      total: celdas.length,
      byVerdict: byVerdict,
      byEstado: byEstado,
      clasificadas: clasificadas,
      sinClasificar: celdas.length - clasificadas,
      avgSoh: clasificadas == 0 ? null : sumaSoh / clasificadas,
      minSoh: minSoh,
      maxSoh: maxSoh,
      capacidadNominalMah: nominal,
      capacidadAprovechableMah: aprovechable,
      conFoto: conFoto,
    );
  }
}

/// Formatea una capacidad en mAh o Ah según el tamaño (para informes y pantalla).
String formatMah(double mah, {String vacio = '—'}) {
  if (mah <= 0) return vacio;
  if (mah >= 1000) return '${(mah / 1000).toStringAsFixed(2)} Ah';
  return '${mah.round()} mAh';
}
