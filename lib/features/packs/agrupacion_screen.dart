import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/agrupacion.dart';
import '../../data/repositories/celda_repository.dart';
import '../../state/celda_controller.dart';

/// Agrupa las celdas en bloques compatibles para armar packs.
///
/// Un pack que mezcla una celda al 95 % con otra al 62 % se degrada por la
/// peor. Esta pantalla usa la **medición real** de cada celda para decir qué
/// celdas se parecen lo suficiente para ir juntas, y explica por qué deja
/// fuera a las demás.
///
/// Se entra desde el inventario (agrupa lo que cumpla el filtro activo) o
/// desde un lote (agrupa solo las celdas de ese lote).
class AgrupacionScreen extends StatefulWidget {
  const AgrupacionScreen({
    super.key,
    this.filtro,
    this.titulo = 'Agrupar para packs',
    this.descripcion,
  });

  /// Filtro de las celdas a agrupar. Si es null se usa el filtro del inventario.
  final CeldaFilter? filtro;

  final String titulo;

  /// Texto que explica qué se está agrupando (p. ej. «Lote L-2026-09-A»).
  final String? descripcion;

  @override
  State<AgrupacionScreen> createState() => _AgrupacionScreenState();
}

class _AgrupacionScreenState extends State<AgrupacionScreen> {
  ResultadoAgrupacion? _resultado;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _agrupar());
  }

  Future<void> _agrupar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await context
          .read<CeldaController>()
          .agruparCeldas(filtro: widget.filtro);
      if (!mounted) return;
      setState(() {
        _resultado = r;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron agrupar las celdas.';
      });
      debugPrint('Agrupación: $e');
    }
  }

  Future<void> _ajustarTolerancias() async {
    final c = context.read<CeldaController>();
    final nuevas = await showDialog<ToleranciasAgrupacion>(
      context: context,
      builder: (_) => _DialogoTolerancias(actuales: c.tolerancias),
    );
    if (nuevas == null || !mounted) return;
    await c.setTolerancias(nuevas);
    if (mounted) await _agrupar();
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          IconButton(
            tooltip: 'Ajustar tolerancias',
            icon: const Icon(Icons.tune),
            onPressed: _ajustarTolerancias,
          ),
          IconButton(
            tooltip: 'Volver a agrupar',
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _agrupar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _Mensaje(
                  icon: Icons.error_outline,
                  titulo: 'No se pudo agrupar',
                  texto: _error!,
                  accion: FilledButton(
                    onPressed: _agrupar,
                    child: const Text('Reintentar'),
                  ),
                )
              : r == null || !r.hayAlgo
                  ? _Mensaje(
                      icon: Icons.battery_std_outlined,
                      titulo: 'No hay celdas que agrupar',
                      texto: 'No hay celdas medidas con el filtro actual. '
                          'Registra mediciones y vuelve a intentarlo.',
                    )
                  : _resultados(r),
    );
  }

  Widget _resultados(ResultadoAgrupacion r) {
    final grupos = r.gruposDePack;
    final sueltas = r.sinCompania;
    final excluidas = r.excluidas;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _encabezado(r),
        const SizedBox(height: 14),

        if (grupos.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No hay ningún grupo armable',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ninguna celda se parece lo suficiente a otra. Puedes '
                    'ensanchar las tolerancias o medir más celdas.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          )
        else
          for (var i = 0; i < grupos.length; i++) ...[
            _TarjetaGrupo(grupo: grupos[i], numero: i + 1, tolerancias: r.tolerancias),
            const SizedBox(height: 10),
          ],

        if (sueltas.isNotEmpty) ...[
          const SizedBox(height: 6),
          _Seccion(
            titulo: 'Celdas sin compañía',
            subtitulo: '${sueltas.length} · encajan consigo mismas y con nadie más',
            icon: Icons.crop_square,
            child: _ListaCeldas(celdas: sueltas),
          ),
        ],

        if (excluidas.isNotEmpty) ...[
          const SizedBox(height: 16),
          _excluidas(excluidas),
        ],
      ],
    );
  }

  Widget _encabezado(ResultadoAgrupacion r) {
    final scheme = Theme.of(context).colorScheme;
    final t = r.tolerancias;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.descripcion != null) ...[
              Text(
                widget.descripcion!,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              '${r.gruposDePack.length} '
              '${r.gruposDePack.length == 1 ? 'grupo armable' : 'grupos armables'} · '
              '${r.celdasAgrupadas} ${r.celdasAgrupadas == 1 ? 'celda' : 'celdas'} '
              'para pack',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Se compara la última medición de cada celda. La química tiene '
              'que ser idéntica y el parecido se mide con estas tolerancias:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Etiqueta('Capacidad ±${_num(t.capacidadPct)} %'),
                _Etiqueta('RI ±${_num(t.irPct)} %'),
                _Etiqueta('SoH ±${_num(t.sohPuntos)} pts'),
                _Etiqueta('Voltaje ±${_num(t.voltajeV, 2)} V'),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _ajustarTolerancias,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Ajustar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _excluidas(List<CeldaExcluida> excluidas) {
    // Se agrupan por motivo: «12 sin medición» dice mucho más que una lista
    // de doce códigos sueltos.
    final porMotivo = <MotivoExclusion, List<CeldaExcluida>>{};
    for (final e in excluidas) {
      porMotivo.putIfAbsent(e.motivo, () => []).add(e);
    }

    return _Seccion(
      titulo: 'Quedaron fuera',
      subtitulo: '${excluidas.length} '
          '${excluidas.length == 1 ? 'celda' : 'celdas'} sin agrupar',
      icon: Icons.block,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final motivo in MotivoExclusion.values)
            if (porMotivo[motivo] != null)
              _MotivoBloque(
                motivo: motivo,
                celdas: porMotivo[motivo]!
                    .map((e) => e.celda)
                    .toList(growable: false),
              ),
        ],
      ),
    );
  }
}

/// Tarjeta de un grupo armable.
class _TarjetaGrupo extends StatelessWidget {
  const _TarjetaGrupo({
    required this.grupo,
    required this.numero,
    required this.tolerancias,
  });

  final GrupoCompatibles grupo;
  final int numero;
  final ToleranciasAgrupacion tolerancias;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avisos = grupo.avisos;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: scheme.primary,
                  child: Text(
                    '$numero',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${grupo.tamano} celdas · ${grupo.quimica}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (grupo.capacidadSpreadPct != null)
                        Text(
                          'se llevan ${_num(grupo.capacidadSpreadPct!, 1)} % de capacidad',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (grupo.capacidadMediaMah != null)
                  _Dato(
                    'Capacidad media',
                    '${_num(grupo.capacidadMediaMah!, 0)} mAh',
                  ),
                if (grupo.sohMedio != null)
                  _Dato('SoH medio', '${_num(grupo.sohMedio!, 1)} %'),
                if (grupo.irMediaMohm != null)
                  _Dato('RI media', '${_num(grupo.irMediaMohm!, 1)} mΩ'),
                if (grupo.voltajeMedioV != null)
                  _Dato('Voltaje medio', '${_num(grupo.voltajeMedioV!, 2)} V'),
              ],
            ),
            if (grupo.capacidadAprovechableMah != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Capacidad aprovechable del pack: '
                  '${_num(grupo.capacidadAprovechableMah!, 0)} mAh '
                  '(la marca la celda más débil, no la media)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _ListaCeldas(celdas: grupo.celdasOrdenadas),
            if (avisos.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final a in avisos)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: scheme.tertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(a,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de celdas con su capacidad y su SoH.
class _ListaCeldas extends StatelessWidget {
  const _ListaCeldas({required this.celdas});

  final List<CeldaMedida> celdas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in celdas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.battery_std, size: 15, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.codigo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  [
                    if (c.capacidadMah != null) '${_num(c.capacidadMah!, 0)} mAh',
                    if (c.sohPct != null) '${_num(c.sohPct!, 1)} %',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bloque de celdas excluidas por un mismo motivo.
class _MotivoBloque extends StatelessWidget {
  const _MotivoBloque({required this.motivo, required this.celdas});

  final MotivoExclusion motivo;
  final List<CeldaMedida> celdas;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 4, bottom: 8),
        title: Text(
          '${motivo.label} · ${celdas.length}',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          motivo.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              celdas.map((c) => c.codigo).join(', '),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección con título, subtítulo y contenido.
class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.subtitulo,
    required this.icon,
    required this.child,
  });

  final String titulo;
  final String subtitulo;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitulo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(texto, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icon,
    required this.titulo,
    required this.texto,
    this.accion,
  });

  final IconData icon;
  final String titulo;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(texto, textAlign: TextAlign.center),
            if (accion != null) ...[
              const SizedBox(height: 18),
              accion!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Diálogo para cambiar las tolerancias de agrupación.
class _DialogoTolerancias extends StatefulWidget {
  const _DialogoTolerancias({required this.actuales});

  final ToleranciasAgrupacion actuales;

  @override
  State<_DialogoTolerancias> createState() => _DialogoToleranciasState();
}

class _DialogoToleranciasState extends State<_DialogoTolerancias> {
  late final TextEditingController _capacidad;
  late final TextEditingController _ir;
  late final TextEditingController _soh;
  late final TextEditingController _voltaje;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final t = widget.actuales;
    _capacidad = TextEditingController(text: _num(t.capacidadPct));
    _ir = TextEditingController(text: _num(t.irPct));
    _soh = TextEditingController(text: _num(t.sohPuntos));
    _voltaje = TextEditingController(text: _num(t.voltajeV, 2));
  }

  @override
  void dispose() {
    _capacidad.dispose();
    _ir.dispose();
    _soh.dispose();
    _voltaje.dispose();
    super.dispose();
  }

  String? _validar(String? v) {
    if (v == null || v.trim().isEmpty) return 'Pon un número';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Tiene que ser un número de 0 en adelante';
    return null;
  }

  void _guardar() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    double leer(TextEditingController c) =>
        double.parse(c.text.trim().replaceAll(',', '.'));
    Navigator.of(context).pop(
      ToleranciasAgrupacion(
        capacidadPct: leer(_capacidad),
        irPct: leer(_ir),
        sohPuntos: leer(_soh),
        voltajeV: leer(_voltaje),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tolerancias de agrupación'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Dos celdas van juntas si no se separan más que esto. '
                'Cuanto más estrecho, más parecido el pack; más ancho, '
                'más celdas aprovechables.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 14),
              _campo(_capacidad, 'Capacidad', '%', '5'),
              _campo(_ir, 'Resistencia interna', '%', '10'),
              _campo(_soh, 'SoH', 'puntos', '5'),
              _campo(_voltaje, 'Voltaje', 'V', '0,05'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String etiqueta,
    String sufijo,
    String ayuda,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: _validar,
          decoration: InputDecoration(
            labelText: etiqueta,
            suffixText: sufijo,
            helperText: 'Por defecto: $ayuda',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}

/// Formatea un número sin arrastrar decimales de más.
///
/// No se usa `intl` a propósito: las tolerancias y medidas se muestran en
/// formato neutro (punto decimal) para que coincidan con lo que se escribe en
/// los campos, que aceptan tanto punto como coma.
String _num(double v, [int decimales = 1]) {
  var s = v.toStringAsFixed(decimales);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
