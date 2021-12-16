import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart';

import 'injector.dart';
import 'layout_builder.dart';
import 'types.dart';

class TreeSurrounding {
  final TreeProcessor treeProcessor;
  final Injector injector;
  final List<List<Widget>> childrenLists;

  TreeSurrounding(this.treeProcessor, this.injector, this.childrenLists);

  Widget build(BuildContext buildContext) {
    for (var element in childrenLists) {
      element.clear();
    }
    LayoutBuildContext context = LayoutBuildContext(buildContext);
    treeProcessor.process(context);
    return context.widget!;
  }

  void updateObjects(ExtObjectMap objects) => injector.reInject(objects);
}
