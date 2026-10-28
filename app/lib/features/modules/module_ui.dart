import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../l10n/app_strings.dart';
import '../common/desktop_menu.dart';
import '../common/widgets.dart';

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
            DesktopToggle(
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
          key: ValueKey('select-$id'),
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
        return _ModuleTextField(
          value: value?.toString() ?? '',
          label: label,
          numeric: field['type'] == 'number',
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
        return DesktopIconButton(
          onPressed: () => onChanged(id, true),
          icon: Icons.play_arrow_outlined,
          label: label,
          tooltip: label,
          size: 34,
        );
      case 'label':
        return Text(
          values.containsKey(id) ? '$label: ${values[id]}' : label,
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

/// Text fields must accept host updates without recreating their focus/caret
/// on every keystroke (including round trips from a separate module window).
class _ModuleTextField extends StatefulWidget {
  const _ModuleTextField({
    required this.value,
    required this.label,
    required this.numeric,
    required this.onChanged,
  });
  final String value;
  final String label;
  final bool numeric;
  final ValueChanged<String> onChanged;
  @override
  State<_ModuleTextField> createState() => _ModuleTextFieldState();
}

class _ModuleTextFieldState extends State<_ModuleTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  @override
  void didUpdateWidget(covariant _ModuleTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      if (widget.numeric &&
          num.tryParse(_controller.text) == num.tryParse(widget.value)) {
        return;
      }
      final selection = _controller.selection;
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: selection.isValid
            ? TextSelection(
                baseOffset: selection.baseOffset.clamp(0, widget.value.length),
                extentOffset: selection.extentOffset.clamp(
                  0,
                  widget.value.length,
                ),
              )
            : TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(labelText: widget.label),
    keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
    onChanged: widget.onChanged,
  );
}
