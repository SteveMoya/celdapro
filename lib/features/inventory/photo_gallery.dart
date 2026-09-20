import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/celda.dart';
import '../../data/models/celda_foto.dart';
import '../../services/photo_service.dart';
import '../../state/celda_controller.dart';

/// Galería de fotos de evidencia de una celda.
///
/// Cada foto lleva su etiqueta (cómo llegó, cómo quedó, un fallo…) para que la
/// evidencia se entienda sola, sin depender del orden en que se sacaron.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.celda});

  final Celda celda;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  static const _service = PhotoService();

  List<CeldaFoto> _fotos = const [];
  bool _cargando = true;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(PhotoGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.celda.id != widget.celda.id) _cargar();
  }

  Future<void> _cargar() async {
    final id = widget.celda.id;
    if (id == null) {
      setState(() => _cargando = false);
      return;
    }
    List<CeldaFoto> lista;
    try {
      lista = await context.read<CeldaController>().fotosOf(id);
    } catch (_) {
      // Si la galería no se puede leer, la ficha de la celda sigue siendo
      // utilizable: se muestra vacía en vez de romper la pantalla.
      lista = const [];
    }
    if (!mounted) return;
    setState(() {
      _fotos = lista;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _fotos.isEmpty
                        ? 'Fotos de evidencia'
                        : 'Fotos de evidencia (${_fotos.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Añadir foto',
                  onPressed: _ocupado ? null : _elegirOrigen,
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
              ],
            ),
          ),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_fotos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Row(
                children: [
                  Icon(Icons.image_outlined, color: scheme.outline),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sin fotos todavía. Sirven de respaldo si el cliente '
                      'reclama por una celda.',
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                itemCount: _fotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _Miniatura(
                  foto: _fotos[i],
                  esPortada: _fotos[i].path == widget.celda.fotoPath,
                  onTap: () => _ver(_fotos[i]),
                  onEtiqueta: () => _cambiarEtiqueta(_fotos[i]),
                  onBorrar: () => _borrar(_fotos[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- Acciones ----------

  /// Pregunta para qué sirve la foto antes de abrir la cámara.
  Future<void> _elegirOrigen() async {
    final etiqueta = await showModalBottomSheet<PhotoTag>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                '¿Qué foto vas a añadir?',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final t in PhotoTag.values)
              ListTile(
                leading: Icon(_iconoDe(t)),
                title: Text(t.label),
                subtitle: Text(t.description),
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (etiqueta == null || !mounted) return;

    final origen = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(ctx).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    );
    if (origen == null || !mounted) return;

    await _anadir(fromCamera: origen, etiqueta: etiqueta);
  }

  Future<void> _anadir({
    required bool fromCamera,
    required PhotoTag etiqueta,
  }) async {
    final celda = widget.celda;
    if (celda.id == null) return;
    setState(() => _ocupado = true);
    try {
      final path = await _service.pickAndSave(
        celdaId: celda.id!,
        fromCamera: fromCamera,
      );
      if (path == null || !mounted) return;
      await context.read<CeldaController>().addFoto(
            celda,
            path,
            etiqueta: etiqueta,
          );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _borrar(CeldaFoto foto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar foto'),
        content: Text('¿Borrar la foto «${foto.etiqueta.label}»? '
            'No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await context.read<CeldaController>().removeFoto(widget.celda, foto);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo borrar: $e')),
      );
    }
  }

  Future<void> _cambiarEtiqueta(CeldaFoto foto) async {
    final nueva = await showModalBottomSheet<PhotoTag>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in PhotoTag.values)
              ListTile(
                leading: Icon(_iconoDe(t)),
                title: Text(t.label),
                selected: t == foto.etiqueta,
                onTap: () => Navigator.of(ctx).pop(t),
              ),
          ],
        ),
      ),
    );
    if (nueva == null || nueva == foto.etiqueta || !mounted) return;
    await context.read<CeldaController>().setFotoEtiqueta(foto, nueva);
    await _cargar();
  }

  Future<void> _ver(CeldaFoto foto) async {
    if (!await File(foto.path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo de la foto ya no existe.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _VisorFoto(foto: foto),
      ),
    );
  }

  static IconData _iconoDe(PhotoTag t) => switch (t) {
        PhotoTag.evidence => Icons.image_outlined,
        PhotoTag.before => Icons.inbox_outlined,
        PhotoTag.after => Icons.auto_fix_high_outlined,
        PhotoTag.failure => Icons.warning_amber_rounded,
        PhotoTag.other => Icons.more_horiz,
      };
}

/// Miniatura con su etiqueta y sus acciones.
class _Miniatura extends StatelessWidget {
  const _Miniatura({
    required this.foto,
    required this.esPortada,
    required this.onTap,
    required this.onEtiqueta,
    required this.onBorrar,
  });

  final CeldaFoto foto;
  final bool esPortada;
  final VoidCallback onTap;
  final VoidCallback onEtiqueta;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onTap,
                    child: Image.file(
                      File(foto.path),
                      fit: BoxFit.cover,
                      // Si el archivo desapareció, se ve un marcador en vez de
                      // una pantalla roja de error.
                      errorBuilder: (_, _, _) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_outlined,
                            color: scheme.outline),
                      ),
                    ),
                  ),
                ),
                if (esPortada)
                  Positioned(
                    left: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Portada',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: onEtiqueta,
            onLongPress: onBorrar,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      foto.etiqueta.label,
                      style: Theme.of(context).textTheme.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.edit_outlined, size: 12, color: scheme.outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visor a pantalla completa con zoom.
class _VisorFoto extends StatelessWidget {
  const _VisorFoto({required this.foto});

  final CeldaFoto foto;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(foto.etiqueta.label),
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: Image.file(File(foto.path)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    foto.nota ?? foto.etiqueta.description,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fecha(foto.fecha),
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _fecha(DateTime f) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(f.day)}/${dos(f.month)}/${f.year} '
        '${dos(f.hour)}:${dos(f.minute)}';
  }
}
