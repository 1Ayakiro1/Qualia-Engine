import 'module_registry.dart';

/// Local UI playground, never published to Supabase or executed as packages.
/// A separate namespace keeps these disposable entries clear of real slugs.
final previewModules = List<SystemModule>.generate(24, (index) {
  const names = [
    'Signal Source',
    'Bandpass Filter',
    'Notch Filter',
    'Channel Mixer',
    'FFT Analyzer',
    'Feature Extractor',
    'Artifact Detector',
    'Signal Viewer',
  ];
  const categories = [
    'Acquisition',
    'DSP',
    'DSP',
    'Routing',
    'Analysis',
    'Analysis',
    'ML',
    'Visualization',
  ];
  const licenses = [
    'MIT',
    'Apache-2.0',
    'BSD-3-Clause',
    'GPL-3.0-only',
    'MPL-2.0',
    'LGPL-3.0-only',
    'Proprietary',
    'Unspecified',
  ];
  final variant = index ~/ names.length;
  final type = index % names.length;
  return SystemModule(
    id: 'qualia.preview.module.$index',
    name: '${names[type]}${variant == 0 ? '' : ' ${variant + 1}'} · Preview',
    category: categories[type],
    description: 'Local placeholder for testing the canvas, ports and author UI. No signal processing or package execution.',
    summary:
        'Preview ${categories[type].toLowerCase()} module for UI and Drag & Drop testing.',
    reviewState: 'preview',
    version: '0.0.0-preview',
    manifest: {
      'preview': true,
      'kind': 'module',
      'author': 'Qualia UI Playground',
      'license': licenses[type],
      'tags': ['Preview', licenses[type]],
      'cover': {
        'color': const ['#35576A', '#555070', '#3C665A', '#7A5B42'][index % 4],
        'pattern': const ['waves', 'contours', 'grid'][index % 3],
        'icon': const ['signal', 'brain', 'chart', 'terrain'][index % 4],
        'aspectRatio': const [1.8, 1.0, 1.4, .85][index % 4],
      },
      'ports': {
        'inputs': type == 0 ? <String>[] : ['signal'],
        'outputs': type == 7
            ? <String>[]
            : ['signal', if (type == 4 || type == 5) 'features'],
      },
      'parameters': [
        {
          'id': 'enabled',
          'type': 'toggle',
          'label': 'Enabled',
          'default': true,
        },
        {
          'id': 'gain',
          'type': 'slider',
          'label': 'Gain',
          'min': 0,
          'max': 10,
          'default': 1,
        },
        {
          'id': 'mode',
          'type': 'select',
          'label': 'Mode',
          'options': ['Standard', 'Low latency', 'High precision'],
          'default': 'Standard',
        },
        {
          'id': 'label',
          'type': 'text',
          'label': 'Instance label',
          'default': names[type],
        },
      ],
      'ui': [
        {
          'id': 'notice',
          'type': 'label',
          'label': 'Preview interface — controls store local values only. No executable module is installed.',
        },
        {
          'id': 'gain',
          'type': 'slider',
          'label': 'Gain',
          'min': 0,
          'max': 10,
          'default': 1,
        },
        {
          'id': 'enabled',
          'type': 'toggle',
          'label': 'Enabled',
          'default': true,
        },
      ],
    },
  );
});

final previewExtensions = List<SystemModule>.generate(12, (index) {
  const names = [
    'Signal Notes',
    'Session Browser',
    'Dataset Tools',
    'Research Dashboard',
  ];
  return SystemModule(
    id: 'qualia.preview.extension.$index',
    name: '${names[index % 4]} ${index ~/ 4 + 1} · Preview',
    category: const ['Notes', 'Workflow', 'Data', 'Visualization'][index % 4],
    description: 'Local extension placeholder for catalog and rail layout testing. No external code runs.',
    version: '0.0.0-preview',
    reviewState: 'preview',
    manifest: {
      'preview': true,
      'kind': 'extension',
      'author': 'Qualia UI Playground',
      'license': const [
        'MIT',
        'Apache-2.0',
        'GPL-3.0-only',
        'Proprietary',
      ][index % 4],
      'tags': ['Preview'],
      'cover': {
        'color': const ['#555070', '#35576A', '#3C665A', '#7A5B42'][index % 4],
        'pattern': 'contours',
        'icon': 'notes',
        'aspectRatio': const [1.8, 1.0, 1.4, .85][index % 4],
      },
      'rail': {'icon': 'notes'},
      'ui': [
        {
          'id': 'notice',
          'type': 'label',
          'label': 'Preview extension area for layout testing.',
        },
      ],
    },
  );
});

/// Only the first set is needed in Explorer; all variants remain in the catalog.
final previewWorkspaceModules = previewModules.take(8).toList(growable: false);
