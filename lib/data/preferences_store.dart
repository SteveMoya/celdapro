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
}
