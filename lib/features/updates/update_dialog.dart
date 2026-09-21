import 'package:flutter/material.dart';

import '../../services/update_service.dart';

/// Diálogo modal que informa de una versión nueva y permite descargar e
/// instalar el APK desde GitHub, mostrando el progreso en vivo.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _descargando = false;
  bool _permisoFalta = false;
  int _descargados = 0;
  int _total = 0;
  String? _error;
  String? _resultadoMensaje; // mensaje del resultado final de la instalación
  bool _resultadoExitoso = false;

  UpdateInfo get _info => widget.info;

  double get _progreso =>
      _total > 0 ? (_descargados / _total).clamp(0.0, 1.0) : 0;

  String get _tamano {
    final mb = _info.apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _actualizar() async {
    setState(() {
      _descargando = true;
      _error = null;
      _permisoFalta = false;
      _resultadoMensaje = null;
      _resultadoExitoso = false;
      _descargados = 0;
      _total = _info.apkSizeBytes;
    });
    try {
      // descargarAPK reutiliza el archivo ya descargado (mismo tamaño): si el
      // usuario reintenta tras cancelar o conceder el permiso, NO se re-descarga.
      final ruta = await UpdateService.instance.descargarAPK(
        _info,
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _descargados = d;
              if (t > 0) _total = t;
            });
          }
        },
      );
      if (!mounted) return;
      final resumen = await UpdateService.instance.instalar(ruta);
      if (!mounted) return;
      switch (resumen.resultado) {
        case InstalacionResultado.instalado:
          setState(() {
            _descargando = false;
            _resultadoExitoso = true;
            _resultadoMensaje =
                '✅ Actualización ${_info.version} instalada correctamente.';
          });
          break;
        case InstalacionResultado.cancelado:
          setState(() {
            _descargando = false;
            _resultadoMensaje = 'Instalación cancelada. '
                'El archivo ya está descargado; puedes reintentar cuando quieras.';
          });
          break;
        case InstalacionResultado.permisoRequerido:
          setState(() {
            _descargando = false;
            _permisoFalta = true;
            _error = resumen.mensaje;
          });
          break;
        case InstalacionResultado.error:
          setState(() {
            _descargando = false;
            _error = 'No se pudo instalar: '
                '${resumen.mensaje ?? 'error desconocido'}';
          });
          break;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _descargando = false;
          _error = 'Error al descargar: $e';
        });
      }
    }
  }

  Future<void> _permitirInstalacion() async {
    await UpdateService.abrirAjustesInstalacion();
    if (!mounted) return;
    setState(() {
      _permisoFalta = false;
      _error = 'Cuando permitas la instalación en los ajustes, vuelve y toca '
          '"Actualizar ahora" (el archivo ya está descargado).';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notas = _info.notes.trim();

    Widget contenido;
    if (!_descargando) {
      contenido = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.download, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text('$_tamano para descargar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
            ),
          ]),
          if (notas.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Novedades', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(notas,
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
            ),
          ],
          if (_resultadoMensaje != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _resultadoExitoso
                    ? scheme.primaryContainer.withValues(alpha: 0.6)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_resultadoMensaje!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _resultadoExitoso
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface)),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onErrorContainer)),
            ),
          ],
        ],
      );
    } else {
      contenido = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progreso,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('${(_progreso * 100).round()}%',
                style: theme.textTheme.labelLarge),
          ]),
          const SizedBox(height: 8),
          Text(
            _progreso >= 1
                ? 'Esperando confirmación de instalación…'
                : 'Descargando ${_info.apkSizeBytes > 0 ? (_descargados ~/ (1024 * 1024)) : 0} de $_tamano…',
            style: theme.textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          ],
        ],
      );
    }

    return AlertDialog(
      scrollable: true,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration:
            BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
        child:
            Icon(Icons.system_update_alt, color: scheme.primary, size: 28),
      ),
      title: Text(
        'Versión ${_info.versionEtiqueta} disponible',
        style:
            theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      content: contenido,
      actions: [
        if (_descargando)
          const TextButton(onPressed: null, child: Text('Espera…'))
        else if (_resultadoExitoso)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          )
        else ...[
          if (_resultadoMensaje != null)
            // Instalación cancelada: reintenta sin re-descargar (archivo en caché).
            FilledButton.icon(
              onPressed: _actualizar,
              icon: const Icon(Icons.download_done, size: 20),
              label: const Text('Actualizar de nuevo'),
            )
          else if (_permisoFalta)
            FilledButton.icon(
              onPressed: _permitirInstalacion,
              icon: const Icon(Icons.settings, size: 20),
              label: const Text('Permitir instalación'),
            )
          else
            FilledButton.icon(
              onPressed: _actualizar,
              icon: const Icon(Icons.download_done, size: 20),
              label: const Text('Actualizar ahora'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_resultadoMensaje != null ? 'Cerrar' : 'Más tarde'),
          ),
        ],
      ],
    );
  }
}
