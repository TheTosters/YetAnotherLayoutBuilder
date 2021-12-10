import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart';

import 'layout_build_coordinator.dart';

class LayoutBuildContext {
  final BuildContext buildContext;
  Widget? widget; //Last returned widget

  LayoutBuildContext(this.buildContext);
}

class LayoutBuilder {
  late TreeProcessor _processor;
  late Map<String, TrackedValue> objectUsageMap;
  late List<List<Widget>> childrenLists;

  LayoutBuilder(String xmlStr, Map<String, dynamic> objects) {
    LayoutBuildCoordinator coordinator = LayoutBuildCoordinator(objects);
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coordinator);
    _processor = builder.build(xmlStr).inverted();
    objectUsageMap = coordinator.objectUsageMap;
    childrenLists = coordinator.childrenLists;
    _warnAboutUnusedObjects(objects);
  }

  void updateObjects(Map<String, dynamic> objects) {
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

  Widget build(BuildContext buildContext) {
    for (var element in childrenLists) {
      element.clear();
    }
    LayoutBuildContext context = LayoutBuildContext(buildContext);
    _processor.process(context);
    return context.widget!;
  }

  void _warnAboutUnusedObjects(Map<String, dynamic> objects) {
    var diff = objects.keys.toSet().difference(objectUsageMap.keys.toSet());
    for(var key in diff) {
      print("WARN Object with key '$key' is given, but it's not used in widget build");
    }
  }
}
