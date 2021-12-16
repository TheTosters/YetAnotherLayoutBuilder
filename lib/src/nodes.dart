part of 'layout_build_coordinator.dart';

material.Widget _dummyBuilder(WidgetData inData) {
  throw Exception("You should never execute this!");
}

Map<String, LayoutBuilderItem> _registerSpecialNodes() {
  return {
    "YalbBlock": LayoutBuilderItem("YalbBlock", false, _blockDelegate,
        _dummyBuilder, _nopProcessor, ParsedItemType.owner),
    "YalbWidgetFactory": LayoutBuilderItem(
        "YalbWidgetFactory",
        false,
        _widgetFactoryDelegate,
        _dummyBuilder,
        _nopProcessor,
        ParsedItemType.owner),
    "YalbStyle": LayoutBuilderItem("YalbStyle", false, _yalbStyleDelegate,
        _dummyBuilder, _nopProcessor, ParsedItemType.constValue),
  };
}
