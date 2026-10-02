import 'package:flutter/widgets.dart';

import '../core/modules/module_registry.dart';
import 'app_strings.dart';

extension LocalModuleStrings on SystemModule {
  // The namespace check matters: a remote author cannot opt into fixture text.
  bool get isLocalPreview =>
      id.startsWith('qualia.preview.') && manifest['preview'] == true;
  String displayName(BuildContext context) =>
      isLocalPreview ? context.previewLabel(name) : name;
  String displayDescription(BuildContext context) =>
      isLocalPreview ? context.previewLabel(description) : description;
  String displayCategory(BuildContext context) =>
      isLocalPreview ? context.previewLabel(category) : category;
}
