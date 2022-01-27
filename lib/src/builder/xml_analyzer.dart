import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:validators/validators.dart';
import 'package:xml/xml.dart';
import 'package:yet_another_layout_builder/src/builder/styles_collector.dart';

import 'dart_extensions.dart';
import 'found_items.dart';
import 'progress_collector.dart';
import 'widget_helpers.dart';

class XmlAnalyzer {
  final Logger logger;
  final List<FoundWidget> widgets = [];
  final Iterable ignoredNodes;
  final ProgressCollector? progressCollector;
  final StylesCollector stylesCollector;

  XmlAnalyzer(this.logger, this.progressCollector, this.ignoredNodes,
      this.stylesCollector);

  void process(String xmlStr, String path) {
    final xmlDoc = XmlDocument.parse(xmlStr);
    XmlElement xmlElement = xmlDoc.rootElement;
    _processElement(xmlElement, path);
  }

  void _processElement(XmlElement xmlElement, String path) {
    Set<String> attributes = _collectDirectAttributes(xmlElement, path);
    int childCount = 0;
    final List<FoundConst> constItems = [];
    for (var subEl in xmlElement.childElements) {
      if (!_handledAsChildAttrib(constItems, subEl, attributes, path)) {
        _processElement(subEl, path);
        //Some nodes should not count as children
        final ignoreAsChildren = const {"YalbStyle", "YalbBlockDef"};
        if (!ignoreAsChildren.contains(subEl.name.toString())) {
          childCount++;
          //factory count as 2 children (since it will build list of children)
          if (subEl.name.toString() == "YalbWidgetFactory") {
            childCount++;
          }
        }
      }
    }
    var wName = attributes.firstWhere((e) => e.startsWith("__"),
        orElse: () => xmlElement.name.toString());
    String? designatedCtrName;
    if (wName.startsWith("__")) {
      attributes.remove(wName); //prevent to poisson constructor search
      designatedCtrName = xmlElement.getAttribute(wName);
      if (designatedCtrName?.isEmpty ?? false) {
        designatedCtrName = null;
      }
      wName = wName.substring(2).capitalize(); //skip '__'
    }

    //should not be processed?
    if (ignoredNodes.any((i) => i.toString() == wName)) {
      logger
          .warning("XML node '$wName' found but ignored due exclusion option.");
      progressCollector?.addIgnoredNode(wName, path);
      return;
    }
    progressCollector?.addProcessedNode(wName, path);

    if (wName == "YalbStyle") {
      _processYalbStyleNode(xmlElement, attributes);
    }

    final widget =
        FoundWidget(wName, attributes, constItems, designatedCtrName);
    widgets.add(widget);
    //Update info about parentship, only more children can be set never
    //from more children to less children!
    Parentship p = childCount == 0
        ? Parentship.noChildren
        : (childCount == 1 ? Parentship.oneChild : Parentship.multipleChildren);
    combineParentship(widget, p);
  }

  Set<String> _collectDirectAttributes(XmlElement xmlElement, String path) {
    Set<String> result = {};
    for (var attr in xmlElement.attributes) {
      final name = attr.name.toString();
      if (name.startsWith("_") && !name.startsWith("__")) {
        //special attributes type, in form _attrib="", don't collect them!
        if (name == "_yalbStyle") {
          final widgetClass = xmlElement.name.toString();
          stylesCollector.addStyleUsage(attr.value, widgetClass);
        }
        continue;
      }
      result.add(name);
      if (isUppercase(name[0]) && !name.startsWith("__")) {
        logger.warning("$path: Found '$name' attribute which start from Capital"
            " letter, looks like a typo.");
      }
    }
    return result;
  }

  // Contract:
  // If name starts with '_' then it's attribute name given as a child node
  bool _handledAsChildAttrib(List<FoundConst> constItems, XmlElement subEl,
      Set<String> attributes, String path) {
    final name = subEl.name.toString();
    String? designatedCtrName;
    if (name.startsWith("_")) {
      final realName = name.substring(1);
      attributes.add(realName);
      if (isUppercase(realName[0])) {
        logger.warning("$path: Found '$realName' attribute (nested as '$name')"
            " which start from Capital letter, looks like a typo.");
      }
      final attribs = _collectDirectAttributes(subEl, path);
      var typeName =
          attribs.firstWhere((e) => e.startsWith("__"), orElse: () => realName);
      if (typeName.startsWith("__")) {
        attribs.remove(typeName); //prevent to poisson constructor search
        designatedCtrName = subEl.getAttribute(typeName);
        if (designatedCtrName?.isEmpty ?? false) {
          designatedCtrName = null;
        }
        typeName = typeName.substring(2); //skip '__'
      }
      //Capitalize name
      typeName = typeName.capitalize();
      final item = FoundConst(typeName, realName, attribs, designatedCtrName);
      constItems.add(item);
      for (var xmlChild in subEl.childElements) {
        if (!_handledAsChildAttrib(
            item.constItems, xmlChild, item.attributes, path)) {
          final reason = "All children of attribute ${item.destAttrib} must be"
              " an attributes, but ${xmlChild.name} looks like widget";
          logger.severe(reason);
          throw Exception(reason);
        }
      }
      return true;
    }
    return false;
  }

  void _processYalbStyleNode(XmlElement xmlElement, Set<String> attributes) {
    final nameAttr = xmlElement.attributes
        .firstWhereOrNull((a) => a.name.toString() == "name");
    if (nameAttr == null) {
      final reason = "YalbStyle must have argument 'name'";
      logger.severe(reason);
      throw Exception(reason);
    }
    stylesCollector.addStyle(nameAttr.value, attributes);
  }
}
