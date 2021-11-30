import 'package:flutter/material.dart' as Material;
import 'package:processing_tree/processing_tree.dart';

import '../yet_another_layout_builder.dart';

typedef DelegateDataProcessor = dynamic Function(Map<String, dynamic> inData);
typedef WidgetBuilder = Material.Widget Function(WidgetData data);

class WidgetData {
  final Map<String, dynamic> data;
  List<Material.Widget>? children;
  late Material.BuildContext buildContext;
  final WidgetBuilder builder;

  WidgetData(this.builder, this.data);

  operator [](String key) => data[key];

  operator []=(String key, dynamic value) => data[key] = value;
}

class LayoutBuilderItem {
  final String elementName;
  final WidgetBuilder builder;
  final ParsedItemType itemType;
  final PNDelegate delegate;
  final DelegateDataProcessor dataProcessor;

  LayoutBuilderItem(this.elementName, this.delegate, this.builder,
      this.dataProcessor, this.itemType);
}

dynamic _nopProcessor(Map<String, dynamic> inData) {
  return inData;
}

Action _returnDataValueDelegate(dynamic context, dynamic data) {
  context.key = data.key;
  context.value = data.value;
  return Action.proceed;
}

Action _widgetProducerDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  wData.children = null;
  lbc.widget = wData.builder(wData);
  lbc.widgets.add(lbc.widget!);
  return Action.proceed;
}

Action _widgetConsumeAndProduceDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  wData.children = lbc.widgets;
  lbc.widget = wData.builder(wData);
  lbc.widgets.clear();
  lbc.widgets.add(lbc.widget!);
  return Action.proceed;
}

class Registry {
  static final Map<String, LayoutBuilderItem> _items = {};

  static void addWidgetBuilder(String elementName, WidgetBuilder _builder) {
    _items[elementName] = LayoutBuilderItem(elementName,
        _widgetProducerDelegate, _builder, _nopProcessor, ParsedItemType.owner);
  }

  static void addWidgetContainerBuilder(
      String elementName, WidgetBuilder _builder) {
    _items[elementName] = LayoutBuilderItem(
        elementName,
        _widgetConsumeAndProduceDelegate,
        _builder,
        _nopProcessor,
        ParsedItemType.owner);
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
    final item = Registry._items[delegateName]!;
    WidgetData result = WidgetData(item.builder, item.dataProcessor(rawData));
    return result;
  }

  @override
  ParsedItemType itemType(String name) {
    if (name.startsWith("_")) {
      return ParsedItemType.constValue;
    }
    return Registry._items[name]!.itemType;
  }
}