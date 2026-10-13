import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/logic/logic_blocks.dart';
import '../../core/theme/app_palette.dart';
import '../../core/workspace/workspace_model.dart';
import '../../l10n/app_strings.dart';

/// Uses standard host fields; scripts are data interpreted by bounded host logic.
class LogicBlockEditor extends StatefulWidget {
  const LogicBlockEditor({
    super.key,
    required this.node,
    required this.onChanged,
  });
  final WorkspaceNode node;
  final void Function(String, dynamic) onChanged;
  @override
  State<LogicBlockEditor> createState() => _LogicBlockEditorState();
}

class _LogicBlockEditorState extends State<LogicBlockEditor> {
  late final String _field = switch (widget.node.logicType) {
    LogicBlockType.condition || LogicBlockType.filter => 'expression',
    LogicBlockType.select => 'fields',
    LogicBlockType.validate => 'schema',
    LogicBlockType.script => 'script',
  };
  late final TextEditingController _controller = TextEditingController(
    text:
        (widget.node.settings[_field] ??
                LogicBlocks.defaults(widget.node.logicType)[_field])
            .toString(),
  );
  final _sample = TextEditingController(text: '{"score":0.8,"channel":"C3"}');
  String? _result;
  @override
  void didUpdateWidget(covariant LogicBlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text =
        (widget.node.settings[_field] ??
                LogicBlocks.defaults(widget.node.logicType)[_field])
            .toString();
    if (_controller.text != text) {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _sample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.logicScriptHelp,
        style: TextStyle(color: context.palette.mutedText, height: 1.5),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _controller,
        key: ValueKey('logic editor $_field'),
        minLines: _field == 'expression' || _field == 'fields' ? 2 : 6,
        maxLines: 16,
        maxLength: 8192,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: InputDecoration(labelText: _field),
        onChanged: (value) => widget.onChanged(_field, value),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _sample,
        maxLines: 5,
        minLines: 2,
        maxLength: 8192,
        decoration: InputDecoration(labelText: context.l10n.logicTestInput),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: Text(context.l10n.logicTest),
        onPressed: () {
          try {
            final output = LogicBlocks.run(widget.node.logicType, {
              ...widget.node.settings,
              _field: _controller.text,
            }, jsonDecode(_sample.text));
            setState(
              () => _result = output.isEmpty
                  ? 'drop'
                  : output
                        .map((e) => '${e.port}: ${jsonEncode(e.value)}')
                        .join('\n'),
            );
          } catch (error) {
            setState(() => _result = '$error');
          }
        },
      ),
      if (_result != null) SelectableText(_result!),
      if (widget.node.runtimeStatus != null) ...[
        const SizedBox(height: 12),
        Text(widget.node.runtimeStatus!),
      ],
    ],
  );
}
