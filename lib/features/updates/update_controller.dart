import 'package:flutter/material.dart';

import '../../data/preferences_store.dart';
import '../../services/update_service.dart';
import 'update_dialog.dart';

/// Orquesta la revisión de actualizaciones: decide cuándo avisar (una vez por
/// versión) y expone el [navigatorKey] global para poder abrir el diálogo
/// aunque la UI todavía no esté montada.
class UpdateController {
  UpdateController._();
  static final instance = UpdateController._();

  /// Navigator global (lo registra `CeldaProApp`) para abrir el diálogo de
  /// actualización sin depender de la pantalla en la que esté el usuario.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Mínimo entre revisiones en red (evita golpear la API de GitHub en cada
  /// "resume"). El arranque en frío siempre corre la primera.
  static const _throttle = Duration(minutes: 3);

  DateTime? _ultimaVerificacion;
  UpdateInfo? _pendiente;

  /// Última versión conocida como disponible (null si no hay ninguna).
  UpdateInfo? get pendiente => _pendiente;

  /// Revisa si hay actualización y, si la hay y no se avisó ya de esa versión,
  /// muestra el diálogo.
  ///
  /// [avisarSiempre] lo usa el botón "Buscar actualizaciones" de Ajustes: ahí
  /// el usuario lo pidió a propósito, así que se ignora el throttle y el
  /// registro de "ya avisada".
  Future<UpdateInfo?> verificar({bool avisarSiempre = false}) async {
    final ahora = DateTime.now();
    if (!avisarSiempre &&
        _ultimaVerificacion != null &&
        ahora.difference(_ultimaVerificacion!) < _throttle) {
      // Revisión muy reciente: devuelve lo ya conocido sin golpear la red.
      return _pendiente;
    }
    _ultimaVerificacion = ahora;

    final info = await UpdateService.instance.verificar();
    if (info == null) {
      _pendiente = null;
      return null;
    }
    _pendiente = info;

    var esNueva = true;
    try {
      final prefs = PreferencesStore();
      final ultima = await prefs.loadUpdateAvisada();
      esNueva = ultima != info.version;
      if (esNueva) await prefs.saveUpdateAvisada(info.version);
    } catch (_) {
      // Si las preferencias fallan, se avisa igual: es mejor avisar de más
      // que dejar al taller sin enterarse de una versión nueva.
    }

    if (avisarSiempre || esNueva) _mostrarDialogo(info);
    return info;
  }

  void _mostrarDialogo(UpdateInfo info) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    Navigator.of(context, rootNavigator: true).push(
      DialogRoute<void>(
        context: context,
        builder: (_) => UpdateDialog(
          key: ValueKey('update-${info.tag}'),
          info: info,
        ),
      ),
    );
  }
}
