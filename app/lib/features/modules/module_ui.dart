import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../l10n/app_strings.dart';
import '../common/desktop_menu.dart';

/// Allowlisted declarative controls. Extension code never receives a context.
class ModuleControls extends StatelessWidget {
  const ModuleControls({
    super.key,
    required this.schema,
    required this.values,
    required this.onChanged,
    this.localizePreview = false,
  });
  final List<dynamic> schema;
  final Map<String, dynamic> values;
  final void Function(String key, dynamic value) onChanged;
  final bool localizePreview;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final entry in schema.take(64))
        if (entry is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ModuleControl(
              key: ValueKey('${entry['id']}-${entry['type']}'),
              field: {
                ...Map<String, dynamic>.from(entry),
                if (localizePreview && entry['label'] is String)
                  'label': context.previewLabel(entry['label'] as String),
              },
              values: values,
              onChanged: onChanged,
              localizePreview: localizePreview,
            ),
          ),
    ],
  );
}

class _ModuleControl extends StatelessWidget {
  const _ModuleControl({
    super.key,
    required this.field,
    required this.values,
    required this.onChanged,
    required this.localizePreview,
  });
  final Map<String, dynamic> field;
  final Map<String, dynamic> values;
  final void Function(String key, dynamic value) onChanged;
  final bool localizePreview;
  @override
  Widget build(BuildContext context) {
    final id = field['id'] is String ? field['id'] as String : '';
    final label = field['label'] is String ? field['label'] as String : id;
    final value = values[id] ?? field['default'];
    if (id.isEmpty) return const SizedBox.shrink();
    switch (field['type']) {
      case 'slider':
        final min = field['min'] is num
            ? (field['min'] as num).toDouble()
            : 0.0;
        final max = field['max'] is num
            ? (field['max'] as num).toDouble()
            : 1.0;
        if (!min.isFinite || !max.isFinite || max <= min) {
          return const SizedBox.shrink();
        }
        final number = value is num ? value.toDouble() : min;
        final current = (number.isFinite ? number : min)
            .clamp(min, max)
            .toDouble();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 14)),
                ),
                Text(
                  current.toStringAsFixed(2),
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Slider(
              value: current,
              min: min,
              max: max,
              onChanged: (next) => onChanged(id, next),
            ),
          ],
        );
      case 'toggle':
        return Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
            Switch(
              value: value == true,
              onChanged: (next) => onChanged(id, next),
            ),
          ],
        );
      case 'select':
        final options =
            (field['options'] is List ? field['options'] as List : const [])
                .whereType<String>()
                .toSet()
                .take(64)
                .toList();
        return DesktopSelectField<String>(
          key: ValueKey('$id-$value'),
          label: label,
          valueLabel: options.contains(value)
              ? (localizePreview
                    ? context.previewLabel(value as String)
                    : value as String)
              : '—',
          entries: [
            for (final option in options)
              DesktopMenuEntry(
                value: option,
                label: localizePreview ? context.previewLabel(option) : option,
              ),
          ],
          onSelected: (next) => onChanged(id, next),
        );
      case 'text':
      case 'number':
        return TextFormField(
          initialValue: value?.toString() ?? '',
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(labelText: label),
          keyboardType: field['type'] == 'number'
              ? TextInputType.number
              : TextInputType.text,
          onChanged: (next) {
            if (field['type'] == 'number') {
              final parsed = num.tryParse(next);
              if (parsed != null) onChanged(id, parsed);
            } else {
              onChanged(id, next);
            }
          },
        );
      case 'button':
        return OutlinedButton(
          onPressed: () => onChanged(id, true),
          child: Text(label),
        );
      case 'label':
        return Text(
          label,
          style: TextStyle(
            color: context.palette.mutedText,
            fontSize: 14,
            height: 1.5,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
