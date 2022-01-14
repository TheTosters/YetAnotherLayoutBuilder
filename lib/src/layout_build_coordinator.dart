import 'package:collection/collection.dart';
import 'package:flutter/material.dart' as material;
import 'package:processing_tree/processing_tree.dart';
import 'package:yet_another_layout_builder/src/builder/dart_extensions.dart';

import 'block_builder.dart';
import 'injector.dart';
import 'layout_builder.dart';
import 'stylist.dart';
import 'types.dart';

part 'delegates.dart';

part 'nodes.dart';

part 'processors.dart';

part 'registry.dart';

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

class LayoutBuildCoordinator extends BuildCoordinator {
  final Injector injector;
  final Stylist stylist;
  final List<List<material.Widget>> childrenLists = [];
  final trueContainerMarker = Object();
  final BlockBuilder blockProvider;
  List<WidgetData> containersData = [];
  String constValPath = "";

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
    //Build attrib path
    if (action == BuildAction.newItem) {
      if (item.type == ParsedItemType.owner) {
        constValPath = item.name;
      } else if (item.type == ParsedItemType.constValue) {
        constValPath =
            constValPath.isEmpty ? item.name : constValPath + "/" + item.name;
      }
    } else if (action == BuildAction.finaliseItem &&
        item.type == ParsedItemType.constValue) {
      final idx = constValPath.lastIndexOf("/");
      constValPath =
          idx < 0 ? "" : constValPath = constValPath.substring(0, idx);
    }
  }

  @override
  ParsedItem requestData(BuildPhaseState state) {
    PNDelegate delegate;
    ParsedItemType itemType;
    dynamic outData;
    dynamic extObj;
    if (state.delegateName.startsWith("_")) {
      String attribPath = constValPath + "/" + state.delegateName;
      final item = Registry._findByPath(state, attribPath);
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
      final name = state.delegateName.substring(1);
      outData = ConstData(state.parentNodeName, name, builder, state.data);
    } else {
      final item = Registry._findByName(state)!;
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
}
