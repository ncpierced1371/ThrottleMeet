import 'package:flutter/material.dart';

import '../../domain/entities/rsvp_status.dart';

class RsvpSelector extends StatelessWidget {
  const RsvpSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final RsvpStatus selected;
  final ValueChanged<RsvpStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: RsvpStatus.values.map((status) {
        final isSelected = status == selected;

        return ChoiceChip(
          label: Text(status.label),
          selected: isSelected,
          onSelected: (_) => onSelected(status),
        );
      }).toList(),
    );
  }
}
