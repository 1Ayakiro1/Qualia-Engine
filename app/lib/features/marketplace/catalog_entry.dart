import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/module_strings.dart';

import '../../core/modules/module_registry.dart';
import '../../core/workspace/workspace_repository.dart';

enum MarketplaceKind { extensions, modules, themes, workspaces }

class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.category,
    this.author = 'Community',
    this.tags = const [],
    this.module,
    this.themeMode,
    this.coverUrl,
    this.coverColor = const Color(0xFF35576A),
    this.coverAspectRatio = 1.6,
    this.pattern = 'waves',
    this.iconName = 'module',
    this.downloads,
    this.likes,
    this.createdAt,
    this.updatedAt,
    this.license = 'Unspecified',
    this.workspace,
  });
  final String id;
  final String name;
  final String description;
  final String author;
  final MarketplaceKind kind;
  final String category;
  final List<String> tags;
  final SystemModule? module;
  final ThemeMode? themeMode;
  final String? coverUrl;
  final Color coverColor;

  /// Width / height supplied by the publisher; unknown covers use landscape.
  final double coverAspectRatio;
  final String pattern;
  final String iconName;
  final int? downloads;
  final int? likes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String license;
  final PublishedWorkspace? workspace;
  bool get isPreview => module?.isLocalPreview == true;
  String displayLicense(BuildContext context) =>
      license == 'Unspecified' || license == 'Proprietary'
      ? context.hostLabel(license)
      : license;
  String displayCategory(BuildContext context) =>
      module?.displayCategory(context) ?? context.hostLabel(category);
  String displayName(BuildContext context) =>
      module?.displayName(context) ?? name;
  String displayDescription(BuildContext context) =>
      module?.isLocalPreview == true
      ? context.l10n.previewSummary(module!.displayCategory(context))
      : module == null
      ? context.hostLabel(description)
      : description;
  factory CatalogEntry.fromModule(SystemModule module) {
    final metadata = module.manifest;
    final cover = metadata['cover'] is Map
        ? metadata['cover'] as Map
        : const {};
    final stats = metadata['stats'] is Map
        ? metadata['stats'] as Map
        : const {};
    final rawColor = (cover['color'] is String ? cover['color'] as String : '')
        .replaceFirst('#', '');
    final color = int.tryParse(rawColor, radix: 16);
    final url = cover['image'] is String ? cover['image'] as String : null;
    final ratio = cover['aspectRatio'];
    final width = cover['width'];
    final height = cover['height'];
    final dimensionsRatio =
        width is num &&
            height is num &&
            width.isFinite &&
            height.isFinite &&
            width > 0 &&
            height > 0
        ? width / height
        : null;
    final aspectRatio = ratio is num && ratio.isFinite && ratio > 0
        ? ratio.toDouble()
        : dimensionsRatio ?? 1.6;
    return CatalogEntry(
      id: module.id,
      name: module.name,
      description: module.summary.isEmpty ? module.description : module.summary,
      author: metadata['author'] is String
          ? metadata['author'] as String
          : module.publisher ?? 'Community',
      kind: switch (metadata['kind']) {
        'extension' => MarketplaceKind.extensions,
        'theme' => MarketplaceKind.themes,
        _ => MarketplaceKind.modules,
      },
      category: module.category,
      tags: (metadata['tags'] is List ? metadata['tags'] as List : const [])
          .whereType<String>()
          .take(8)
          .toList(),
      module: module,
      coverUrl: Uri.tryParse(url ?? '')?.scheme == 'https' ? url : null,
      coverAspectRatio: aspectRatio.clamp(.75, 2.4),
      coverColor: color == null
          ? const Color(0xFF35576A)
          : Color(0xFF000000 | color),
      pattern: cover['pattern'] is String
          ? cover['pattern'] as String
          : 'waves',
      iconName: cover['icon'] is String ? cover['icon'] as String : 'module',
      downloads: stats['downloads'] is int ? stats['downloads'] as int : null,
      likes: stats['likes'] is int ? stats['likes'] as int : null,
      createdAt: module.createdAt,
      updatedAt: module.updatedAt,
      license:
          metadata['license'] is String &&
              (metadata['license'] as String).trim().isNotEmpty
          ? (metadata['license'] as String).trim()
          : 'Unspecified',
    );
  }
}

String marketplaceKindLabel(MarketplaceKind kind) => switch (kind) {
  MarketplaceKind.extensions => 'Extensions',
  MarketplaceKind.modules => 'Modules',
  MarketplaceKind.themes => 'Themes',
  MarketplaceKind.workspaces => 'Workspaces',
};

IconData catalogIcon(String name) => switch (name) {
  'signal' => Icons.graphic_eq,
  'workspace' => Icons.account_tree_outlined,
  'brain' => Icons.psychology_outlined,
  'terrain' => Icons.terrain_outlined,
  'notes' => Icons.sticky_note_2_outlined,
  'chart' => Icons.multiline_chart,
  'moon' => Icons.dark_mode_outlined,
  'sun' => Icons.light_mode_outlined,
  _ => Icons.extension_outlined,
};

const engineThemes = [
  CatalogEntry(
    id: 'qualia.theme.dark',
    name: 'Qualia Dark',
    description: 'The engine’s neutral, dark-first appearance. A quiet workspace for focused research.',
    kind: MarketplaceKind.themes,
    category: 'Dark',
    author: 'Qualia Engine',
    tags: ['Dark', 'Built-in'],
    themeMode: ThemeMode.dark,
    coverColor: Color(0xFF384453),
    pattern: 'contours',
    iconName: 'moon',
  ),
  CatalogEntry(
    id: 'qualia.theme.light',
    name: 'Qualia Light',
    description: 'A clean white appearance with the same hierarchy and unified controls.',
    kind: MarketplaceKind.themes,
    category: 'Light',
    author: 'Qualia Engine',
    tags: ['Light', 'Built-in'],
    themeMode: ThemeMode.light,
    coverColor: Color(0xFF9BBAB4),
    pattern: 'waves',
    iconName: 'sun',
  ),
];
