import 'package:flutter/material.dart';

import '../common/widgets.dart';

/// Models: no-code training and model registry (v0.2).
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const <Widget>[
        ScreenHeader(
          title: 'Модели',
          subtitle: 'Обучение без кода и реестр моделей',
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.psychology_outlined, size: 48),
                SizedBox(height: 12),
                Text('Реестр моделей пуст'),
                SizedBox(height: 8),
                Text(
                  'v0.2: обучение моделей на датасетах (батчи, кластеры '
                  'спектрограмм), интеграция обученных моделей как Entities, '
                  'экспорт/загрузка в ONNX через Model Registry & Runtime.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
