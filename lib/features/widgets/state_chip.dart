import 'package:flutter/material.dart';

import '../../data/models/celda.dart';

/// Chip del estado del proceso en el que está la celda.
class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.state});

  final CellState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (state) {
      CellState.received => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      CellState.testing => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      CellState.classified => (scheme.primaryContainer, scheme.onPrimaryContainer),
      CellState.balanced => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      CellState.repacked => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      CellState.qaPassed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      CellState.rejected => (scheme.errorContainer, scheme.onErrorContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        state.label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
