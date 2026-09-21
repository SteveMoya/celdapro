import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/ocr_code.dart';
import '../../data/models/celda.dart';
import '../../state/celda_controller.dart';

/// Lee el código de una celda con OCR a partir de una foto de su etiqueta.
///
/// El taller pega en cada celda una tira con el código en texto grande. Esta
/// pantalla hace la foto, lee el texto con el reconocedor del teléfono (que va
/// dentro de la app, sin internet) y busca el código en la base.
///
/// El OCR no es perfecto, así que la pantalla nunca deja al operador sin salida:
/// enseña lo que leyó, y si no acierta propone los códigos más parecidos y
/// permite escribir el código a mano.
///
/// Devuelve al salir el código elegido (o `null` si se cancela).
class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  final _picker = ImagePicker();
  final _reconocedor = TextRecognizer(script: TextRecognitionScript.latin);
  final _manualCtrl = TextEditingController();

  bool _leyendo = false;
  bool _hayFoto = false;
  String _textoLeido = '';
  Celda? _encontrada;
  List<String> _parecidos = const [];

  @override
  void dispose() {
    _manualCtrl.dispose();
    _reconocedor.close();
    super.dispose();
  }

  /// Hace o elige una foto, la lee y busca el código.
  Future<void> _leer(ImageSource origen) async {
    setState(() {
      _leyendo = true;
      _textoLeido = '';
      _encontrada = null;
      _parecidos = const [];
      _hayFoto = false;
    });

    // Se lee el controlador antes de los `await`: después de un await el
    // `context` puede ya no ser válido.
    final controller = context.read<CeldaController>();

    try {
      final foto = await _picker.pickImage(
        source: origen,
        // Al reconocedor no le aporta nada una foto gigante, y tarda más.
        maxWidth: 2400,
        imageQuality: 95,
      );
      if (foto == null) {
        if (mounted) setState(() => _leyendo = false);
        return;
      }

      final reconocido = await _reconocedor.processImage(
        InputImage.fromFilePath(foto.path),
      );
      final texto = reconocido.text;

      // Se prueban los candidatos en orden: el primero que exista en la base
      // gana. El orden lo decide la lógica pura de `ocr_code.dart`: primero la
      // lectura corregida, después lo leído tal cual.
      Celda? hallada;
      for (final candidato in codigosCandidatos(texto)) {
        hallada = await controller.celdaPorCodigo(candidato);
        if (hallada != null) break;
      }

      // Si nada coincide, se proponen los códigos más parecidos del inventario
      // en vez de dejar al operador con un "no encontrado" y nada más.
      var parecidos = const <String>[];
      if (hallada == null) {
        parecidos = sugerencias(texto, await controller.todosLosCodigos());
      }

      if (!mounted) return;
      setState(() {
        _leyendo = false;
        _hayFoto = true;
        _textoLeido = texto;
        _encontrada = hallada;
        _parecidos = parecidos;
      });
    } catch (error) {
      debugPrint('OCR: no se pudo procesar la foto: $error');
      if (!mounted) return;
      setState(() {
        _leyendo = false;
        _hayFoto = true;
      });
      _avisar('No se pudo leer la foto. Prueba otra vez con más luz.');
    }
  }

  void _avisar(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  void _elegir(String codigo) => Navigator.of(context).pop(codigo.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leer código con OCR')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _instruccion(context),
          const SizedBox(height: 16),
          _botones(),
          if (_leyendo) ...[
            const SizedBox(height: 28),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Leyendo la etiqueta…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (!_leyendo && _hayFoto) ...[
            const SizedBox(height: 24),
            _resultado(context),
          ],
        ],
      ),
    );
  }

  Widget _instruccion(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Etiqueta en una línea',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Encuadra el código impreso y que ocupe buena parte de la foto. '
              'Con luz y sin mover el teléfono acierta más.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _botones() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _leyendo ? null : () => _leer(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Hacer foto'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _leyendo ? null : () => _leer(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('De la galería'),
          ),
        ),
      ],
    );
  }

  Widget _resultado(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final encontrada = _encontrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (encontrada != null)
          Card(
            color: scheme.primaryContainer,
            child: ListTile(
              leading: Icon(Icons.check_circle, color: scheme.primary),
              title: Text(
                encontrada.codigoInterno,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                [
                  if (encontrada.marca != null || encontrada.modelo != null)
                    [encontrada.marca, encontrada.modelo]
                        .whereType<String>()
                        .join(' '),
                  encontrada.estado.label,
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _elegir(encontrada.codigoInterno),
            ),
          )
        else ...[
          Text(
            'No encontré esa celda',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Puede que el código no esté en la base o que la foto no se lea '
            'bien. Esto es lo que leí:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        if (_textoLeido.trim().isNotEmpty)
          _cajaTexto(context, 'Lo que leí', _textoLeido.trim()),
        if (_parecidos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '¿Querías decir…?',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final codigo in _parecidos)
                ActionChip(
                  label: Text(codigo),
                  onPressed: () => _elegir(codigo),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'O escribe el código a mano',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _manualCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código de la celda',
                  hintText: 'C-0001',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) _elegir(v);
                },
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                if (_manualCtrl.text.trim().isNotEmpty) {
                  _elegir(_manualCtrl.text);
                }
              },
              child: const Text('Buscar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cajaTexto(BuildContext context, String titulo, String contenido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          SelectableText(
            contenido,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
    );
  }
}
