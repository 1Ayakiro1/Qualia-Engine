import '../../l10n/app_strings.dart';

import 'package:flutter/material.dart';

import '../common/widgets.dart';

/// Models: no-code training and model registry (v0.2).
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        ScreenHeader(
          title: context.l10n.textModels51,
          subtitle: context.l10n.textNoCodeTrainingAndModelRegistry395,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.psychology_outlined, size: 48),
                SizedBox(height: 12),
                Text(context.l10n.textTheModelRegistryIsEmpty396),
                SizedBox(height: 8),
                Text(context.l10n.modelsRoadmap, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
