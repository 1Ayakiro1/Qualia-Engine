import '../../l10n/app_strings.dart';
import '../common/desktop_menu.dart';
import '../../l10n/module_strings.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/modules/module_registry.dart';
import '../../core/modules/module_repository.dart';
import '../../core/modules/module_preview_data.dart';
import '../../core/theme/app_palette.dart';
import '../../state/app_state.dart';
import '../../state/workspace_state.dart';
import '../common/widgets.dart';
import '../common/desktop_scroll.dart';
import 'catalog_entry.dart';
import 'catalog_cover.dart';
import '../../core/workspace/workspace_repository.dart';
import '../modules/workspace_manager.dart';

typedef CatalogPageLoader = Future<List<SystemModule>> Function(
  int offset,
  int limit,
);

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({
    super.key,
    this.loadPage,
    this.includePreviews = true,
    this.loadWorkspacePage,
  });
  final CatalogPageLoader? loadPage;
  final bool includePreviews;
  final Future<List<PublishedWorkspace>> Function(int offset, int limit)?
  loadWorkspacePage;
  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  static const _pageSize = 24;
  final _search = TextEditingController();
  final _scroll = DesktopScrollController(debugLabel: 'marketplace catalog');
  final _filterScroll = DesktopScrollController(
    debugLabel: 'marketplace filters',
  );
  final _entries = <CatalogEntry>[];
  final _liked = <String>{};
  MarketplaceKind _kind = MarketplaceKind.extensions;
  String _category = 'All';
  String _period = 'All time';
  String _license = 'All';
  String _sort = 'Relevance';
  String _view = 'Grid';
  bool _connectedOnly = false;
  bool _loading = false;
  bool _hasMore = true;
  bool _filters = true;
  double _filterWidth = 240;
  bool _filterWidthChanged = false;
  String? _error;
  int _offset = 0;
  bool _workspaceLoading = false;
  bool _workspaceHasMore = true;
  int _workspaceOffset = 0;
  String? _workspaceError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    _load();
    _loadLikes();
    _loadFilterWidth();
  }

  Future<void> _loadFilterWidth() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _filterWidthChanged) return;
    setState(
      () => _filterWidth =
          (prefs.getDouble('qualia.marketplace.filterWidth') ?? 240).clamp(
            200,
            420,
          ),
    );
  }

  Future<void> _saveFilterWidth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('qualia.marketplace.filterWidth', _filterWidth);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _filterScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLikes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(
          () =>
              _liked.addAll(prefs.getStringList('qualia.catalog.likes') ?? []),
        );
      }
    } catch (_) {}
  }

  Future<void> _like(CatalogEntry entry) async {
    setState(() {
      _liked.contains(entry.id)
          ? _liked.remove(entry.id)
          : _liked.add(entry.id);
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('qualia.catalog.likes', _liked.toList());
    } catch (_) {}
  }

  Future<void> _load() async {
    if (_kind == MarketplaceKind.workspaces) return _loadWorkspaces();
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final modules =
          await (widget.loadPage?.call(_offset, _pageSize) ??
              ModuleRepository().listPublishedPage(
                offset: _offset,
                limit: _pageSize,
              ));
      if (!mounted) return;
      setState(() {
        _entries.addAll(
          modules
              .map(CatalogEntry.fromModule)
              .where((entry) => !_entries.any((old) => old.id == entry.id)),
        );
        _offset += modules.length;
        _hasMore = modules.length == _pageSize;
        _loading = false;
      });
      _fillViewport();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'The catalog could not be loaded. Check your connection and try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadWorkspaces() async {
    if (_workspaceLoading || !_workspaceHasMore) return;
    setState(() {
      _workspaceLoading = true;
      _workspaceError = null;
    });
    try {
      final items =
          await (widget.loadWorkspacePage?.call(_workspaceOffset, _pageSize) ??
              WorkspaceRepository().listPublishedPage(
                offset: _workspaceOffset,
                limit: _pageSize,
              ));
      if (!mounted) return;
      setState(() {
        _entries.addAll(
          items
              .where(
                (item) =>
                    !_entries.any((old) => old.id == 'workspace:${item.id}'),
              )
              .map(
                (item) => CatalogEntry(
                  id: 'workspace:${item.id}',
                  name: item.project.name,
                  description: item.project.description,
                  kind: MarketplaceKind.workspaces,
                  category: 'Workspace',
                  author: item.author,
                  license: item.license,
                  createdAt: item.createdAt,
                  iconName: 'workspace',
                  workspace: item,
                ),
              ),
        );
        _workspaceOffset += items.length;
        _workspaceHasMore = items.length == _pageSize;
        _workspaceLoading = false;
      });
      _fillViewport();
    } catch (_) {
      if (mounted) {
        setState(() {
          _workspaceError = 'workspaces';
          _workspaceLoading = false;
        });
      }
    }
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 450) _load();
  }

  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          (_kind == MarketplaceKind.workspaces
              ? _workspaceHasMore
              : _hasMore) &&
          (_kind == MarketplaceKind.workspaces ? _workspaceError : _error) ==
              null &&
          (!_scroll.hasClients || _scroll.position.extentAfter < 450)) {
        _load();
      }
    });
  }

  void _filterChanged(VoidCallback update) {
    setState(update);
    _fillViewport();
  }

  List<CatalogEntry> get _catalog => [
    ..._entries,
    if (widget.includePreviews)
      ...[...previewModules, ...previewExtensions].map(CatalogEntry.fromModule),
    ...engineThemes,
  ];

  List<CatalogEntry> _filtered(Set<String> connected) {
    final items = _catalog.where((entry) {
      final query = _search.text.trim().toLowerCase();
      final cutoff = switch (_period) {
        'This week' => DateTime.now().subtract(const Duration(days: 7)),
        'This month' => DateTime.now().subtract(const Duration(days: 30)),
        _ => null,
      };
      return entry.kind == _kind &&
          (_category == 'All' || entry.category == _category) &&
          (_license == 'All' || entry.license == _license) &&
          (!_connectedOnly ||
              connected.contains(entry.id) ||
              entry.themeMode != null) &&
          (cutoff == null ||
              (entry.createdAt != null && entry.createdAt!.isAfter(cutoff))) &&
          '${entry.displayName(context)} ${entry.author} ${entry.displayDescription(context)} ${entry.tags.join(' ')}'
              .toLowerCase()
              .contains(query);
    }).toList();
    final query = _search.text.trim().toLowerCase();
    int relevance(CatalogEntry entry) => query.isEmpty
        ? 0
        : entry.name.toLowerCase() == query
        ? 3
        : entry.name.toLowerCase().startsWith(query)
        ? 2
        : entry.name.toLowerCase().contains(query)
        ? 1
        : 0;
    items.sort((a, b) {
      final comparison = switch (_sort) {
        'Newest' => (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
          a.createdAt?.millisecondsSinceEpoch ?? 0,
        ),
        'Recently updated' =>
          (b.updatedAt?.millisecondsSinceEpoch ??
                  b.createdAt?.millisecondsSinceEpoch ??
                  0)
              .compareTo(
                a.updatedAt?.millisecondsSinceEpoch ??
                    a.createdAt?.millisecondsSinceEpoch ??
                    0,
              ),
        'Most downloaded' => (b.downloads ?? -1).compareTo(a.downloads ?? -1),
        'Most liked' =>
          ((b.likes ?? 0) + (_liked.contains(b.id) ? 1 : 0)).compareTo(
            (a.likes ?? 0) + (_liked.contains(a.id) ? 1 : 0),
          ),
        'Name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _ => relevance(b).compareTo(relevance(a)),
      };
      return comparison;
    });
    return items;
  }

  Future<void> _details(CatalogEntry entry) async {
    if (entry.workspace != null) {
      final project = entry.workspace!.project;
      final install = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(project.name),
          content: SizedBox(
            width: 490,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.description),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.workspaceGraphSummary(
                      project.nodes.length,
                      project.links.length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('${context.l10n.textLicense103}: ${entry.license}'),
                  const SizedBox(height: 16),
                  Text(context.l10n.workspaceInstallNotice),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.textClose110),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.workspaceInstall),
            ),
          ],
        ),
      );
      if (install != true || !mounted) return;
      try {
        await installWorkspace(context, ref, project);
      } catch (error) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              error is WorkspaceDependencyException
                  ? context.l10n.workspaceDependenciesUnavailable
                  : context.l10n.workspaceOperationFailed,
            ),
            content: Text('$error'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.textClose110),
              ),
            ],
          ),
        );
      }
      return;
    }
    final connected = ref
        .read(workspaceProvider)
        .library
        .any((module) => module.id == entry.id);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          entry.displayName(context),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 490,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CatalogCover(
                      color: entry.coverColor,
                      pattern: entry.pattern,
                      iconName: entry.iconName,
                      imageUrl: entry.coverUrl,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.textByArg0445((entry.author).toString()),
                  style: TextStyle(
                    color: context.palette.mutedText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  entry.module?.displayDescription(context) ??
                      entry.displayDescription(context),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.textLicenseArg0446(
                    entry.displayLicense(context),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (entry.module != null)
                  Text(
                    entry.isPreview
                        ? context.l10n.textLocalUIPlaceholderOnlyThisEntryIs447
                        : context
                              .l10n
                              .textAddThisPublishedManifestToTheWorkspace448,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.textClose110),
          ),
          if (entry.themeMode != null || !connected)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                entry.themeMode != null
                    ? context.l10n.textApplyTheme449
                    : context.l10n.textAddToWorkspace450,
              ),
            ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    if (entry.themeMode != null) {
      ref.read(themeModeProvider.notifier).setThemeMode(entry.themeMode!);
    }
    if (entry.module != null) {
      ref.read(workspaceProvider.notifier).addToLibrary(entry.module!);
      ref
          .read(notificationProvider.notifier)
          .add(
            id: entry.id,
            title: context.l10n.textAddedToWorkspace451,
            message: context.l10n
                .textArg0IsAvailableInExplorerPackageExecution452(
                  entry.displayName(context),
                ),
            icon: Icons.extension_outlined,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _kind == MarketplaceKind.workspaces
        ? _workspaceLoading
        : _loading;
    final error = _kind == MarketplaceKind.workspaces
        ? _workspaceError
        : _error;
    final connected = ref
        .watch(workspaceProvider)
        .library
        .map((module) => module.id)
        .toSet();
    final items = _filtered(connected);
    final categories = <String>{
      'All',
      ..._catalog
          .where((entry) => entry.kind == _kind)
          .map((entry) => entry.category),
    }.toList();
    return ColoredBox(
      color: context.palette.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 740;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.palette.panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final kind in MarketplaceKind.values)
                            DesktopHoverTile(
                              onTap: () => _filterChanged(() {
                                _kind = kind;
                                _category = 'All';
                                _license = 'All';
                              }),
                              selected: kind == _kind,
                              selectedColor: context.palette.hover,
                              borderRadius: BorderRadius.circular(9),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 10 : 17,
                                  vertical: 9,
                                ),
                                child: Text(
                                  kind == MarketplaceKind.workspaces
                                      ? context.l10n.workspacesTitle
                                      : context.hostLabel(
                                          marketplaceKindLabel(kind),
                                        ),
                                  style: TextStyle(
                                    color: kind == _kind
                                        ? context.palette.text
                                        : context.palette.mutedText,
                                    fontSize: 14,
                                    fontWeight: kind == _kind
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact && _filters)
                      SizedBox(
                        width: _filterWidth.clamp(
                          200,
                          math.min(420, constraints.maxWidth * .4),
                        ),
                        child: _filterPanel(categories),
                      ),
                    if (!compact && _filters)
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          key: const ValueKey('marketplace filter resize'),
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragUpdate: (details) => setState(() {
                            _filterWidthChanged = true;
                            _filterWidth = (_filterWidth + details.delta.dx)
                                .clamp(
                                  200,
                                  math.min(420, constraints.maxWidth * .4),
                                );
                          }),
                          onHorizontalDragEnd: (_) => _saveFilterWidth(),
                          child: SizedBox(
                            width: 8,
                            child: Center(
                              child: Container(
                                width: 1,
                                color: context.palette.hover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                            child: Row(
                              children: [
                                if (compact) ...[
                                  DesktopIconButton(
                                    icon: Icons.tune,
                                    tooltip: context.l10n.textFilters453,
                                    onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (_) => Dialog(
                                        child: SizedBox(
                                          width: 340,
                                          height: 580,
                                          child: StatefulBuilder(
                                            builder: (context, update) =>
                                                _filterPanel(
                                                  categories,
                                                  onUpdate: update,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: TextField(
                                    key: const ValueKey(
                                      'marketplace search field',
                                    ),
                                    controller: _search,
                                    style: const TextStyle(fontSize: 14),
                                    onChanged: (_) => _filterChanged(() {}),
                                    decoration: InputDecoration(
                                      hintText: context.l10n.textSearchArg0454(
                                        context
                                            .hostLabel(
                                              marketplaceKindLabel(_kind),
                                            )
                                            .toLowerCase(),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 19,
                                      ),
                                      fillColor: context.palette.panel,
                                      suffixIcon: _search.text.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: context
                                                  .l10n
                                                  .textClearSearch455,
                                              onPressed: () {
                                                _search.clear();
                                                _filterChanged(() {});
                                              },
                                              icon: const Icon(
                                                Icons.close,
                                                size: 17,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (!compact && !_filters)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _filters = true),
                                    icon: const Icon(Icons.tune, size: 15),
                                    label: Text(context.l10n.textFilters453),
                                  ),
                                _catalogSelector(
                                  context.l10n.textSortBy456,
                                  _sort,
                                  const [
                                    'Relevance',
                                    'Newest',
                                    'Recently updated',
                                    'Most downloaded',
                                    'Most liked',
                                    'Name',
                                  ],
                                  (value) =>
                                      _filterChanged(() => _sort = value),
                                ),
                                _catalogSelector(
                                  context.l10n.textView62,
                                  _view,
                                  const ['Grid', 'List'],
                                  (value) =>
                                      _filterChanged(() => _view = value),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, bounds) {
                                final columns = bounds.maxWidth >= 1080
                                    ? 3
                                    : bounds.maxWidth >= 720
                                    ? 2
                                    : 1;
                                return CustomScrollView(
                                  controller: _scroll,
                                  slivers: [
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        20,
                                      ),
                                      sliver: _view == 'List'
                                          ? SliverList(
                                              delegate:
                                                  SliverChildBuilderDelegate(
                                                    (context, index) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 14,
                                                          ),
                                                      child: SizedBox(
                                                        height:
                                                            bounds.maxWidth >=
                                                                660
                                                            ? 256
                                                            : null,
                                                        child: _CatalogCard(
                                                          adaptive:
                                                              bounds.maxWidth <
                                                              660,
                                                          entry: items[index],
                                                          liked: _liked
                                                              .contains(
                                                                items[index].id,
                                                              ),
                                                          connected: connected
                                                              .contains(
                                                                items[index].id,
                                                              ),
                                                          horizontal:
                                                              bounds.maxWidth >=
                                                              660,
                                                          onLike: () => _like(
                                                            items[index],
                                                          ),
                                                          onOpen: () =>
                                                              _details(
                                                                items[index],
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                    childCount: items.length,
                                                  ),
                                            )
                                          : SliverMasonryGrid(
                                              gridDelegate:
                                                  SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: columns,
                                                  ),
                                              crossAxisSpacing: 14,
                                              mainAxisSpacing: 14,
                                              delegate: SliverChildBuilderDelegate(
                                                (
                                                  context,
                                                  index,
                                                ) => _CatalogCard(
                                                  key: ValueKey(
                                                    'catalog card ${items[index].id}',
                                                  ),
                                                  adaptive: true,
                                                  entry: items[index],
                                                  liked: _liked.contains(
                                                    items[index].id,
                                                  ),
                                                  connected: connected.contains(
                                                    items[index].id,
                                                  ),
                                                  onLike: () =>
                                                      _like(items[index]),
                                                  onOpen: () =>
                                                      _details(items[index]),
                                                ),
                                                childCount: items.length,
                                              ),
                                            ),
                                    ),
                                    if (error != null)
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            children: [
                                              Text(
                                                _kind ==
                                                        MarketplaceKind
                                                            .workspaces
                                                    ? context
                                                          .l10n
                                                          .workspaceCatalogUnavailable
                                                    : context.hostLabel(error),
                                                style: TextStyle(
                                                  color:
                                                      context.palette.mutedText,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: _load,
                                                child: Text(
                                                  context.l10n.textRetry458,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (loading)
                                      const SliverToBoxAdapter(
                                        child: Padding(
                                          padding: EdgeInsets.all(24),
                                          child: Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (items.isEmpty &&
                                        !loading &&
                                        error == null)
                                      SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.storefront_outlined,
                                                  size: 38,
                                                  color:
                                                      context.palette.mutedText,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  _search.text.isEmpty &&
                                                          _category == 'All'
                                                      ? context.l10n
                                                            .textNoPublishedArg0Yet459(
                                                              context
                                                                  .hostLabel(
                                                                    marketplaceKindLabel(
                                                                      _kind,
                                                                    ),
                                                                  )
                                                                  .toLowerCase(),
                                                            )
                                                      : context
                                                            .l10n
                                                            .textNoMatchingItems460,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  context
                                                      .l10n
                                                      .textPublishedCatalogEntriesWillAppearHereAutomatically461,
                                                  style: TextStyle(
                                                    color: context
                                                        .palette
                                                        .mutedText,
                                                    fontSize: 14,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _catalogSelector(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) => DesktopMenuButton<String>(
    tooltip: context.hostLabel(label),
    onSelected: onChanged,
    entries: [
      for (final option in options)
        DesktopMenuEntry(value: option, label: context.hostLabel(option)),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.textArg0Arg1462(
              context.hostLabel(label),
              context.hostLabel(value),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );

  String _categoryLabel(String category) {
    if (category == 'All') return context.hostLabel(category);
    final entries = _catalog
        .where((entry) => entry.kind == _kind && entry.category == category)
        .toList();
    // Never translate an author's category because it matches a fixture label.
    return entries.isNotEmpty &&
            entries.every((entry) => entry.isPreview || entry.module == null)
        ? entries.first.displayCategory(context)
        : category;
  }

  Widget _filterPanel(List<String> categories, {StateSetter? onUpdate}) {
    final licenses =
        _catalog
            .where((entry) => entry.kind == _kind)
            .map((entry) => entry.license)
            .toSet()
            .toList()
          ..sort();
    return Scrollbar(
      controller: _filterScroll,
      child: ListView(
        key: const ValueKey('marketplace filters scroll'),
        controller: _filterScroll,
        primary: false,
        padding: const EdgeInsets.fromLTRB(20, 8, 0, 20),
        children: [
          DesktopPane(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.textFilters453,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DesktopIconButton(
                    icon: Icons.restart_alt,
                    tooltip: context.l10n.textResetFilters463,
                    size: 26,
                    onPressed: () {
                      _filterChanged(() {
                        _category = 'All';
                        _period = 'All time';
                        _license = 'All';
                        _connectedOnly = false;
                      });
                      onUpdate?.call(() {});
                    },
                  ),
                  if (onUpdate == null)
                    DesktopIconButton(
                      icon: Icons.chevron_left,
                      tooltip: context.l10n.textToggleFilters464,
                      size: 26,
                      onPressed: () => setState(() => _filters = false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _filterBlock(
            _kind == MarketplaceKind.themes
                ? context.l10n.textAppearance362
                : context.l10n.textCategory190,
            [
              for (final category in categories)
                _FilterOption(
                  label: _categoryLabel(category),
                  selected: category == _category,
                  onTap: () {
                    _filterChanged(() => _category = category);
                    onUpdate?.call(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          _filterBlock(context.l10n.textLicense103, [
            DesktopSelectField<String>(
              key: const ValueKey('marketplace license filter'),
              label: context.l10n.textLicense103,
              showLabel: false,
              valueLabel: context.hostLabel(_license),
              entries: [
                for (final license in ['All', ...licenses])
                  DesktopMenuEntry(
                    value: license,
                    label: context.hostLabel(license),
                  ),
              ],
              onSelected: (license) {
                _filterChanged(() => _license = license);
                onUpdate?.call(() {});
              },
            ),
          ]),
          const SizedBox(height: 12),
          _filterBlock(context.l10n.textPublished465, [
            for (final period in ['All time', 'This month', 'This week'])
              _FilterOption(
                label: context.hostLabel(period),
                selected: _period == period,
                onTap: () {
                  _filterChanged(() => _period = period);
                  onUpdate?.call(() {});
                },
              ),
          ]),
          if (_kind != MarketplaceKind.workspaces) ...[
            const SizedBox(height: 12),
            _filterBlock(context.l10n.textAvailability466, [
              _FilterOption(
                label: _kind == MarketplaceKind.themes
                    ? context.l10n.textBuiltInConnected467
                    : context.l10n.textInWorkspace468,
                selected: _connectedOnly,
                onTap: () {
                  _filterChanged(() => _connectedOnly = !_connectedOnly);
                  onUpdate?.call(() {});
                },
              ),
              if (widget.includePreviews)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    context.l10n.textPreviewEntriesAreLocalUIPlaceholdersNot469,
                    style: TextStyle(
                      color: context.palette.mutedText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _filterBlock(String title, List<Widget> children) => DesktopPane(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 6),
            children[index],
          ],
        ],
      ),
    ),
  );
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => DesktopHoverTile(
    onTap: onTap,
    selected: selected,
    selectedColor: context.palette.hover,
    borderRadius: BorderRadius.circular(7),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check : Icons.circle_outlined,
            size: 14,
            color: selected ? context.palette.text : context.palette.mutedText,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? context.palette.text
                    : context.palette.mutedText,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    super.key,
    required this.entry,
    required this.liked,
    required this.connected,
    required this.onLike,
    required this.onOpen,
    this.horizontal = false,
    this.adaptive = false,
  });
  final CatalogEntry entry;
  final bool liked;
  final bool connected;
  final VoidCallback onLike;
  final VoidCallback onOpen;
  final bool horizontal;
  final bool adaptive;
  Widget _fill(Widget child) => adaptive ? child : Expanded(child: child);
  String _count(BuildContext context, int? count) => count == null
      ? '—'
      : NumberFormat.compact(locale: context.l10n.localeName).format(count);
  String _date(BuildContext context, DateTime? date) => date == null
      ? (entry.themeMode != null ? context.hostLabel('Built-in') : '—')
      : DateFormat.yMMMd(context.l10n.localeName).format(date.toLocal());
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: DesktopHoverTile(
      onTap: onOpen,
      color: context.palette.panel,
      hoverColor: context.palette.hover,
      borderRadius: BorderRadius.circular(12),
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cover(
            Stack(
              fit: StackFit.expand,
              children: [
                CatalogCover(
                  color: entry.coverColor,
                  pattern: entry.pattern,
                  iconName: entry.iconName,
                  imageUrl: entry.coverUrl,
                ),
                if (connected)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _fill(
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
              child: Column(
                mainAxisSize: adaptive ? MainAxisSize.min : MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        catalogIcon(entry.iconName),
                        size: 22,
                        color: context.palette.text,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName(context),
                              maxLines: adaptive ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.textByArg0445(
                                (entry.author).toString(),
                              ),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.palette.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _fill(
                    Text(
                      entry.displayDescription(context),
                      maxLines: adaptive ? 4 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.mutedText,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (adaptive) const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final tag in {
                          entry.displayCategory(context),
                          ...entry.tags,
                          entry.license,
                        }.take(4))
                          Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.background,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              tag == entry.license
                                  ? entry.displayLicense(context)
                                  : entry.isPreview
                                  ? context.previewLabel(tag)
                                  : entry.module == null
                                  ? context.hostLabel(tag)
                                  : tag,
                              style: TextStyle(
                                color: context.palette.mutedText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 14,
                        color: context.palette.mutedText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _count(context, entry.downloads),
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 7),
                      DesktopIconButton(
                        icon: liked ? Icons.favorite : Icons.favorite_border,
                        tooltip: context.l10n.textLikeArg0470(
                          entry.displayName(context),
                        ),
                        onPressed: onLike,
                        iconSize: 14,
                        size: 22,
                      ),
                      Text(
                        entry.likes == null
                            ? (liked ? '1' : '—')
                            : _count(context, entry.likes! + (liked ? 1 : 0)),
                        style: TextStyle(
                          color: context.palette.mutedText,
                          fontSize: 14,
                        ),
                      ),
                      Tooltip(
                        message: context.l10n.textCreatedArg0UpdatedArg1471(
                          _date(context, entry.createdAt),
                          _date(context, entry.updatedAt),
                        ),
                        child: Text(
                          _date(context, entry.updatedAt ?? entry.createdAt),
                          style: TextStyle(
                            color: context.palette.mutedText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _cover(Widget child) {
    final cover = AspectRatio(
      key: ValueKey('catalog cover ${entry.id}'),
      aspectRatio: 16 / 9,
      child: RepaintBoundary(child: child),
    );
    return horizontal
        ? SizedBox(width: 230, child: Center(child: cover))
        : cover;
  }
}
