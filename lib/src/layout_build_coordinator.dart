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

mixin SemiConstSupport {
  List<ConstData>? semiConsts;

  bool get hasSemiConsts => semiConsts != null;

  void addSemiConst(ConstData cData) {
    semiConsts ??= [];
    semiConsts?.add(cData);
  }
}

class ConstData with SemiConstSupport {
  final String attribName;
  final ConstBuilder builder;
  final String parentName;
  final Map<String, dynamic> data;
  bool isSemiConst;

  ConstData(this.parentName, this.attribName, this.builder, this.data,
      this.isSemiConst);
}

class WidgetData with SemiConstSupport {
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
  final List<WidgetData> _widgetDataStack = [];
  final List<ConstData> _constDataStack = [];
  String constValPath = "";

  LayoutBuildCoordinator(this.injector, this.blockProvider, this.stylist) {
    containersData.add(
        WidgetData(null, blockProvider, stylist, _dummyBuilder, {}, null)
          ..children = []);
  }

  @override
  void step(BuildAction action, ParsedItem item) {
    //Support for: Containers
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
    //Support for: Build attrib path
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
    //support for: SemiConst
    final itemData = item.data;
    if (action == BuildAction.newItem) {
      if (itemData is WidgetData) {
        _widgetDataStack.add(itemData);
      } else if (itemData is ConstData) {
        _constDataStack.add(itemData);
      }
    } else if (action == BuildAction.finaliseItem) {
      if (itemData is WidgetData) {
        final last = _widgetDataStack.removeLast();
        assert(last == itemData);
      } else if (itemData is ConstData) {
        final last = _constDataStack.removeLast();
        assert(last == itemData);
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
      String attribPath = constValPath + "/" + state.delegateName;
      final item = Registry._findByPath(state, attribPath);
      final builder = item?.builder ?? _constValueStringBuilder;
      delegate = item?.delegate ?? _constValueDelegate;
      itemType = ParsedItemType.constValue;

      bool semiConst = injector.inject(state.data, true);
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
      outData =
          ConstData(state.parentNodeName, name, builder, state.data, semiConst);
      if (semiConst) {
        _handleSemiConstTree(outData);
      }
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

  void _handleSemiConstTree(ConstData cData) {
    assert(cData.isSemiConst);
    if (_constDataStack.isEmpty) {
      //This is first constData for given widget. Nothing more need to be done
      //just add this to WidgetData. In [step] function this object will be
      //added to proper stacks, don't do it here!
      _widgetDataStack.last.addSemiConst(cData);
    } else {
      //There is already other ConstData on stack (called Parent), so cData must
      //become a child of it. Two things need to be considered:
      //1) Parent is already semiConst: add cData as child to Parent
      //2) Parent is not a semiConst:
      //    add cData as semiConst child to Parent,
      //    parent also becomes semiConst
      //    repeat above steps until root ConstData is found
      var parent = _constDataStack.last;
      if (parent.isSemiConst) {
        //Case 1
        parent.addSemiConst(cData);
      } else {
        //Case 2
        for (parent in _constDataStack.reversed) {
          parent.addSemiConst(cData);
          if (parent.isSemiConst) {
            //Some other subtree of constData already marked this root as
            //semiConst, we don't need to go deeper
            return;
          }
          parent.isSemiConst = true;
        }
        //If we are here, we traversed constValues stack to the bottom, now
        //parent is a root of whole constVal subtree, add it to widget
        _widgetDataStack.last.addSemiConst(_constDataStack.first);
      }
    }
  }
}
