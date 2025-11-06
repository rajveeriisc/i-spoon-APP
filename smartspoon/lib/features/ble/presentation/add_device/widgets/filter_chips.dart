import 'package:flutter/material.dart';

class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.filterIndex,
    required this.onChanged,
  });

  final int filterIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    InputChip filter(String label, int idx) => InputChip(
      label: Text(label),
      selected: filterIndex == idx,
      onSelected: (_) => onChanged(idx),
    );
    return Row(
      children: [
        filter('All', 0),
        const SizedBox(width: 8),
        filter('Nearby', 1),
        const SizedBox(width: 8),
        filter('Connected', 2),
      ],
    );
  }
}
