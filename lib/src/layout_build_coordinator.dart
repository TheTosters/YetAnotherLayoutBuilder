import 'package:processing_tree/processing_tree.dart';

typedef DelegateDataProcessor = dynamic Function(Map<String, dynamic> inData);

class LayoutBuilderItem {
  final String elementName;
  final PNDelegate delegate;
  final ParsedItemType itemType;
  final DelegateDataProcessor dataProcessor;

  LayoutBuilderItem(
      this.elementName, this.delegate, this.dataProcessor, this.itemType);
}

dynamic _nopProcessor(Map<String, dynamic> inData) {
  return inData;
}

Action _returnDataValueDelegate(dynamic context, dynamic data) {
  context.key = data.key;
  context.value = data.value;
  return Action.proceed;
}

class Registry {
  static final Map<String, LayoutBuilderItem> _items = {};

  static void addItem(String elementName, PNDelegate delegate,
      DelegateDataProcessor? dataProcessor, ParsedItemType itemType) {
    dataProcessor ??= _nopProcessor;
    _items[elementName] =
        LayoutBuilderItem(elementName, delegate, dataProcessor, itemType);
  }
}

class LayoutBuildCoordinator implements BuildCoordinator {
  @override
  PNDelegate? delegate(String name) {
    if (name.startsWith("_")) {
      return _returnDataValueDelegate;
    }
    return Registry._items[name]!.delegate;
  }

  @override
  dynamic delegateData(String delegateName, Map<String, dynamic> rawData) {
    if (delegateName.startsWith("_")) {
      return KeyValue(delegateName.substring(1), rawData["value"]);
    }
    return Registry._items[delegateName]!.dataProcessor(rawData);
  }

  @override
  ParsedItemType itemType(String name) {
    if (name.startsWith("_")) {
      return ParsedItemType.constValue;
    }
    return Registry._items[name]!.itemType;
  }
}
