import 'package:flutter/material.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';

void registerItems() {
  Registry.addWidgetContainerBuilder("Center", _centerBuilder);
  Registry.addWidgetContainerBuilder("Column", _columnBuilder);
  Registry.addWidgetBuilder("Text", _textBuilder);
}

Widget _columnBuilder(WidgetData data) {
  return Column(children: data.children!);
}

Widget _centerBuilder(WidgetData data) {
  return Center(child: data.children!.first);
}

Widget _textBuilder(WidgetData data) {
  return Text(data.data["text"]);
}