part of 'layout_build_coordinator.dart';

typedef BlockProvider = material.Widget Function(Map<String, dynamic> data);

Action _blockDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  final BlockProvider? prv = wData["provider"];
  lbc.widget = (prv != null) ? prv(data.data) : wData["widget"];
  wData.parentChildren!.add(lbc.widget!);
  return Action.proceed;
}

material.Widget _dummyBuilder(WidgetData inData) {
  throw Exception("You should never execute this!");
}

Map<String, LayoutBuilderItem> _registerSpecialNodes() {
  return {
    "YalbBlock": LayoutBuilderItem("YalbBlock", false, _blockDelegate,
        _dummyBuilder, _nopProcessor, ParsedItemType.owner),
  };
}
