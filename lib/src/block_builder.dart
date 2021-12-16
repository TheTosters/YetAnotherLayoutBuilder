import 'package:flutter/material.dart';
import 'layout_build_coordinator.dart';
import 'tree_surrounding.dart';
import 'types.dart';

class BlockBuilder {
  final Map<String, TreeSurrounding> _blocks = {};

  void add(String name, TreeSurrounding block) => _blocks[name] = block;

  Widget build(String blockName, WidgetData wData, ExtObjectMap injectable) {
    final blockBuilder = _blocks[blockName];
    if (blockBuilder == null) {
      throw Exception("Requested to build unknown block named: $blockName");
    }
    blockBuilder.updateObjects(injectable);
    return blockBuilder.build(wData.buildContext);
  }
}