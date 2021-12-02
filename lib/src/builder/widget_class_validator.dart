import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:logging/logging.dart';

import 'found_widget.dart';

class WidgetClassValidator {
  final List<LibraryElement> libraries = [];
  final Logger logger;

  WidgetClassValidator(this.logger);

  Future<void> prepare(Resolver resolver) async {
    List<Uri> libUri = [
      Uri.parse("package:flutter/widgets.dart"),
//      Uri.parse("package:flutter/material.dart")
    ];
    for (var uri in libUri) {
      final lib = await resolver.libraryFor(AssetId.resolve(uri));
      libraries.add(lib);
    }
  }

  void process(Map<String, FoundWidget> widgets) {
    _findClasses(widgets);
  }

  void _findClasses(Map<String, FoundWidget> widgets) {
    for (var library in libraries) {
      for (var export in library.exports) {
        var expLibrary = export.exportedLibrary!;
        if (_findInLibrary(expLibrary, widgets)) {
          //all widgets found
          return;
        }
      }
    }
  }

  bool _findInLibrary(LibraryElement lib, Map<String, FoundWidget> widgets) {
    for (var unit in lib.units) {
      for (var clazz in unit.classes) {
        if (_widgetsMatched(clazz, widgets)) {
          return true;
        }
      }
    }
    return false;
  }

  //Check if class have constructor to which params match. If so, then
  //assign this constructor to widget with this same name.
  //returns true if all widgets in map have assigned constructor
  bool _widgetsMatched(ClassElement clazz, Map<String, FoundWidget> widgets) {
    FoundWidget? widget = widgets[clazz.name];
    if (widget == null) {
      return false;
    }
    widget.constructor = _matchingConstructor(clazz, widget.attributes);
    if (widget.constructor == null) {
      final reason = "Widget with name ${clazz.name} found as a class, however"
          " no constructor match params: ${widget.attributes}";
      logger.severe(reason);
      throw Exception(reason);
    }
    return widgets.values.every((w) => w.constructor != null);
  }

  ConstructorElement? _matchingConstructor(
      ClassElement clazz, Set<String> wanted) {
    //no params at all
    if (wanted.isEmpty) {
      for (var ctr in clazz.constructors) {
        if (ctr.parameters.isEmpty) {
          return ctr;
        }
        final requiredParams = ctr.parameters
            .any((p) => p.isRequiredNamed || p.isRequiredPositional);
        if (!requiredParams) {
          return ctr;
        }
      }
      return null;
    }
    //Normal search, wanted must be subset of constructor params
    for (var ctr in clazz.constructors) {
      Set<String> allParams = ctr.parameters.map((param) => param.name).toSet();
      if (allParams.containsAll(wanted)) {
        return ctr;
      }
    }
    return null;
  }
}
