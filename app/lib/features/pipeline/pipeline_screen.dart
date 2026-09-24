import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/modules/module_registry.dart';
import '../../state/engine_provider.dart';
import '../common/widgets.dart';

/// Visual chain of the processing pipeline.
class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final List<String> coreJsons = ref.watch(engineProvider.notifier).moduleJsons();

    return ListView(
      children: [
        const ScreenHeader(
          title: 'Конвейер',
          subtitle: 'Device → Raw Buffer → Preprocessing → Features → Output',
        ),
        InfoCard(
          title: 'Активная цепочка ядра',
          headerIcon: Icons.linear_scale,
          trailing: StatusChip(
            label: coreJsons.isEmpty ? 'недоступно' : '${coreJsons.length} модулей',
            color: coreJsons.isEmpty
                ? theme.colorScheme.outline
                : theme.colorScheme.primary,
          ),
          children: [
            if (coreJsons.isEmpty)
              Text(
                'Ядро офлайн: цепочка инициализируется при старте сессии. '
                'Запустите тестовую сессию на экране «Сессия».',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            else
              Text(
                'Модули получены из ядра через bci_engine_module_json():',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        if (coreJsons.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < coreJsons.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: theme.colorScheme.primary
                                .withAlpha(60),
                            child: Text('${i + 1}',
                                style: theme.textTheme.labelSmall),
                          ),
                          const SizedBox(width: 10),
                          SelectableText(
                            coreJsons[i],
                            style: theme.textTheme.bodySmall
                                ?.copyWith(fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        InfoCard(
          title: 'Реестр модулей (Dart-каталог)',
          headerIcon: Icons.extension_outlined,
          children: [
            for (final SystemModule m in kSystemModules)
              _PipelineRow(module: m),
          ],
        ),
      ],
    );
  }
}

class _PipelineRow extends StatelessWidget {
  const _PipelineRow({required this.module});

  final SystemModule module;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            module.active ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: module.active
                ? Colors.greenAccent
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 208,
            child: Text('${module.id} · ${module.stage}',
                style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              module.name,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
