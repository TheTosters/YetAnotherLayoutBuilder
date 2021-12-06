import 'package:logging/logging.dart';
import 'package:xml/xml.dart';
import 'package:validators/validators.dart';
import 'package:collection/collection.dart';

import 'found_items.dart';
import 'progress_collector.dart';

class XmlAnalyzer {
  final Logger logger;
  final Map<String, FoundWidget> items = {};
  final Iterable ignoredNodes;
  final ProgressCollector? progressCollector;

  XmlAnalyzer(this.logger, this.progressCollector, this.ignoredNodes);

  void process(String xmlStr, String path) {
    final xmlDoc = XmlDocument.parse(xmlStr);
    XmlElement xmlElement = xmlDoc.rootElement;
    _processElement(xmlElement, path);
  }

  void _processElement(XmlElement xmlElement, String path) {
    Set<String> attributes = _collectDirectAttributes(xmlElement, path);
    int childCount = 0;
    final Map<String, FoundConst> constItems = {};
    for (var subEl in xmlElement.childElements) {
      if (!_handledAsChildAttrib(constItems, subEl, attributes, path)) {
        _processElement(subEl, path);
        childCount++;
      }
    }
    final wName = xmlElement.name.toString();

    //should not be processed?
    if (ignoredNodes.any((i) => i.toString() == wName)) {
      logger
          .warning("XML node '$wName' found but ignored due exclusion option.");
      progressCollector?.addIgnoredNode(wName, path);
      return;
    }
    progressCollector?.addProcessedNode(wName, path);

    var widget = items[wName];
    if (widget == null) {
      widget = FoundWidget(wName);
      items[wName] = widget;
    }
    widget.attributes.addAll(attributes);
    _combineConstItems(widget.constItems, constItems);
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
      if (isUppercase(name[0]) && !name.startsWith("__")) {
        logger.warning("$path: Found '$name' attribute which start from Capital"
            " letter, looks like a typo.");
      }
    }
    return result;
  }

  // Contract:
  // If name starts with '_' then it's attribute name given as a child node
  bool _handledAsChildAttrib(Map<String, FoundConst> constItems,
      XmlElement subEl, Set<String> attributes, String path) {
    final name = subEl.name.toString();
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
        typeName = typeName.substring(2); //skip '__'
      }
      //Capitalize name
      typeName = "${typeName[0].toUpperCase()}${typeName.substring(1)}";
      final foundConst = FoundConst(typeName, realName);
      foundConst.attributes.addAll(attribs);
      constItems[foundConst.destAttrib] = foundConst;
      return true;
    }
    return false;
  }

  //TODO: Currently we support only this same Consts definitions. Don't combine
  // it. This limitation prevents usage of different constructors (or this same
  // constructor with optional params) but currently it will be too complicated,
  // need to be further investigation and more advanced heuristic.
  void _combineConstItems(
      Map<String, FoundConst> dest, Map<String, FoundConst> other) {
    Function equals = const SetEquality().equals;
    for (var o in other.values) {
      final prev = dest[o.typeName];
      if (prev != null) {
        if (!equals(o.attributes, prev.attributes)) {
          final reason = "Possible two different constructors for ConstValue "
              "found not equal sets are: ${o.attributes} != ${prev.attributes}";
          logger.severe(reason);
          throw Exception(reason);
        }
      } else {
        dest[o.typeName] = o;
      }
    }
  }
}
