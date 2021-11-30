import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart';

import 'layout_build_coordinator.dart';

class LayoutBuilder {
  late TreeProcessor _processor;

  LayoutBuilder(String xmlStr) {
    LayoutBuildCoordinator coordinator = LayoutBuildCoordinator();
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coordinator);
    _processor = builder.build(xmlStr).inverted();
  }

  Widget build(BuildContext buildContext) {
    Map<String, dynamic> buffer = {"buildContext":buildContext};
    _processor.process(buffer);
    return buffer["widget"] as Widget;
  }
}