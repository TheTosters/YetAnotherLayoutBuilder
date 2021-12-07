import 'package:flutter/material.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';
//
// int? _improvedIntParse(String value) {
//   return int.tryParse(value) ?? int.parse(value, radix: 16);
// }
//
// extension MapUpdate on Map {
//   void updateInt(String key) {
//     if (containsKey(key)) {
//       this[key] = _improvedIntParse(this[key]!);
//     }
//   }
//
//   void updateAllInt(Iterable<String> keys) {
//     for (var s in keys) {
//       updateInt(s);
//     }
//   }
// }
//
// int? _parseIntForColor(String v) {
//   if (v.startsWith("#")) {
//     v = v.substring(1);
//   } else if (v.startsWith("0x")) {
//     return _improvedIntParse(v);
//   }
//
//   //Support for 3 digit html color
//   if (v.length == 3) {
//     v = "0xFF${v[0]}${v[0]}${v[1]}${v[1]}${v[2]}${v[2]}";
//   } else if (v.length == 6) {
//     //Add opacity component if missing otherwise color will be full transparent
//     v = "0xFF$v";
//   }
//
//   return _improvedIntParse(v);
// }
//
// Color _colorBuilderSelector(String parent, Map<String, dynamic> data) {
//   if ({"value"}.containsAll(data.keys)) {
//     return _colorBuilderAutoGen(parent, data);
//   } else if ({"a", "r", "g", "b"}.containsAll(data.keys)) {
//     return _colorValBuilderAutoGen(parent, data);
//   }
//   throw Exception("Unknown constructor");
// }
//
// Color _colorBuilderAutoGen(String parent, Map<String, dynamic> data) {
//   return Color(_parseIntForColor(data["value"])!);
// }
//
// Color _colorValBuilderAutoGen(String parent, Map<String, dynamic> data) {
//   return Color.fromARGB(
//     int.parse(data["a"]!),
//     int.parse(data["r"]!),
//     int.parse(data["g"]!),
//     int.parse(data["b"]!),
//   );
// }

void registerItems() {
//  Registry.addValueBuilder("Container", "color", _colorBuilderSelector);
  //Registry.addWidgetBuilder("Text", _textBuilderAutoGen);
}
