import 'package:flutter/material.dart';

import '../common/widgets.dart';

/// Datasets: upload/create/compare (researcher toolset, v0.2).
class DatasetsScreen extends StatelessWidget {
  const DatasetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const <Widget>[
        ScreenHeader(
          title: 'Датасеты',
          subtitle: 'Загрузка, формирование и сравнение записей',
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.folder_copy_outlined, size: 48),
                SizedBox(height: 12),
                Text('Здесь появятся ваши датасеты'),
                SizedBox(height: 8),
                Text(
                  'v0.2: импорт сессий и внешних файлов (EDF/CSV), '
                  'группировка по экспериментам, теги, сравнение датасетов '
                  'и сессий — всё без написания кода.',
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
