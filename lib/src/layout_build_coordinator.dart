import 'package:collection/src/iterable_extensions.dart';
import 'package:flutter/material.dart' as material;
import 'package:processing_tree/processing_tree.dart';

import 'block_builder.dart';
import 'injector.dart';
import 'layout_builder.dart';
import 'stylist.dart';
import 'types.dart';

part 'delegates.dart';

part 'nodes.dart';

part 'processors.dart';

part 'value_builders.dart';

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
  final BlockBuilder blockBuilder;
  final Stylist stylist;

  //knows how convert rawData values from string to proper types
  final DelegateDataProcessor? paramProcessor;
  final List<material.Widget>? parentChildren; //our siblings

  WidgetData(this.parentChildren, this.blockBuilder, this.stylist, this.builder,
      this.data, this.paramProcessor);

  operator [](String key) => data[key];

  operator []=(String key, dynamic value) => data[key] = value;
}

class LayoutBuilderItem {
  final String elementName;
  final dynamic builder; //WidgetBuilder or ConstBuilder
  final ParsedItemType itemType;
  final PNDelegate delegate;
  final DelegateDataProcessor dataProcessor;
  final bool isContainer; //can have children?
  //special case, when more then one constValue with this same destAttirbute is
  // given but different types can be found. Used in YalbStyle
  final String? underlyingType;

  //This is only meaningful for ConstBuilder
  String? parentName;

  //if we have several items with this same elementName,
  // used for building const values
  LayoutBuilderItem? next;

  LayoutBuilderItem(this.elementName, this.isContainer, this.delegate,
      this.builder, this.dataProcessor, this.itemType)
      : underlyingType = null;

  LayoutBuilderItem.withType(this.elementName, this.isContainer, this.delegate,
      this.builder, this.dataProcessor, this.itemType, this.underlyingType);
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
    int idx = elementName.indexOf("/");
    LayoutBuilderItem item;
    if (idx > 0) {
      final extraType = elementName.substring(idx + 1);
      item = LayoutBuilderItem.withType(
          elementName.substring(0, idx),
          false,
          _constValueDelegate,
          builder,
          _nopProcessor,
          ParsedItemType.constValue,
          extraType);
    } else {
      item = LayoutBuilderItem(elementName, false, _constValueDelegate, builder,
          _nopProcessor, ParsedItemType.constValue);
    }

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
  final Injector injector;
  final Stylist stylist;
  final List<List<material.Widget>> childrenLists = [];
  final trueContainerMarker = Object();
  final BlockBuilder blockProvider;
  List<WidgetData> containersData = [];

  LayoutBuildCoordinator(this.injector, this.blockProvider, this.stylist) {
    containersData.add(
        WidgetData(null, blockProvider, stylist, _dummyBuilder, {}, null)
          ..children = []);
  }

  @override
  void step(BuildAction action, ParsedItem item) {
    if (item.type == ParsedItemType.owner &&
        item.extObj == trueContainerMarker) {
      if (action == BuildAction.goLevelUp) {
        containersData.removeLast();
      }
      if (action == BuildAction.finaliseItem) {
        //This is needed to process constValues of unresolved primitive types
        //like int, double, bool collected from constValues
        final parseItem = Registry._items[item.name]!;
        parseItem.dataProcessor(item.data.data);
      }
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
      final item = _findBuilderItem(state, name);
      final builder = item?.builder ?? _constValueStringBuilder;
      delegate = item?.delegate ?? _constValueDelegate;
      itemType = ParsedItemType.constValue;

      injector.inject(state.data, false);
      String? ctrMarker;
      state.data.removeWhere((key, value) {
        final toDelete = key.startsWith("__");
        if (toDelete && value?.isNotEmpty) {
          ctrMarker = value;
        }
        return toDelete;
      });
      if (ctrMarker != null) {
        state.data["_ctr"] = ctrMarker;
      }
      //Note: don't call item.dataProcessor for this type of node
      //decision is that builder handle processing + building in one go!
      outData = ConstData(state.parentNodeName, name, builder, state.data);
    } else {
      final item = Registry._items[state.delegateName]!;
      delegate = item.delegate;
      itemType = item.itemType;

      injector.inject(state.data, true);
      final siblings = containersData.last.children;
      outData = WidgetData(siblings, blockProvider, stylist, item.builder,
          item.dataProcessor(state.data), item.dataProcessor);
      if (item.isContainer) {
        outData.children = <material.Widget>[];
        childrenLists.add(outData.children!);
        containersData.add(outData);
        extObj = trueContainerMarker;
      }
    }

    return ParsedItem.from(state, delegate, outData, itemType, extObj: extObj);
  }

  LayoutBuilderItem? _findBuilderItemByParentType(
      LayoutBuilderItem? chain, String parent, String wantedType) {
    while (chain != null) {
      if (chain.parentName == parent && chain.underlyingType == wantedType) {
        return chain;
      }
      chain = chain.next;
    }
    return null;
  }

  LayoutBuilderItem? _findBuilderItemByParent(
      LayoutBuilderItem? chain, String parent) {
    while (chain != null) {
      if (chain.parentName == parent) {
        return chain;
      }
      chain = chain.next;
    }
    return null;
  }

  LayoutBuilderItem? _findBuilderItem(BuildPhaseState state, String name) {
    var chain = Registry._items[name];
    if (chain == null) {
      return null;
    }
    final parent = state.parentNodeName;
    if (parent != "YalbStyle") {
      return _findBuilderItemByParent(chain, parent);
    }

    String? wantedType =
        state.data.keys.firstWhereOrNull((element) => element.startsWith("__"));
    if (wantedType != null) {
      wantedType = wantedType.substring(2);
      return _findBuilderItemByParentType(chain, parent, wantedType);
    } else {
      //No type specified, fallback to parent+name search
      return _findBuilderItemByParent(chain, parent);
    }
  }
}
