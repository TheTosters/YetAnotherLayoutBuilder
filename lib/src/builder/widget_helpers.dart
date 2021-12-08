import 'package:analyzer/dart/element/element.dart';
import 'package:yet_another_layout_builder/src/builder/dart_extensions.dart';

import 'class_finders.dart';
import 'found_items.dart';

/// Analyzes parameters in given constructor and determine type of Parentship
/// for widget
Parentship parentshipFromConstructor(ConstructorElement constructor) {
  final childParam = findChildParam(constructor);
  final childrenParam = findChildrenParam(constructor);
  if (childrenParam != null) {
    return Parentship.multipleChildren;
  } else if (childParam != null) {
    return Parentship.oneChild;
  }
  return Parentship.noChildren;
}

/// Assign new parentship to widget but only if ```p``` indicates more
/// children then is already assigned.
void combineParentship(FoundWidget widget, Parentship p) {
  if (widget.parentship == Parentship.noChildren) {
    widget.parentship = p;
  } else if (widget.parentship == Parentship.oneChild &&
      p != Parentship.noChildren) {
    widget.parentship = p;
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
        widget.constItems.addAllIfAbsent(other.constItems,
            (inList, toAdd) => inList.destAttrib == toAdd.destAttrib);
        widget.attributes.addAll(other.attributes);
        widgets.removeAt(t);
      }
    }
    index++;
  }
}
