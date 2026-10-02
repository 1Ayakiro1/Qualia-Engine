import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/engine_provider.dart';
import '../common/widgets.dart';

/// Visual chain of the processing pipeline.
class PipelineScreen extends ConsumerWidget {
  const PipelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final List<String> coreJsons = ref
        .watch(engineProvider.notifier)
        .moduleJsons();

    return ListView(
      children: [
        ScreenHeader(
          title: context.l10n.textPipeline42,
          subtitle:
              context.l10n.textDeviceRawBufferPreprocessingFeaturesOutput289,
        ),
        InfoCard(
          title: context.l10n.textActiveCorePipeline290,
          headerIcon: Icons.linear_scale,
          trailing: StatusChip(
            label: coreJsons.isEmpty
                ? context.l10n.textUnavailable291
                : context.l10n.textArg0Modules292(
                    (coreJsons.length).toString(),
                  ),
            color: coreJsons.isEmpty
                ? theme.colorScheme.outline
                : theme.colorScheme.primary,
          ),
          children: [
            if (coreJsons.isEmpty)
              Text(
                context.l10n.pipelineOfflineNotice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Text(
                context.l10n.textModulesRetrievedFromTheCoreViaBci293,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SelectableText(
                            coreJsons[i],
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
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
