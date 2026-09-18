import 'package:flutter/material.dart';

import '../../data/cell_catalog.dart';
import '../../data/models/celda.dart';

/// Pantalla de catálogo: busca una celda comercial y devuelve su ficha para
/// pre-rellenar el alta (capacidad nominal, voltaje, química y resistencia).
class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  late final TextEditingController _searchCtrl =
      TextEditingController(text: widget.initialQuery ?? '');
  Chemistry? _chemistry;
  String? _format;
  late List<CellCatalogEntry> _results = CellCatalog.search(
    widget.initialQuery ?? '',
  );

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_apply);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    setState(() {
      _results = CellCatalog.search(
        _searchCtrl.text,
        chemistry: _chemistry,
        format: _format,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de celdas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${CellCatalog.all.length} modelos de referencia',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: widget.initialQuery == null,
              decoration: InputDecoration(
                hintText: 'Busca por marca, modelo o capacidad',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _apply();
                        },
                      ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todo'),
                  selected: _chemistry == null && _format == null,
                  onSelected: (_) => setState(() {
                    _chemistry = null;
                    _format = null;
                    _apply();
                  }),
                ),
                const SizedBox(width: 8),
                for (final c in Chemistry.values) ...[
                  FilterChip(
                    label: Text(c.label),
                    selected: _chemistry == c,
                    onSelected: (sel) => setState(() {
                      _chemistry = sel ? c : null;
                      _apply();
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
                for (final f in const ['18650', '21700', '26650']) ...[
                  FilterChip(
                    label: Text(f),
                    selected: _format == f,
                    onSelected: (sel) => setState(() {
                      _format = sel ? f : null;
                      _apply();
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados. Prueba con otra marca o modelo.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) => _CatalogoTile(
                      entry: _results[i],
                      // Con búsqueda activa, un toque elige y vuelve.
                      onTap: () => Navigator.of(context).pop(_results[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CatalogoTile extends StatelessWidget {
  const _CatalogoTile({required this.entry, required this.onTap});

  final CellCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  entry.format,
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.chemistry.label} · ${entry.capacityMah} mAh · '
                      '${entry.voltage} V · ${entry.irMohm} mΩ',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (entry.maxDischargeA != null)
                      Text(
                        'Descarga ${_fmt(entry.maxDischargeA)} A'
                        '${entry.pulseDischargeA == null ? '' : ' (pico ${_fmt(entry.pulseDischargeA)} A)'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double? v) =>
      v == null ? '—' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
}
