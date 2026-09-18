import 'package:flutter/material.dart';

import '../../core/classification.dart';
import '../../core/theme.dart';

/// Chip de veredicto (A / B / C / Rechazo) con su color.
class VerdictChip extends StatelessWidget {
  const VerdictChip({super.key, required this.verdict, this.dense = false});

  final Verdict? verdict;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final v = verdict;
    final color = v == null ? Theme.of(context).colorScheme.outline : AppTheme.verdictColor(v.code);
    final label = v == null ? 'Sin clasificar' : v.code;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: dense ? 11 : 13,
        ),
      ),
    );
  }
}
