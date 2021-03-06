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
  if (wData.hasSemiConsts) {
    _processSemiConst(wData);
  }
  //----------
  wData.stylist.applyStyleIfNeeded("<N/A>", wData);
  //----------
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
  if (wData.hasSemiConsts) {
    _processSemiConst(wData);
  }
  wData.stylist.applyStyleIfNeeded("<N/A>", wData);
  lbc.widget = wData.builder(wData);
  wData.parentChildren!.add(lbc.widget!);
  return Action.proceed;
}

void _processSemiConst(dynamic widgetOrConstData) {
  for (final cData in widgetOrConstData.semiConsts!) {
    if (cData.hasSemiConsts) {
      _processSemiConst(cData);
    }
    widgetOrConstData.data[cData.attribName] =
        cData.builder(cData.parentName, cData.data);
  }
}

/// Builds instance of various classes which is used by parent [Widget] as an
/// argument for constructor.
///
/// Transform [ConstData] into [dynamic]. Expects that ```context``` is instance
/// of [KeyValue] and ```data``` is instance of [ConstData].
Action _constValueDelegate(dynamic context, dynamic data) {
  KeyValue ctx = context;
  final ConstData cData = data;
  if (ctx.value != null) {
    cData.data.addAll(ctx.value);
  }
  ctx.key = cData.attribName;
  ctx.value = cData.builder(cData.parentName, cData.data);
  return Action.proceed;
}

/// Returns any [Widget] which must be stored in [data] under key *widget* or
/// by calling provider if there is a key *provider*. Provider must be a type of
/// [BlockBuilder].
Action _blockDelegate(dynamic context, dynamic data) {
  LayoutBuildContext lbc = context;
  final WidgetData wData = data;
  wData.buildContext = lbc.buildContext;
  final String? blockName = wData["name"];
  lbc.widget = (blockName != null)
      ? wData.blockBuilder.build(blockName, wData, {})
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
  //---------
  wData.stylist.applyStyleIfNeeded("<N/A>", wData);
  //-------
  final FactoryProvider provider = wData["provider"];
  final List<WidgetFactoryItem> items = provider();
  for (var item in items) {
    lbc.widget =
        wData.blockBuilder.build(item.blockName, wData, item.injectableData);
    wData.parentChildren!.add(lbc.widget!);
  }
  return Action.proceed;
}
