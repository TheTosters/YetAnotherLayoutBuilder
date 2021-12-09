part of 'layout_build_coordinator.dart';

/// Const Value Builder for handling String const value nodes
///
/// Should be used for nodes which start with '_' and considered as String
/// data node which should be converted into data in parent for example
/// ```xml
/// <Text>
///   <_data text="this is text"/>
/// </Text>
/// ```
/// This builder can be used for '_data' node from above example. It supports
/// attribute which can be named _value_, _data_ or _text_
dynamic _constValueStringBuilder(String parent, Map<String, dynamic> data) {
  return data["value"] ?? data["data"] ?? data["text"];
}

dynamic _constValueNOPBuilder(String parent, Map<String, dynamic> data) {
  return data;
}
