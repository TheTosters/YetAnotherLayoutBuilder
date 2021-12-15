part of 'layout_build_coordinator.dart';

/// Builds a widget which has no children.
///
/// Delegate which transform [WidgetData] into [Widget]. Created instance is
/// set to [context.widget], and added to [context.widgets] list. This
/// delegate expects ```data``` to be instance of [WidgetData] and
/// ```context``` to be instance of [LayoutBuildContext].
Action _widgetProducerDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  lbc.widget = wData.builder(wData);
  wData.parentChildren!.add(lbc.widget!);
  return Action.proceed;
}

/// Builds [Widget] which have one or more children.
///
/// Delegate which transform [WidgetData] into [Widget]. Created instance is
/// set to [context.widget], and added to [context.widgets], however before
/// adding list is cleared. This delegate expects ```data``` to be instance of
/// [WidgetData] and ```context``` to be instance of [LayoutBuildContext].
Action _widgetConsumeAndProduceDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  lbc.widget = wData.builder(wData);
  wData.parentChildren!.add(lbc.widget!);
  return Action.proceed;
}

/// Builds instance of various classes which is used by parent [Widget] as an
/// argument for constructor.
///
/// Transform [ConstData] into [dynamic]. Expects that ```context``` is instance
/// of [KeyValue] and ```data``` is instance of [ConstData].
Action _constValueDelegate(dynamic context, dynamic data) {
  KeyValue ctx = context;
  final ConstData cData = data;
  ctx.key = cData.attribName;
  ctx.value = cData.builder(cData.parentName, cData.data);
  return Action.proceed;
}

/// Returns any [Widget] which must be stored in [data] under key *widget* or
/// by calling provider if there is a key *provider*. Provider must be a type of
/// [BlockProvider].
Action _blockDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  final String? blockName = wData["name"];
  lbc.widget = (blockName != null)
      ? wData.blockProvider(lbc.buildContext, blockName, wData.data)
      : wData["widget"];
  wData.parentChildren!.add(lbc.widget!);
  return Action.proceed;
}

/// Special delegate to handle YalbStyle, which is detected by coordinator as
/// [Widget], but in reality it's used just to collect attributes. This delegate
/// extract those data and pass it to context.
Action _yalbStyleDelegate(dynamic context, dynamic data) {
  KeyValue ctx = context;
  final WidgetData wData = data;
  ctx.value = wData.data;
  return Action.proceed;
}

Action _widgetFactoryDelegate(dynamic context, dynamic data) {
  final LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  final FactoryProvider provider = wData["provider"];
  final List<WidgetFactoryItem> items = provider();
  for (var item in items) {
    lbc.widget = wData.blockProvider(
        lbc.buildContext, item.blockName, item.injectableData);
    wData.parentChildren!.add(lbc.widget!);
  }
  return Action.proceed;
}
