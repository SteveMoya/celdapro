import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_info.dart';
import '../../core/pro_license.dart';
import '../../services/photo_service.dart';
import '../../state/celda_controller.dart';
import '../updates/update_controller.dart';

/// Sección "Versión Pro": la marca del taller en los informes.
///
/// Los informes funcionan **sin** esto: salen con la marca de CeldaPro y no
/// piden ningún dato del taller. Lo que añade Pro es poder poner el nombre y
/// el logo del taller en las etiquetas y los informes exportados.
class ProCard extends StatelessWidget {
  const ProCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final scheme = Theme.of(context).colorScheme;

    if (!c.esPro) return const _ProInactiva();

    final logoTaller = c.logoTaller;
    final tieneLogo = logoTaller != null && File(logoTaller).existsSync();

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.workspace_premium, color: scheme.primary),
            title: const Text('CeldaPro Pro'),
            subtitle: Text(
              c.licencia == null ? 'Activada' : 'Activada · ${_enmascarar(c.licencia!)}',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Nombre del taller'),
            subtitle: Text(
              c.nombreTaller ?? 'Sin definir — el informe saldrá solo con '
                  'la marca de CeldaPro',
            ),
            onTap: () => _editarTaller(context, c),
          ),
          const Divider(height: 1),
          ListTile(
            leading: tieneLogo
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: Image.file(File(logoTaller), fit: BoxFit.contain),
                  )
                : const Icon(Icons.image_outlined),
            title: const Text('Logo del taller'),
            subtitle: Text(
              tieneLogo ? 'Aparece en los informes' : 'Sin logo (opcional)',
            ),
            onTap: () => _elegirLogo(context, c),
            trailing: tieneLogo
                ? IconButton(
                    tooltip: 'Quitar logo',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _quitarLogo(context, c),
                  )
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.key_off_outlined),
            title: const Text('Desactivar Pro'),
            subtitle: const Text(
              'El nombre y el logo se conservan por si vuelves a activarla',
            ),
            onTap: () => _desactivar(context, c),
          ),
        ],
      ),
    );
  }

  /// Deja el código a la vista pero sin la firma completa: sirve para
  /// reconocerlo sin exponerlo entero en una captura de pantalla.
  static String _enmascarar(String codigo) {
    final partes = codigo.split('-');
    if (partes.length < 4) return codigo;
    return '${partes[0]}-${partes[1]}-••••';
  }

  Future<void> _editarTaller(BuildContext context, CeldaController c) async {
    final ctrl = TextEditingController(text: c.nombreTaller ?? '');
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre del taller'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Aparecerá en las etiquetas y los informes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nombre == null) return;
    await c.setNombreTaller(nombre);
  }

  Future<void> _elegirLogo(BuildContext context, CeldaController c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ruta = await const PhotoService().pickLogo();
      if (ruta == null) return;
      await c.setLogoTaller(ruta);
      messenger.showSnackBar(
        const SnackBar(content: Text('Logo guardado: saldrá en los informes')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar el logo: $e')),
      );
    }
  }

  Future<void> _quitarLogo(BuildContext context, CeldaController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar el logo'),
        content: const Text('Los informes volverán a salir con la marca de '
            'CeldaPro.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await c.quitarLogoTaller();
  }

  Future<void> _desactivar(BuildContext context, CeldaController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Desactivar la versión Pro?'),
        content: const Text(
          'Los informes y las etiquetas volverán a salir con la marca de '
          'CeldaPro. Tus datos, el nombre y el logo del taller no se borran.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await c.desactivarPro();
  }
}

/// Estado sin licencia: explica qué añade Pro y permite activarla.
class _ProInactiva extends StatelessWidget {
  const _ProInactiva();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.read<CeldaController>();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.workspace_premium_outlined, color: scheme.primary),
            title: const Text('CeldaPro Pro'),
            subtitle: const Text(
              'Pon el nombre y el logo de tu taller en las etiquetas y los '
              'informes. Todo lo demás de la app ya funciona sin esto.',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Activar con código'),
            subtitle: const Text(ProLicense.ejemplo),
            onTap: () => _activar(context, c),
          ),
        ],
      ),
    );
  }

  Future<void> _activar(BuildContext context, CeldaController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activar CeldaPro Pro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escribe el código que te entregaron. Se comprueba en '
                'el teléfono, sin conexión.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código',
                hintText: ProLicense.ejemplo,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (codigo == null || codigo.isEmpty) return;

    final ok = await c.activarPro(codigo);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Pro activada: ya puedes poner el nombre y el logo del taller'
              : 'Ese código no es válido. Revisa que esté completo.',
        ),
      ),
    );
  }
}

/// Sección de actualizaciones: buscar a mano y decidir si se busca sola.
class UpdatesCard extends StatefulWidget {
  const UpdatesCard({super.key});

  @override
  State<UpdatesCard> createState() => _UpdatesCardState();
}

class _UpdatesCardState extends State<UpdatesCard> {
  bool _buscando = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Buscar actualizaciones'),
            subtitle: Text('Versión instalada: $appVersionFull'),
            trailing: _buscando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _buscando ? null : () => _buscar(c),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: const Text('Buscar automáticamente'),
            subtitle: const Text('Al abrir la app y al volver a ella'),
            value: c.updateAutomatico,
            onChanged: (v) => c.setUpdateAutomatico(v),
          ),
        ],
      ),
    );
  }

  Future<void> _buscar(CeldaController c) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _buscando = true);
    // avisarSiempre: el usuario lo pidió, así que se ignora el mínimo de
    // tiempo entre revisiones y el aviso ya mostrado para esa versión.
    final info = await UpdateController.instance.verificar(avisarSiempre: true);
    if (!mounted) return;
    setState(() => _buscando = false);
    if (info == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Ya tienes la última versión ($appVersion) ✅'),
        ),
      );
    }
  }
}
