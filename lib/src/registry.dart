part of 'layout_build_coordinator.dart';

class LayoutBuilderItem {
  final String elementName;
  final dynamic builder; //WidgetBuilder or ConstBuilder
  final ParsedItemType itemType;
  final PNDelegate delegate;
  final DelegateDataProcessor dataProcessor;
  final bool isContainer; //can have children?
  //special case, when more then one constValue with this same destAttirbute is
  // given but different types can be found. Used in YalbStyle
  final String? underlyingType;

  //This is only meaningful for ConstBuilder
  final String? fullPath;

  //if we have several items with this same elementName,
  // used for building const values
  LayoutBuilderItem? next;

  LayoutBuilderItem.widget(this.elementName, this.builder, this.dataProcessor)
      : isContainer = false,
        delegate = _widgetProducerDelegate,
        itemType = ParsedItemType.owner,
        underlyingType = null,
        fullPath = null;

  LayoutBuilderItem.container(
      this.elementName, this.builder, this.dataProcessor)
      : isContainer = true,
        delegate = _widgetConsumeAndProduceDelegate,
        itemType = ParsedItemType.owner,
        underlyingType = null,
        fullPath = null;

  LayoutBuilderItem.constVal(
      this.elementName, this.fullPath, this.underlyingType, this.builder)
      : isContainer = false,
        delegate = _constValueDelegate,
        itemType = ParsedItemType.constValue,
        dataProcessor = _nopProcessor;

  LayoutBuilderItem.withDataProcessor(
      LayoutBuilderItem oldItem, DelegateDataProcessor prc)
      : elementName = oldItem.elementName,
        fullPath = oldItem.fullPath,
        underlyingType = oldItem.underlyingType,
        builder = oldItem.builder,
        isContainer = oldItem.isContainer,
        delegate = oldItem.delegate,
        itemType = oldItem.itemType,
        dataProcessor = prc;

  LayoutBuilderItem.withDelegate(this.elementName, this.delegate, this.itemType)
      : isContainer = false,
        builder = _dummyBuilder,
        dataProcessor = _nopProcessor,
        underlyingType = null,
        fullPath = null;

/*  LayoutBuilderItem(this.elementName, this.isContainer, this.delegate,
      this.builder, this.dataProcessor, this.itemType)
      : underlyingType = null,
        fullPath = null;*/
}

class Registry {
  static final Map<String, LayoutBuilderItem> _items = _registerSpecialNodes();

  static void addWidgetBuilder(String elementName, WidgetBuilder builder,
      {DelegateDataProcessor dataProcessor = _nopProcessor}) {
    _items[elementName] =
        LayoutBuilderItem.widget(elementName, builder, dataProcessor);
  }

  static void addWidgetContainerBuilder(
      String elementName, WidgetBuilder builder,
      {DelegateDataProcessor dataProcessor = _nopProcessor}) {
    _items[elementName] =
        LayoutBuilderItem.container(elementName, builder, dataProcessor);
  }

  static void addValueBuilder(
      String attribPath, String typeName, ConstBuilder builder) {
    int idx = attribPath.lastIndexOf("/");
    LayoutBuilderItem item = LayoutBuilderItem.constVal(
        attribPath.substring(idx + 1), attribPath, typeName, builder);

    _items.update(item.elementName, (existing) {
      item.next = existing;
      return item;
    }, ifAbsent: () => item);
  }

  static void setStyleDataProcessor(DelegateDataProcessor prc) {
    _items.update("YalbStyle",
        (oldItem) => LayoutBuilderItem.withDataProcessor(oldItem, prc));
  }

  static String? _getWantedType(BuildPhaseState state) {
    String? wantedType =
        state.data.keys.firstWhereOrNull((element) => element.startsWith("__"));
    if (wantedType != null) {
      return wantedType.substring(2);
    } else {
      return state.delegateName.substring(1).capitalize();
    }
  }

  static LayoutBuilderItem? _findByPath(BuildPhaseState state, String path) {
    assert(path.isNotEmpty);
    var chain = Registry._items[state.delegateName];
    if (chain != null) {
      String? wantedType = _getWantedType(state);
      while (chain != null) {
        if (chain.underlyingType == wantedType && chain.fullPath == path) {
          return chain;
        }
        chain = chain.next;
      }
    }
    return null;
  }

  static LayoutBuilderItem? _findByName(BuildPhaseState state) =>
      _items[state.delegateName];
}
