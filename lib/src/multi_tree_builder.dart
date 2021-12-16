import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:xml/xml.dart';
import 'package:yet_another_layout_builder/src/block_builder.dart';

import 'injector.dart';
import 'layout_build_coordinator.dart';
import 'stylist.dart';
import 'tree_surrounding.dart';
import 'types.dart';

typedef BranchBuilder = void Function(XmlElement root, ExtObjectMap ext);

class MultiTreeBuilder {
  final BlockBuilder blockProvider;
  final Stylist stylist = Stylist();

  MultiTreeBuilder(this.blockProvider);

  TreeSurrounding parse(String xmlStr, ExtObjectMap ext) {
    Map<String, BranchBuilder> builders = {
      "YalbBlockDef": _blockBuilder,
      "YalbStyle": _styleBuilder
    };

    final xmlDoc = XmlDocument.parse(xmlStr);
    TreeSurrounding? layoutTree;
    if (xmlDoc.rootElement.name.toString() == "YalbTree") {
      for (var node in xmlDoc.rootElement.childElements) {
        BranchBuilder? builder = builders[node.name.toString()];
        if (builder != null) {
          builder(node, ext);
        } else {
          if (layoutTree != null) {
            throw TreeBuilderException(
                "There can't be more then one root Widget.");
          }
          layoutTree = _parseWidgetBranch(node, ext);
        }
      }
    } else {
      layoutTree = _parseWidgetBranch(xmlDoc.rootElement, ext);
    }

    if (layoutTree == null) {
      throw TreeBuilderException("There must be one root Widget.");
    }
    return layoutTree;
  }

  TreeSurrounding _parseWidgetBranch(XmlElement root, ExtObjectMap ext) {
    final injector = Injector(ext);
    LayoutBuildCoordinator coordinator = LayoutBuildCoordinator(injector,
           blockProvider, stylist);
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coordinator);
    final processor = builder.buildFrom(root).inverted();
    return TreeSurrounding(
        processor, injector, coordinator.childrenLists);
  }

  void _blockBuilder(XmlElement root, ExtObjectMap ext) {
    final result = _parseWidgetBranch(root.childElements.first, ext);
    final name = root.getAttribute("name");
    if (name == null || name.isEmpty) {
      throw TreeBuilderException(
          "Block def need to have 'name' attribute: ${root.toXmlString()}");
    }
    blockProvider.add(name, result);
  }

  void _styleBuilder(XmlElement root, ExtObjectMap ext) {
    final name = root.getAttribute("name");
    if (name == null || name.isEmpty) {
      throw TreeBuilderException(
          "Style need to have 'name' attribute: ${root.toXmlString()}");
    }

    final injector = Injector(ext);
    LayoutBuildCoordinator coordinator = LayoutBuildCoordinator(injector,
            blockProvider, stylist);
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coordinator);
    final processor = builder.buildFrom(root).inverted();
    KeyValue tmp = KeyValue("", null);
    processor.process(tmp);
    tmp.value.remove("name"); //remove name attribute, it's name of style
    stylist.add(name, tmp.value);
  }
}
