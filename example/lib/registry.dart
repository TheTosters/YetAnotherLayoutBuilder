import 'package:flutter/material.dart';
import 'package:processing_tree/processing_tree.dart' as ProcTree;
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';

void registerItems() {
  Registry.addItem("Center", _center, null, ProcTree.ParsedItemType.owner);
  Registry.addItem("Text", _text, null, ProcTree.ParsedItemType.owner);
}

ProcTree.Action _center(dynamic context, dynamic data) {
  final child = context["widget"]!;
  context["widget"] = Center(child: child);
  return ProcTree.Action.proceed;
}

ProcTree.Action _text(dynamic context, dynamic data) {
  context["widget"] = Text(data["text"]);
  return ProcTree.Action.proceed;
}