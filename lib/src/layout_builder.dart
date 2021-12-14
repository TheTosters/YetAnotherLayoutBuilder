import 'package:flutter/material.dart';

import 'multi_tree_builder.dart';

class LayoutBuildContext {
  final BuildContext buildContext;
  Widget? widget; //Last returned widget

  LayoutBuildContext(this.buildContext);
}

class LayoutBuilder {
  late TreeSurrounding rootWidgetBuilder;
  final TreeSurMap blocks = {};

  LayoutBuilder(String xmlStr, Map<String, dynamic> objects) {
    MultiTreeBuilder mBuilder = MultiTreeBuilder(blocks);
    rootWidgetBuilder = mBuilder.parse(xmlStr, objects);
    _warnAboutUnusedObjects(objects);
  }

  void updateObjects(Map<String, dynamic> objects) {
    rootWidgetBuilder.updateObjects(objects);
  }

  Widget build(BuildContext buildContext) {
    return rootWidgetBuilder.build(buildContext);
  }

  void _warnAboutUnusedObjects(Map<String, dynamic> objects) {
    var diff = objects.keys
        .toSet()
        .difference(rootWidgetBuilder.objectUsageMap.keys.toSet());
    for (var key in diff) {
      print(
          "WARN Object with key '$key' is given, but it's not used in widgets");
    }
  }
}
