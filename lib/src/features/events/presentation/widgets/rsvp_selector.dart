import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/rsvp_status.dart';

class RsvpSelector extends StatelessWidget {
  const RsvpSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RsvpStatus? selected;
  final ValueChanged<RsvpStatus>? onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SegmentedButton<RsvpStatus>(
      segments: RsvpStatus.values
          .map(
            (status) => ButtonSegment<RsvpStatus>(
              value: status,
              label: Text(status.label, textAlign: TextAlign.center),
            ),
          )
          .toList(),
      selected: {?selected},
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      onSelectionChanged: onSelected == null
          ? null
          : (selection) {
              if (selection.isNotEmpty) {
                onSelected!(selection.first);
              }
            },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return states.contains(WidgetState.disabled)
                ? AppPalette.accentCaliperRed.withValues(alpha: 0.45)
                : AppPalette.accentCaliperRed;
          }
          return states.contains(WidgetState.disabled)
              ? colorScheme.surfaceContainerHigh.withValues(alpha: 0.7)
              : colorScheme.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return states.contains(WidgetState.disabled)
                ? colorScheme.onTertiary.withValues(alpha: 0.8)
                : colorScheme.onTertiary;
          }
          return states.contains(WidgetState.disabled)
              ? colorScheme.onSurface.withValues(alpha: 0.38)
              : colorScheme.onSurfaceVariant;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? AppPalette.accentCaliperRed.withValues(alpha: 0.45)
                  : AppPalette.accentCaliperRed,
            );
          }
          return BorderSide(color: colorScheme.outlineVariant);
        }),
        textStyle: WidgetStatePropertyAll(
          Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
    );
  }
}
