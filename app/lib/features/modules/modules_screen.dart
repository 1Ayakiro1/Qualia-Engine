import 'package:flutter/material.dart';

import '../../core/modules/module_registry.dart';
import '../common/widgets.dart';

/// Module registry: system modules (active) and planned ones.
class ModulesScreen extends StatelessWidget {
  const ModulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final int activeCount =
        kSystemModules.where((SystemModule m) => m.active).length;

    return ListView(
      children: [
        ScreenHeader(
          title: 'Модули',
          subtitle: 'Системные: $activeCount реализовано · '
              '${kSystemModules.length - activeCount} запланировано',
        ),
        for (final SystemModule m in kSystemModules)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.name,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      StatusChip(
                        label: m.active ? 'активен' : 'запланирован',
                        color: m.active
                            ? Colors.greenAccent
                            : theme.colorScheme.outline,
                        icon: m.active ? Icons.check : Icons.schedule,
                      ),
                      const SizedBox(width: 8),
                      StatusChip(
                        label: m.category,
                        color: theme.colorScheme.secondary,
                        icon: Icons.category_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${m.id} · v${m.version} · этап: ${m.stage}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(m.description, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Контракт модуля', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Пользовательские модули будут подгружаться из песочницы '
                  '(Permission & Sandbox Manager): манифест (id, категории, '
                  'права), инициализация, обработка блоков сэмплов и работа '
                  'с конфигами. Спецификация — docs/MODULES.md.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
