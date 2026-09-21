import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/classification.dart';
import 'database_helper.dart';

/// Preferencias locales de la app (umbrales, motivos de rechazo).
class PreferencesStore {
  PreferencesStore({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  static const _thresholdsKey = 'thresholds';
  static const _rejectReasonsKey = 'reject_reasons';
  static const _lastBackupKey = 'ultimo_respaldo';
  static const _tallerKey = 'nombre_taller';
  static const _licenciaKey = 'licencia_pro';
  static const _logoKey = 'logo_taller';
  static const _updateAvisadaKey = 'update_ultima_avisada';
  static const _updateAutoKey = 'update_automatico';

  static const defaultRejectReasons = <String>[
    'Capacidad baja',
    'Resistencia interna alta',
    'Voltaje fuera de rango',
    'Celda hinchada / dañada',
    'Fuga de electrolito',
    'No retiene carga',
    'Otro',
  ];

  Future<String?> _get(String key) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tablePrefs,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      DatabaseHelper.tablePrefs,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Thresholds> loadThresholds() async {
    final raw = await _get(_thresholdsKey);
    if (raw == null || raw.isEmpty) return const Thresholds();
    try {
      return Thresholds.fromMap(jsonDecode(raw) as Map<String, Object?>)
          .sanitized();
    } catch (_) {
      return const Thresholds();
    }
  }

  Future<void> saveThresholds(Thresholds thresholds) =>
      _set(_thresholdsKey, jsonEncode(thresholds.sanitized().toMap()));

  Future<List<String>> loadRejectReasons() async {
    final raw = await _get(_rejectReasonsKey);
    if (raw == null || raw.isEmpty) return defaultRejectReasons;
    try {
      final list = (jsonDecode(raw) as List).cast<String>();
      return list.isEmpty ? defaultRejectReasons : list;
    } catch (_) {
      return defaultRejectReasons;
    }
  }

  Future<void> saveRejectReasons(List<String> reasons) =>
      _set(_rejectReasonsKey, jsonEncode(reasons));

  /// Fecha del último respaldo guardado (null si nunca se ha hecho uno).
  Future<DateTime?> loadLastBackup() async {
    final raw = await _get(_lastBackupKey);
    if (raw == null || raw.isEmpty) return null;
    final ms = int.tryParse(raw);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> saveLastBackup(DateTime fecha) =>
      _set(_lastBackupKey, '${fecha.millisecondsSinceEpoch}');

  /// Nombre del taller, para las etiquetas y los informes.
  ///
  /// Solo se usa en la versión Pro: los informes salen igual sin él.
  Future<String?> loadTaller() async {
    final v = await _get(_tallerKey);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> saveTaller(String? nombre) =>
      _set(_tallerKey, (nombre ?? '').trim());

  // ---------- Versión Pro ----------

  /// Código de licencia guardado (null si nunca se activó).
  Future<String?> loadLicencia() async {
    final v = await _get(_licenciaKey);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> saveLicencia(String? codigo) =>
      _set(_licenciaKey, (codigo ?? '').trim());

  /// Ruta del logo del taller (imagen elegida por el usuario).
  Future<String?> loadLogoTaller() async {
    final v = await _get(_logoKey);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  Future<void> saveLogoTaller(String? ruta) =>
      _set(_logoKey, (ruta ?? '').trim());

  // ---------- Actualizaciones ----------

  /// Última versión sobre la que ya se avisó (para no repetir el aviso).
  Future<String?> loadUpdateAvisada() => _get(_updateAvisadaKey);

  Future<void> saveUpdateAvisada(String version) =>
      _set(_updateAvisadaKey, version);

  /// ¿Buscar actualizaciones sola al abrir la app? (por defecto, sí).
  Future<bool> loadUpdateAutomatico() async => (await _get(_updateAutoKey)) != '0';

  Future<void> saveUpdateAutomatico(bool activo) =>
      _set(_updateAutoKey, activo ? '1' : '0');
}
