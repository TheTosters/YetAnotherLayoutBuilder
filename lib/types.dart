import 'package:flutter/material.dart' as material;

/// Widget provider signature for YalbBlock node attribute *provider*.
typedef BlockProvider = material.Widget Function(
    material.BuildContext context, String blockName, Map<String, dynamic> data);

/// Signature of provider function which should be used with [YalbWidgetFactory]
typedef FactoryProvider = List<WidgetFactoryItem> Function();

/// Single item definition used by [YalbWidgetFactory] to fabricate [Widget]
class WidgetFactoryItem {
  final String blockName;
  final Map<String, dynamic> injectableData;

  WidgetFactoryItem(this.blockName, this.injectableData);
}
