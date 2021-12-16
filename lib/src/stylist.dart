import 'layout_build_coordinator.dart';
import 'types.dart';

class _StyleItem {
  final Map<String, dynamic> params;
  final Set<DelegateDataProcessor> converters = {};

  _StyleItem(this.params);

  //If true then params was converted
  bool isConverted(DelegateDataProcessor? prc) =>
      prc != null ? converters.contains(prc) : true;
}

class Stylist {
  final Map<String, _StyleItem> styles = {};

  void applyStyleIfNeeded(String name, WidgetData wData) {
    final styleName = wData["_yalbStyle"];
    if (styleName != null) {
      final styleInfo = styles[styleName];
      if (styleInfo != null) {
        if (!styleInfo.isConverted(wData.paramProcessor)) {
          wData.paramProcessor!(styleInfo.params);
          styleInfo.converters.add(wData.paramProcessor!);
        }
        wData.data.addAll(styleInfo.params);
      } else {
        print("ERROR xml node '$name' requested yalbStyle named '$styleName'"
            " but this style is not defined.");
      }
    }
  }

  void add(String name, Map<String, dynamic> data) {
    if (styles.containsKey(name)) {
      throw Exception("Style named '$name' already defined!");
    }
    styles[name] = _StyleItem(data);
  }
}
