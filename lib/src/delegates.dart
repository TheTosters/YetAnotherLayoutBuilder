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
  wData.children = null;
  lbc.widget = wData.builder(wData);
  lbc.widgets.add(lbc.widget!);
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
  wData.children = List.from(lbc.widgets, growable: false);
  lbc.widget = wData.builder(wData);
  lbc.widgets.clear();
  lbc.widgets.add(lbc.widget!);
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
