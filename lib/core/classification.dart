/// Lógica de clasificación de celdas (pura y testeable).
///
/// El veredicto se deriva del **SoH** (State of Health): capacidad medida entre
/// capacidad nominal. Los umbrales son configurables (convención del taller).
library;

/// Veredicto de clasificación de una celda.
enum Verdict {
  a('A', 'Excelente'),
  b('B', 'Buena'),
  c('C', 'Aceptable'),
  reject('Rechazo', 'Rechazada');

  const Verdict(this.code, this.label);

  final String code;
  final String label;

  bool get isRejected => this == Verdict.reject;

  static Verdict fromName(String? name) => Verdict.values.firstWhere(
        (v) => v.name == name,
        orElse: () => Verdict.reject,
      );

  static Verdict? fromCode(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    for (final v in Verdict.values) {
      if (v.code.toUpperCase() == normalized) return v;
    }
    return Verdict.fromName(code);
  }
}

/// Umbrales de clasificación por SoH (porcentaje).
class Thresholds {
  const Thresholds({
    this.aMin = 90.0,
    this.bMin = 75.0,
    this.cMin = 60.0,
  });

  /// SoH mínimo para veredicto A.
  final double aMin;

  /// SoH mínimo para veredicto B.
  final double bMin;

  /// SoH mínimo para veredicto C (por debajo → rechazo).
  final double cMin;

  Thresholds copyWith({double? aMin, double? bMin, double? cMin}) => Thresholds(
        aMin: aMin ?? this.aMin,
        bMin: bMin ?? this.bMin,
        cMin: cMin ?? this.cMin,
      );

  /// Valida y ordena los umbrales (A ≥ B ≥ C, todos entre 0 y 100).
  Thresholds sanitized() {
    double clamp(double v) => v.clamp(0, 100).toDouble();
    final c = clamp(cMin);
    final b = clamp(bMin) < c ? c : clamp(bMin);
    final a = clamp(aMin) < b ? b : clamp(aMin);
    return Thresholds(aMin: a, bMin: b, cMin: c);
  }

  Map<String, Object?> toMap() => {'aMin': aMin, 'bMin': bMin, 'cMin': cMin};

  factory Thresholds.fromMap(Map<String, Object?> map) => Thresholds(
        aMin: (map['aMin'] as num?)?.toDouble() ?? 90.0,
        bMin: (map['bMin'] as num?)?.toDouble() ?? 75.0,
        cMin: (map['cMin'] as num?)?.toDouble() ?? 60.0,
      );

  @override
  bool operator ==(Object other) =>
      other is Thresholds &&
      other.aMin == aMin &&
      other.bMin == bMin &&
      other.cMin == cMin;

  @override
  int get hashCode => Object.hash(aMin, bMin, cMin);
}

/// Resultado del cálculo de clasificación.
class ClassificationResult {
  const ClassificationResult({this.soh, required this.verdict, this.reason});

  /// SoH en porcentaje (null si no se pudo calcular).
  final double? soh;
  final Verdict verdict;

  /// Motivo cuando no se pudo calcular automáticamente.
  final String? reason;

  bool get computed => soh != null;
}

/// Calcula el SoH (%). Devuelve null si la capacidad nominal no es válida.
double? computeSoh({
  required double? measuredMah,
  required double? nominalMah,
}) {
  if (measuredMah == null || nominalMah == null) return null;
  if (nominalMah <= 0 || measuredMah <= 0) return null;
  return (measuredMah / nominalMah) * 100;
}

/// Clasifica a partir de capacidades. Si falta algún dato o la medida es 0,
/// devuelve rechazo con motivo (una celda sin capacidad útil no sirve).
ClassificationResult classifyByCapacity({
  required double? measuredMah,
  required double? nominalMah,
  Thresholds thresholds = const Thresholds(),
}) {
  if (measuredMah != null && measuredMah <= 0) {
    return const ClassificationResult(
      verdict: Verdict.reject,
      reason: 'Capacidad medida nula (celda muerta)',
    );
  }

  final soh = computeSoh(measuredMah: measuredMah, nominalMah: nominalMah);
  if (soh == null) {
    return const ClassificationResult(
      verdict: Verdict.reject,
      reason: 'Faltan datos para calcular el SoH',
    );
  }

  return ClassificationResult(soh: soh, verdict: classifySoh(soh, thresholds));
}

/// Clasifica un SoH ya calculado contra los umbrales.
Verdict classifySoh(double soh, [Thresholds thresholds = const Thresholds()]) {
  final t = thresholds.sanitized();
  if (soh >= t.aMin) return Verdict.a;
  if (soh >= t.bMin) return Verdict.b;
  if (soh >= t.cMin) return Verdict.c;
  return Verdict.reject;
}

/// SoH formateado para mostrar (ej. "87.4 %").
String formatSoh(double? soh) =>
    soh == null ? '—' : '${soh.toStringAsFixed(1)} %';
