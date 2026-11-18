import '../../core/theme/app_icons.dart';
import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';

import '../common/widgets.dart';

/// Datasets: upload/create/compare (researcher toolset, v0.2).
class DatasetsScreen extends StatelessWidget {
  const DatasetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ScreenHeader(
          title: context.l10n.textDatasets49,
          subtitle: context.l10n.textImportCreationAndComparisonOfRecordings393,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(AppIcons.folders, size: 48),
                SizedBox(height: 12),
                Text(context.l10n.textYourDatasetsWillAppearHere394),
                SizedBox(height: 8),
                Text(context.l10n.datasetsRoadmap, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
