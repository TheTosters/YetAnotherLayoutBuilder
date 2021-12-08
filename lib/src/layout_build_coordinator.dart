import 'dart:collection';

import 'package:flutter/material.dart' as material;
import 'package:processing_tree/processing_tree.dart';

import '../yet_another_layout_builder.dart';

typedef DelegateDataProcessor = dynamic Function(Map<String, dynamic> inData);
typedef WidgetBuilder = material.Widget Function(WidgetData data);
typedef ConstBuilder = dynamic Function(
    String parent, Map<String, dynamic> data);

class ConstData {
  final String attribName;
  final ConstBuilder builder;
  final String parentName;
  final Map<String, dynamic> data;

  ConstData(this.parentName, this.attribName, this.builder, this.data);
}

class WidgetData {
  final Map<String, dynamic> data;
  List<material.Widget>? children;
  late material.BuildContext buildContext;
  final WidgetBuilder builder;

  WidgetData(this.builder, this.data);

  operator [](String key) => data[key];

  operator []=(String key, dynamic value) => data[key] = value;
}

class TrackedValueIterator implements Iterator<TrackedValue> {
  TrackedValue _cur;

  TrackedValueIterator(TrackedValue first)
      : _cur = TrackedValue("", const {}, first);

  @override
  TrackedValue get current => _cur;

  @override
  bool moveNext() {
    if (_cur.next != null) {
      _cur = _cur.next!;
      return true;
    }
    return false;
  }
}

class TrackedValue with IterableMixin<TrackedValue> {
  final Map<String, dynamic> destMap;
  final String keyName;
  final TrackedValue? next;

  TrackedValue(this.keyName, this.destMap, this.next);

  @override
  Iterator<TrackedValue> get iterator => TrackedValueIterator(this);
}

class LayoutBuilderItem {
  final String elementName;
  final dynamic builder; //WidgetBuilder or ConstBuilder
  final ParsedItemType itemType;
  final PNDelegate delegate;
  final DelegateDataProcessor dataProcessor;

  //This is only meaningful for ConstBuilder
  String? parentName;

  //if we have several items with this same elementName,
  // used for building const values
  LayoutBuilderItem? next;

  LayoutBuilderItem(this.elementName, this.delegate, this.builder,
      this.dataProcessor, this.itemType);
}

dynamic _nopProcessor(Map<String, dynamic> inData) {
  return inData;
}

/// Const Value Builder for handling String const value nodes
///
/// Should be used for nodes which start with '_' and considered as String
/// data node which should be converted into data in parent for example
/// ```xml
/// <Text>
///   <_data text="this is text"/>
/// </Text>
/// ```
/// This builder can be used for '_data' node from above example. It supports
/// attribute which can be named _value_, _data_ or _text_
dynamic _constValueStringBuilder(String parent, Map<String, dynamic> data) {
  return data["value"] ?? data["data"] ?? data["text"];
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

Action _constValueDelegate(dynamic context, dynamic data) {
  KeyValue ctx = context;
  final ConstData cData = data;
  ctx.key = cData.attribName;
  ctx.value = cData.builder(cData.parentName, cData.data);
  return Action.proceed;
}

Action _widgetConsumeAndProduceDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  wData.children = List.from(lbc.widgets, growable: false);
  lbc.widget = wData.builder(wData);
  lbc.widgets.clear();
  lbc.widgets.add(lbc.widget!);
  return Action.proceed;
}

class Registry {
  static final Map<String, LayoutBuilderItem> _items = {};

  static void addWidgetBuilder(String elementName, WidgetBuilder builder,
      {DelegateDataProcessor dataProcessor = _nopProcessor}) {
    _items[elementName] = LayoutBuilderItem(elementName,
        _widgetProducerDelegate, builder, dataProcessor, ParsedItemType.owner);
  }

  static void addWidgetContainerBuilder(
      String elementName, WidgetBuilder builder) {
    _items[elementName] = LayoutBuilderItem(
        elementName,
        _widgetConsumeAndProduceDelegate,
        builder,
        _nopProcessor,
        ParsedItemType.owner);
  }

  static void addValueBuilder(
      String parentName, String elementName, ConstBuilder builder) {
    final item = LayoutBuilderItem(elementName, _constValueDelegate, builder,
        _nopProcessor, ParsedItemType.constValue);
    item.parentName = parentName;
    _items.update(elementName, (existing) => existing.next = item,
        ifAbsent: () => item);
  }
}

class LayoutBuildCoordinator extends BuildCoordinator {
  final Map<String, dynamic> objects;
  final Map<String, TrackedValue> objectUsageMap = {};

  LayoutBuildCoordinator(this.objects);

  @override
  PNDelegate? delegate(String name) {
    if (name.startsWith("_")) {
      return _findConstDataDelegate(name.substring(1));
    }
    return Registry._items[name]!.delegate;
  }

  @override
  dynamic delegateData(String delegateName, Map<String, dynamic> rawData) {
    if (delegateName.startsWith("_")) {
      _resolveExternals(rawData, false);
      final name = delegateName.substring(1);
      //Note: don't call item.dataProcessor for this type of node
      //decision is that builder handle processing + building in one go!
      return ConstData(
          parentNodeName, name, _findConstDataBuilder(name), rawData);
    }
    _resolveExternals(rawData, true);
    final item = Registry._items[delegateName]!;
    WidgetData result = WidgetData(item.builder, item.dataProcessor(rawData));
    return result;
  }

  void _resolveExternals(Map<String, dynamic> rawData, bool track) {
    //Expect that values in rawData is always String at this moment
    rawData.updateAll((key, value) {
      if (value.startsWith("\$")) {
        //resolve as string
        return _processResolvable(value.substring(1), key, rawData, track)
            .toString();

      } else if (value.startsWith("@")) {
        //resolve as object itself
        return _processResolvable(value.substring(1), key, rawData, track);
      }
      return value;
    });
  }

  dynamic _processResolvable(String objName, String inMapKey,
      Map<String, dynamic> destMap, bool trackResolved) {
    if (trackResolved) {
      objectUsageMap.update(
          objName, (value) => TrackedValue(inMapKey, destMap, value),
          ifAbsent: () => TrackedValue(inMapKey, destMap, null));
    }
    if (!objects.containsKey(objName)) {
      print("WARN xml refers to key $objName, but it's not given in objects");
    }
    return objects[objName];
  }

  @override
  ParsedItemType itemType(String name) {
    if (name.startsWith("_")) {
      return ParsedItemType.constValue;
    }
    return Registry._items[name]!.itemType;
  }

  LayoutBuilderItem? _findBuilderItem(String parent, String name) {
    var item = Registry._items[name];
    while (item != null) {
      if (item.parentName == parent) {
        return item;
      }
      item = item.next;
    }
    return null;
  }

  PNDelegate _findConstDataDelegate(String name) {
    final item = _findBuilderItem(parentNodeName, name);
    return item?.delegate ?? _constValueDelegate;
  }

  ConstBuilder _findConstDataBuilder(String name) {
    final item = _findBuilderItem(parentNodeName, name);
    return item?.builder ?? _constValueStringBuilder;
  }
}
