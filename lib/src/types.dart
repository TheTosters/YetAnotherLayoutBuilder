typedef DelegateDataProcessor = dynamic Function(Map<String, dynamic> inData);

/// Typedef for arguments which represents external object map given to
/// [LayoutBuilder].
typedef ExtObjectMap = Map<String, dynamic>;

/// Signature of provider function which should be used with [YalbWidgetFactory]
typedef FactoryProvider = List<WidgetFactoryItem> Function();

/// Single item definition used by [YalbWidgetFactory] to fabricate [Widget]
class WidgetFactoryItem {
  final String blockName;
  final Map<String, dynamic> injectableData;

  WidgetFactoryItem(this.blockName, this.injectableData);
}
