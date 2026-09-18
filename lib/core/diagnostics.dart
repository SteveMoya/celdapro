/// Diagnóstico de la resistencia interna medida frente a la de fábrica.
///
/// Criterio del taller (no es un estándar universal): la resistencia interna
/// sube con el desgaste, así que compararla con la del catálogo delata celdas
/// agotadas aunque su capacidad aún parezca aceptable.
library;

/// Severidad del diagnóstico.
enum IrLevel {
  ok('Normal', 'Dentro de lo esperado para el modelo'),
  high('Elevada', 'Por encima de lo esperado: posible desgaste'),
  veryHigh('Muy alta', 'Muy por encima: celda agotada o con mala conexión'),
  unknown('Sin referencia', 'No hay resistencia nominal para comparar');

  const IrLevel(this.label, this.description);

  final String label;
  final String description;

  bool get isProblem => this == IrLevel.high || this == IrLevel.veryHigh;
}

/// Resultado de comparar la resistencia medida con la nominal.
class IrAssessment {
  const IrAssessment({
    required this.level,
    this.measuredMohm,
    this.nominalMohm,
  });

  final IrLevel level;
  final double? measuredMohm;
  final double? nominalMohm;

  /// Cuántas veces supera la nominal (null si no se puede calcular).
  double? get ratio {
    final m = measuredMohm;
    final n = nominalMohm;
    if (m == null || n == null || n <= 0) return null;
    return m / n;
  }
}

/// Evalúa la resistencia interna medida contra la de referencia.
///
/// Umbrales (convención del taller, editables a futuro):
/// - hasta **1.3×** la nominal → Normal
/// - hasta **2.0×** → Elevada
/// - por encima de **2.0×** → Muy alta
IrAssessment assessInternalResistance({
  required double? measuredMohm,
  required double? nominalMohm,
}) {
  if (measuredMohm == null || nominalMohm == null || nominalMohm <= 0) {
    return IrAssessment(
      level: IrLevel.unknown,
      measuredMohm: measuredMohm,
      nominalMohm: nominalMohm,
    );
  }

  final ratio = measuredMohm / nominalMohm;
  final level = ratio <= 1.3
      ? IrLevel.ok
      : (ratio <= 2.0 ? IrLevel.high : IrLevel.veryHigh);

  return IrAssessment(
    level: level,
    measuredMohm: measuredMohm,
    nominalMohm: nominalMohm,
  );
}

/// Texto corto del diagnóstico (ej. "1.7× la nominal").
String formatIrRatio(double? ratio) =>
    ratio == null ? '—' : '${ratio.toStringAsFixed(1)}× la nominal';
