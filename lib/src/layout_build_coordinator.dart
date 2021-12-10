import 'dart:collection';

import 'package:flutter/material.dart' as material;
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:collection/collection.dart';

import '../yet_another_layout_builder.dart';

part "delegates.dart";
part "processors.dart";
part "value_builders.dart";
part "nodes.dart";

/// Widget provider signature for YalbBlock node attribute *provider*.
typedef BlockProvider = material.Widget Function(Map<String, dynamic> data);

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
  final List<material.Widget>? parentChildren; //our siblings

  WidgetData(this.parentChildren, this.builder, this.data);

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
  final bool isContainer; //can have children?

  //This is only meaningful for ConstBuilder
  String? parentName;

  //if we have several items with this same elementName,
  // used for building const values
  LayoutBuilderItem? next;

  LayoutBuilderItem(this.elementName, this.isContainer, this.delegate,
      this.builder, this.dataProcessor, this.itemType);
}

class Registry {
  static final Map<String, LayoutBuilderItem> _items = _registerSpecialNodes();

  static void addWidgetBuilder(String elementName, WidgetBuilder builder,
      {DelegateDataProcessor dataProcessor = _nopProcessor}) {
    _items[elementName] = LayoutBuilderItem(elementName, false,
        _widgetProducerDelegate, builder, dataProcessor, ParsedItemType.owner);
  }

  static void addWidgetContainerBuilder(
      String elementName, WidgetBuilder builder,
      {DelegateDataProcessor dataProcessor = _nopProcessor}) {
    _items[elementName] = LayoutBuilderItem(
        elementName,
        true,
        _widgetConsumeAndProduceDelegate,
        builder,
        dataProcessor,
        ParsedItemType.owner);
  }

  static void addValueBuilder(
      String parentName, String elementName, ConstBuilder builder) {
    final item = LayoutBuilderItem(elementName, false, _constValueDelegate,
        builder, _nopProcessor, ParsedItemType.constValue);
    item.parentName = parentName;
    _items.update(elementName, (existing) {
      item.next = existing;
      return item;
    }, ifAbsent: () => item);
  }

  static void setStyleDataProcessor(DelegateDataProcessor prc) {
    _items.update(
        "YalbStyle",
        (oldItem) => LayoutBuilderItem(oldItem.elementName, oldItem.isContainer,
            oldItem.delegate, oldItem.builder, prc, oldItem.itemType));
  }
}

class LayoutBuildCoordinator extends BuildCoordinator {
  final Map<String, dynamic> objects;
  final Map<String, TrackedValue> objectUsageMap = {};
  final Map<String, Map<String, dynamic>> styles = {};
  final List<List<material.Widget>> childrenLists = [];
  final trueContainerMarker = Object();

  List<WidgetData> containersData = [
    WidgetData(null, _dummyBuilder, {})..children = []
  ];

  LayoutBuildCoordinator(this.objects);

  @override
  void step(BuildAction action, ParsedItem item) {
    if (item.type == ParsedItemType.owner &&
        action == BuildAction.goLevelUp &&
        item.extObj == trueContainerMarker) {
      containersData.removeLast();
    }
  }

  @override
  ParsedItem requestData(BuildPhaseState state) {
    PNDelegate delegate;
    ParsedItemType itemType;
    dynamic outData;
    dynamic extObj;
    if (state.delegateName.startsWith("_")) {
      final name = state.delegateName.substring(1);
      delegate = _findConstDataDelegate(state.parentNodeName, name);
      itemType = ParsedItemType.constValue;

      _resolveExternals(state.data, false);
      //Note: don't call item.dataProcessor for this type of node
      //decision is that builder handle processing + building in one go!
      outData = ConstData(state.parentNodeName, name,
          _findConstDataBuilder(state.parentNodeName, name), state.data);
    } else {
      final item = Registry._items[state.delegateName]!;
      delegate = item.delegate;
      itemType = item.itemType;

      if (item.itemType == ParsedItemType.constValue) {
        //Special nodes
        _resolveExternals(state.data, false);
        if (state.delegateName == "YalbStyle") {
          final converter = _InFlyConverter(item.dataProcessor, styles);
          outData = ConstData(
              state.data["name"], "", _constValueNOPBuilder, converter);
          return ParsedItem.from(state, delegate, outData, itemType);
        }
        throw Exception("Internal error");
      }

      _resolveExternals(state.data, true);
      _applyStyleInfoIfNeeded(state.delegateName, state.data);
      final siblings = containersData.last.children;
      outData =
          WidgetData(siblings, item.builder, item.dataProcessor(state.data));
      if (item.isContainer) {
        outData.children = <material.Widget>[];
        childrenLists.add(outData.children!);
        containersData.add(outData);
        extObj = trueContainerMarker;
      }
    }

    return ParsedItem.from(state, delegate, outData, itemType, extObj:extObj);
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

  PNDelegate _findConstDataDelegate(String parentNodeName, String name) {
    final item = _findBuilderItem(parentNodeName, name);
    return item?.delegate ?? _constValueDelegate;
  }

  ConstBuilder _findConstDataBuilder(String parentNodeName, String name) {
    final item = _findBuilderItem(parentNodeName, name);
    return item?.builder ?? _constValueStringBuilder;
  }

  void _applyStyleInfoIfNeeded(String name, Map<String, dynamic> rawData) {
    final styleName = rawData["_yalbStyle"];
    if (styleName != null) {
      final styleInfo = styles[styleName];
      if (styleInfo != null) {
        rawData.addAll(styleInfo);
      } else {
        print("ERROR xml node '$name' requested yalbStyle named '$styleName'"
            " but this style is not defined");
      }
    }
  }
}

class _InFlyConverter extends DelegatingMap<String, Map<String, dynamic>> {
  final Map<String, Map<String, dynamic>> _map;
  final DelegateDataProcessor dataProcessor;
  _InFlyConverter(this.dataProcessor, this._map) : super(_map);

  @override
  void operator []=(String key, Map<String, dynamic> value) {
    _map[key] = dataProcessor(value);
  }
}
