import '../../core/theme/app_icons.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../common/widgets.dart';

/// Host-rendered custom module surface. It is intentionally declarative:
/// module code supplies a layout description, while the host retains the
/// active window, navigation, theme and input boundaries.
class ModuleCustomUi extends StatelessWidget {
  const ModuleCustomUi({
    super.key,
    required this.schema,
    required this.values,
    required this.history,
    required this.onChanged,
  });
  final Map<String, dynamic> schema;
  final Map<String, dynamic> values;
  final Map<String, List<double>> history;
  final void Function(String key, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) => _CustomNode(
    node: schema,
    values: values,
    history: history,
    onChanged: onChanged,
  );
}

class _CustomNode extends StatelessWidget {
  const _CustomNode({
    required this.node,
    required this.values,
    required this.history,
    required this.onChanged,
  });
  final Map<String, dynamic> node;
  final Map<String, dynamic> values;
  final Map<String, List<double>> history;
  final void Function(String key, dynamic value) onChanged;

  List<dynamic> get children =>
      node['children'] is List ? node['children'] as List : const [];
  List<Widget> get childWidgets => [
    for (final child in children)
      if (child is Map)
        _CustomNode(
          node: Map<String, dynamic>.from(child),
          values: values,
          history: history,
          onChanged: onChanged,
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final type = node['type'];
    final padding = _insets(node['padding']);
    final content = switch (type) {
      'column' => Column(
        crossAxisAlignment: _alignment(node['align']),
        children: _spaced(childWidgets, node['gap']),
      ),
      'row' => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: _spaced(childWidgets, node['gap'], horizontal: true),
      ),
      'card' => DesktopPane(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _spaced(childWidgets, node['gap']),
          ),
        ),
      ),
      'text' => Text(
        _value(node['value'] ?? node['text']),
        style: TextStyle(
          color: _color(context, node['tone']),
          fontSize: (node['size'] as num?)?.toDouble() ?? 14,
          fontWeight: _weight(node['weight']),
          height: 1.35,
        ),
        maxLines: (node['maxLines'] as num?)?.toInt(),
        overflow: TextOverflow.ellipsis,
      ),
      'value' => _ValueText(
        label: node['label'] as String? ?? '',
        value: _value(values[node['id']]),
      ),
      'button' => DesktopIconButton(
        icon: _icon(node['icon']),
        label: node['label'] as String? ?? '',
        tooltip: node['label'] as String? ?? '',
        onPressed: node['id'] is String
            ? () => onChanged(node['id'], true)
            : null,
        size: 36,
      ),
      'input' => _CustomInput(
        id: node['id'] as String? ?? '',
        label: node['label'] as String? ?? '',
        value: values[node['id']],
        numeric: node['inputType'] == 'number',
        onChanged: onChanged,
      ),
      'chart' => _ModuleChart(
        title: node['title'] as String? ?? '',
        values: history[node['id']] ?? const [],
        color: _color(context, node['tone']) ?? context.palette.text,
      ),
      'divider' => Divider(
        color: context.palette.mutedText.withValues(alpha: .22),
      ),
      'spacer' => SizedBox(height: (node['height'] as num?)?.toDouble() ?? 8),
      _ => const SizedBox.shrink(),
    };
    return padding == null || type == 'card'
        ? content
        : Padding(padding: padding, child: content);
  }

  String _value(dynamic value) => value == null ? '—' : value.toString();

  List<Widget> _spaced(
    List<Widget> items,
    dynamic rawGap, {
    bool horizontal = false,
  }) {
    final gap = (rawGap as num?)?.toDouble() ?? 10;
    return [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) ...[
          SizedBox(width: horizontal ? gap : 0, height: horizontal ? 0 : gap),
        ],
        horizontal ? Flexible(child: items[i]) : items[i],
      ],
    ];
  }

  EdgeInsets? _insets(dynamic value) =>
      value is num ? EdgeInsets.all(value.toDouble()) : null;
  CrossAxisAlignment _alignment(dynamic value) => switch (value) {
    'center' => CrossAxisAlignment.center,
    'end' => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.stretch,
  };
  FontWeight? _weight(dynamic value) =>
      value == 'bold' ? FontWeight.w600 : null;
  IconData _icon(dynamic value) => switch (value) {
    'play' => AppIcons.play,
    'add' => AppIcons.add,
    'remove' => AppIcons.minus,
    'clear' => AppIcons.close,
    _ => AppIcons.bolt,
  };
  Color? _color(BuildContext context, dynamic value) => switch (value) {
    'muted' => context.palette.mutedText,
    'accent' => context.palette.text,
    'success' => const Color(0xFF70B78B),
    'warning' => const Color(0xFFD5A35B),
    _ => context.palette.text,
  };
}

class _ValueText extends StatelessWidget {
  const _ValueText({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: TextStyle(color: context.palette.mutedText)),
      ),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

class _CustomInput extends StatefulWidget {
  const _CustomInput({
    required this.id,
    required this.label,
    required this.value,
    required this.numeric,
    required this.onChanged,
  });
  final String id, label;
  final dynamic value;
  final bool numeric;
  final void Function(String, dynamic) onChanged;
  @override
  State<_CustomInput> createState() => _CustomInputState();
}

class _CustomInputState extends State<_CustomInput> {
  late final controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );
  @override
  void didUpdateWidget(covariant _CustomInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.value?.toString() ?? '';
    if (next != controller.text &&
        !(widget.numeric &&
            num.tryParse(next) == num.tryParse(controller.text))) {
      controller.text = next;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: widget.label),
    keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
    onChanged: (value) => widget.onChanged(
      widget.id,
      widget.numeric ? num.tryParse(value) ?? 0 : value,
    ),
  );
}

class _ModuleChart extends StatelessWidget {
  const _ModuleChart({
    required this.title,
    required this.values,
    required this.color,
  });
  final String title;
  final List<double> values;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title.isNotEmpty)
        Text(title, style: TextStyle(color: context.palette.mutedText)),
      const SizedBox(height: 8),
      SizedBox(
        height: 120,
        child: CustomPaint(painter: _ChartPainter(values, color)),
      ),
    ],
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.color);
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = color.withValues(alpha: .06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      background,
    );
    if (values.length < 2) return;
    final min = values.reduce(math.min), max = values.reduce(math.max);
    final range = max - min == 0 ? 1 : max - min;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y =
          size.height - ((values[i] - min) / range * (size.height - 12) + 6);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values || old.color != color;
}
