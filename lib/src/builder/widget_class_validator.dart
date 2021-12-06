import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:logging/logging.dart';

import 'found_items.dart';

class ConstValClassValidator extends GenericClassValidator {

  ConstValClassValidator(Logger logger) : super(logger);

  Future<void> prepare(Resolver resolver) async {
    List<Uri> libUri = [
      Uri.parse("package:flutter/painting.dart"),
//      Uri.parse("package:flutter/material.dart"),
      Uri.parse("package:yet_another_layout_builder/workaround.dart"),
    ];
    await _prepareLibraries(resolver, libUri);
  }

  void process(Map<String, Constructable> items) {
    _process(items);
  }
}

class WidgetClassValidator extends GenericClassValidator {

  WidgetClassValidator(Logger logger) : super(logger);

  Future<void> prepare(Resolver resolver) async {
    List<Uri> libUri = [
      Uri.parse("package:flutter/widgets.dart"),
    ];
    await _prepareLibraries(resolver, libUri);
  }

  void process(Map<String, FoundWidget> widgets) {
    _process(widgets);
  }
}

class GenericClassValidator {
  final List<LibraryElement> libraries = [];
  final Logger logger;

  GenericClassValidator(this.logger);

  Future<void> _prepareLibraries(Resolver resolver, List<Uri> libUri) async {
    for (var uri in libUri) {
      final lib = await resolver.libraryFor(AssetId.resolve(uri));
      libraries.add(lib);
    }
  }

  void _process(Map<String, Constructable> widgets) {
    _findClasses(widgets);
  }

  void _findClasses(Map<String, Constructable> items) {
    for (var library in libraries) {
      for (var export in library.exports) {
        var expLibrary = export.exportedLibrary!;
        if (_findInLibrary(expLibrary, items)) {
          //all widgets found
          return;
        }
      }
    }
  }

  bool _findInLibrary(LibraryElement lib, Map<String, Constructable> items) {
    for (var unit in lib.units) {
      for (var clazz in unit.classes) {
        if (_itemsMatched(clazz, items)) {
          return true;
        }
      }
    }
    return false;
  }

  //Check if class have constructor to which params match. If so, then
  //assign this constructor to item with this same name.
  //returns true if all items in map have assigned constructor
  bool _itemsMatched(ClassElement clazz, Map<String, Constructable> items) {
    Constructable? item = items[clazz.name];
    if (item == null) {
      return false;
    }
    item.constructor = _matchingConstructor(clazz, item.attributes);
    if (item.constructor == null) {
      final reason = "Item with name ${clazz.name} found as a class, however"
          " no constructor match params: ${item.attributes}";
      logger.severe(reason);
      throw Exception(reason);
    }
    return items.values.every((w) => w.constructor != null);
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
