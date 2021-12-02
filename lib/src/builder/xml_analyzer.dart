import 'package:logging/logging.dart';
import 'package:xml/xml.dart';
import 'package:validators/validators.dart';

import 'found_widget.dart';

class XmlAnalyzer {
  final Logger logger;
  final Map<String, FoundWidget> items = {};

  XmlAnalyzer(this.logger);

  void process(String xmlStr, String path) {
    final xmlDoc = XmlDocument.parse(xmlStr);
    XmlElement xmlElement = xmlDoc.rootElement;
    _processElement(xmlElement, path);
  }

  void _processElement(XmlElement xmlElement, String path) {
    Set<String> attributes = _collectDirectAttributes(xmlElement, path);
    int childCount = 0;
    for (var subEl in xmlElement.childElements) {
      if (!_handledAsChildAttrib(subEl, attributes, path)) {
        _processElement(subEl, path);
        childCount++;
      }
    }
    final wName = xmlElement.name.toString();
    var widget = items[wName];
    if (widget == null) {
      widget = FoundWidget(wName);
      items[wName] = widget;
    }
    widget.attributes.addAll(attributes);

    //Update info about parentship, only more children can be set never
    //from more children to less children!
    Parentship p = childCount == 0
        ? Parentship.noChildren
        : (childCount == 1 ? Parentship.oneChild : Parentship.multipleChildren);
    if (widget.parentship == Parentship.noChildren) {
      widget.parentship = p;
    } else if (widget.parentship == Parentship.oneChild &&
        p != Parentship.noChildren) {
      widget.parentship = p;
    }
  }

  Set<String> _collectDirectAttributes(XmlElement xmlElement, String path) {
    Set<String> result = {};
    for (var attr in xmlElement.attributes) {
      final name = attr.name.toString();
      result.add(name);
      if (isUppercase(name[0])) {
        logger.warning("$path: Found '$name' attribute which start from Capital"
            " letter, looks like a typo.");
      }
    }
    return result;
  }

  // Contract:
  // If name starts with '_' then it's attribute name given as a child node
  bool _handledAsChildAttrib(
      XmlElement subEl, Set<String> attributes, String path) {
    final name = subEl.name.toString();
    if (name.startsWith("_")) {
      final realName = name.substring(1);
      attributes.add(realName);
      if (isUppercase(realName[0])) {
        logger.warning("$path: Found '$realName' attribute (nested as '$name')"
            " which start from Capital letter, looks like a typo.");
      }
      return true;
    }
    return false;
  }
}
