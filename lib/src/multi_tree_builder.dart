import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:xml/xml.dart';

import '../yet_another_layout_builder.dart';

typedef ExtObjectMap = Map<String, dynamic>;
typedef TreeSurMap = Map<String, TreeSurrounding>;
typedef BranchBuilder = void Function(XmlElement root, ExtObjectMap ext);

class TreeSurrounding {
  final TreeProcessor treeProcessor;
  final Map<String, TrackedValue> objectUsageMap;
  final List<List<Widget>> childrenLists;

  TreeSurrounding(this.treeProcessor, this.objectUsageMap, this.childrenLists);

  Widget build(BuildContext buildContext) {
    for (var element in childrenLists) {
      element.clear();
    }
    LayoutBuildContext context = LayoutBuildContext(buildContext);
    treeProcessor.process(context);
    return context.widget!;
  }

  void updateObjects(ExtObjectMap objects) {
    for(var entry in objects.entries) {
      final destQueue = objectUsageMap[entry.key];
      if (destQueue == null) {
        print("WARN updateObjects: Object with key ${entry.key} is given but"
            " it's not used in build widget process.");
        continue;
      }
      for(var d in destQueue) {
        d.destMap[d.keyName] = entry.value;
      }
    }
  }
}

class MultiTreeBuilder {
  final TreeSurMap blocks;

  MultiTreeBuilder(this.blocks);

  TreeSurrounding parse(String xmlStr, ExtObjectMap ext) {
    Map<String, BranchBuilder> builders = {"YalbBlockDef": _blockBuilder};

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
    LayoutBuildCoordinator coordinator = LayoutBuildCoordinator(ext,
            (buildContext, name, data) {
      final blockBuilder = blocks[name]!;
      blockBuilder.updateObjects(data);
      return blockBuilder.build(buildContext);
    });
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coordinator);
    final processor = builder.buildFrom(root).inverted();
    return TreeSurrounding(
        processor, coordinator.objectUsageMap, coordinator.childrenLists);
  }

  void _blockBuilder(XmlElement root, ExtObjectMap ext) {
    final result = _parseWidgetBranch(root.childElements.first, ext);
    final name = root.getAttribute("name");
    if (name == null || name.isEmpty) {
      throw TreeBuilderException(
          "Block def need to have name attribute: ${root.toXmlString()}");
    }
    blocks[name] = result;
  }
}
