import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart';

import 'layout_build_coordinator.dart';

class LayoutBuildContext {
  final BuildContext buildContext;
  Widget? widget; //Last returned widget
  List<Widget> widgets = []; //returned widgets are collected here

  LayoutBuildContext(this.buildContext);
}

class LayoutBuilder {
  late TreeProcessor _processor;

  LayoutBuilder(String xmlStr, Map<String, dynamic> objects) {
    LayoutBuildCoordinator coordinator = LayoutBuildCoordinator(objects);
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coordinator);
    _processor = builder.build(xmlStr).inverted();
  }

  Widget build(BuildContext buildContext) {
    LayoutBuildContext context = LayoutBuildContext(buildContext);
    _processor.process(context);
    return context.widget!;
  }
}
