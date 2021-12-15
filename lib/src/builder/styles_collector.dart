import 'package:logging/logging.dart';

class StylesCollector {
  final Logger logger;

  //key-styleName from <YalbStyle name="<this is key>">
  //value = all attribute nodes found in YalbStyle with given name
  Map<String, Set<String>> styles = {};

  //key - class name of widget
  //value - all styleNames(keys from map styles) used on this widget
  Map<String, Set<String>> styledWidgets = {};

  StylesCollector(this.logger);

  void addStyleUsage(String styleName, String widgetClass) {
    styledWidgets.update(widgetClass, (value) {
      value.add(styleName);
      return value;
    }, ifAbsent: () => {styleName});
  }

  void addStyle(String styleName, Set<String> attributes) {
    if (styles.containsKey(styleName)) {
      final reason = "Style with name '$styleName' already defined !";
      logger.severe(reason);
      throw Exception(reason);
    }
    styles[styleName] = Set.unmodifiable(attributes);
  }

  Set<String> styledAttributesFor(String widgetClass) {
    final result = <String>{};
    final usedStyles = styledWidgets[widgetClass];
    if (usedStyles == null) {
      return result;
    }
    for(var styleName in usedStyles) {
      if (styleName.startsWith("\$")) {
        //Skip injectable styles
        continue;
      }
      final attribs = styles[styleName];
      if (attribs == null) {
        final reason = "Widget '$widgetClass' refers to style named "
            "'$styleName', but it's definition is not found!";
        logger.severe(reason);
        throw Exception(reason);
      }
      result.addAll(attribs);
    }
    return result;
  }
}
