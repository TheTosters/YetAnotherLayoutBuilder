part of 'layout_build_coordinator.dart';

material.Widget _dummyBuilder(WidgetData inData) {
  throw Exception("You should never execute this!");
}

Map<String, LayoutBuilderItem> _registerSpecialNodes() {
  return {
    "YalbBlock": LayoutBuilderItem.withDelegate(
        "YalbBlock", _blockDelegate, ParsedItemType.owner),
    "YalbWidgetFactory": LayoutBuilderItem.withDelegate(
        "YalbWidgetFactory", _widgetFactoryDelegate, ParsedItemType.owner),
    "YalbStyle": LayoutBuilderItem.withDelegate(
        "YalbStyle", _yalbStyleDelegate, ParsedItemType.constValue),
  };
}
