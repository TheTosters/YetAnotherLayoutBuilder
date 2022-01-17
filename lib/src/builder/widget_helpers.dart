import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:collection/collection.dart';
import 'package:yet_another_layout_builder/src/builder/dart_extensions.dart';

import 'class_finders.dart';
import 'found_items.dart';
import 'styles_collector.dart';

/// Analyzes parameters in given constructor and determine type of Parentship
/// for widget
Parentship parentshipFromConstructor(ConstructorElement constructor) {
  final childParam = findChildParam(constructor);
  final childrenParam = findChildrenParam(constructor);
  if (childrenParam != null) {
    return childrenParam.type.nullabilitySuffix == NullabilitySuffix.question
        ? Parentship.multipleChildrenOrNone
        : Parentship.multipleChildren;
  } else if (childParam != null) {
    return childParam.type.nullabilitySuffix == NullabilitySuffix.question
        ? Parentship.oneChildOrNone
        : Parentship.oneChild;
  }
  return Parentship.noChildren;
}

/// Assign new parentship to widget but only if ```p``` indicates more
/// children then is already assigned.
void combineParentship(FoundWidget widget, Parentship p) {
  if (widget.parentship == Parentship.noChildren &&
      p != Parentship.noChildren) {
    //if xxxOrNone found, and no children in XML found, then don't change parentship
    if (p != Parentship.oneChildOrNone &&
        p != Parentship.multipleChildrenOrNone) {
      widget.parentship = p;
      widget.attributes.add(p == Parentship.oneChild ? "child" : "children");
    }
  } else if (widget.parentship == Parentship.oneChild &&
      (p == Parentship.multipleChildren ||
          p == Parentship.multipleChildrenOrNone)) {
    widget.parentship = Parentship.multipleChildren;
    widget.attributes.remove("child");
    widget.attributes.add("children");
  }
}

//Removes widgets for which constructor was not found
//Removes repeats of this same widget type
//combine const values for same widget type
//combine attributes for same widget type
//Update parentship info using constructor parameters info
//combine parentship info
void widgetsCompact(
    List<FoundWidget> widgets, ClassConstructorsCollector collector) {
  widgets.removeWhere((w) => !collector.hasConstructor(w.name));
  int index = 0;
  while (index < widgets.length) {
    FoundWidget widget = widgets[index];
    Parentship definedParentship = parentshipFromConstructor(
        collector.constructorsFor(widget.name).first.constructor!);
    combineParentship(widget, definedParentship);
    for (int t = widgets.length - 1; t > index; t--) {
      final other = widgets[t];
      if (widget.name == other.name) {
        widget.constItems.addAllIfAbsent(
            other.constItems,
            (inList, toAdd) =>
                (inList.destAttrib == toAdd.destAttrib) &&
                (inList.typeName == toAdd.typeName));
        widget.attributes.addAll(other.attributes);
        widgets.removeAt(t);
      }
    }
    index++;
  }
}

void addStyleRelatedAttributes(List<FoundWidget> widgets,
    ClassConstructorsCollector collector, StylesCollector styles) {
  for (var widget in widgets) {
    final ctr = collector.constructorsFor(widget.name).firstOrNull;
    if (ctr != null) {
      final extraAttribs = styles.styledAttributesFor(widget.name);
      // add extra attributes to widget, but only those which present at
      // found constructor
      for (var ea in extraAttribs) {
        final eaName = ea;
        final exists = ctr.constructor!.parameters.any((p) => p.name == eaName);
        if (exists) {
          ctr.attributes.add(ea);
        }
      }
    }
  }
}

void collectConst(List<FoundConst> constItems, List<Resolvable> allConsts) {
  for (var c in constItems) {
    allConsts.add(Resolvable(c.typeName, c.attributes, c.designatedCtrName));
    if (c.constItems.isNotEmpty) {
      collectConst(c.constItems, allConsts);
    }
  }
}
