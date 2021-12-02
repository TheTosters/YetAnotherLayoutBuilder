import 'package:flutter/material.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';

extension MapUpdate on Map {
  void unparseEnum<T>(String key, List<T> values) {
    if (containsKey(key)) {
      final tmp = "${T.toString()}.${this[key]}";
      this[key] = values.firstWhere((d) => d.toString() == tmp);
    }
  }
}

dynamic _textDataResolver(Map<String, dynamic> inData) {
  inData.unparseEnum("textAlign", TextAlign.values);
  return inData;
}

void registerItems() {
  Registry.addWidgetBuilder("Text", _textBuilderAutoGen, dataProcessor: _textDataResolver);
  //Registry.addWidgetBuilder("Text", _textBuilderAutoGen);
}


Widget _textBuilderAutoGen(WidgetData data) {
  return Text(
    data["data"]!,
    textAlign: data["textAlign"],
  );
}