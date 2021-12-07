import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:logging/logging.dart';

class Constructable {
  //*************** Filled by xml analyzer
  /// Attributes found with xml which should be used to determine constructor
  /// for this item
  final Set<String> attributes;

  //*************** filled by class validator
  ConstructorElement? constructor;

  Constructable() : attributes = {};
  Constructable.from(Constructable other)
      : attributes = Set.unmodifiable(other.attributes);
  Constructable.withAttributes(Set<String> attributes)
      : attributes = Set.unmodifiable(attributes);

  @override
  String toString() {
    return 'Constructable{attributes: $attributes, ctr:$constructor}';
  }
}

class Resolvable extends Constructable {
  final String typeName;

  Resolvable(this.typeName, Set<String> attributes)
      : super.withAttributes(attributes);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Resolvable &&
          runtimeType == other.runtimeType &&
          typeName == other.typeName &&
          attributes.containsAll(other.attributes);

  @override
  int get hashCode => typeName.hashCode;
}

class ClassConstructorsCollector {
  final Map<String, List<Constructable>> _constructors = {};

  void addConstructor(
      String typeName, ConstructorElement ctr, Set<String> attributes) {
    _constructors.update(typeName, (value) {
      //Function equals = const SetEquality().equals;
      Constructable? found;
      for (var knownCtr in value) {
        if (knownCtr.constructor!.name ==
                ctr.name /*&&
            equals(knownCtr.constructor!.parameters, ctr.parameters)*/
            ) {
          found = knownCtr;
          break;
        }
      }
      if (found == null) {
        value.add(Constructable()
          ..constructor = ctr
          ..attributes.addAll(attributes));
      } else {
        found.attributes.addAll(attributes);
      }
      return value;
    },
        ifAbsent: () => [
              Constructable()
                ..constructor = ctr
                ..attributes.addAll(attributes)
            ]);
  }

  List<Constructable> constructorsFor(String typeName) =>
      _constructors[typeName] ?? const [];

  bool hasConstructor(String typeName) => constructorsFor(typeName).isNotEmpty;
}

class ConstValClassFinder extends GenericClassFinder {
  ConstValClassFinder(ClassConstructorsCollector collector, Logger logger)
      : super(collector, logger);

  Future<void> prepare(Resolver resolver) async {
    List<Uri> libUri = [
      Uri.parse("package:yet_another_layout_builder/workaround.dart"),
      Uri.parse("package:flutter/painting.dart"),
//      Uri.parse("package:flutter/material.dart"),
    ];
    await _prepareLibraries(resolver, libUri);
  }

  void process(List<Resolvable> constValues) {
    _process(constValues);
  }
}

class WidgetClassFinder extends GenericClassFinder {
  WidgetClassFinder(ClassConstructorsCollector collector, Logger logger)
      : super(collector, logger);

  Future<void> prepare(Resolver resolver) async {
    List<Uri> libUri = [
      Uri.parse("package:flutter/widgets.dart"),
    ];
    await _prepareLibraries(resolver, libUri);
  }

  void process(List<Resolvable> widgets) {
    _process(widgets);
  }
}

class GenericClassFinder {
  final List<LibraryElement> libraries = [];
  final Logger logger;
  final ClassConstructorsCollector collector;

  GenericClassFinder(this.collector, this.logger);

  Future<void> _prepareLibraries(Resolver resolver, List<Uri> libUri) async {
    for (var uri in libUri) {
      final lib = await resolver.libraryFor(AssetId.resolve(uri));
      libraries.add(lib);
    }
  }

  // I got feeling this can be done better...
  void _compact(List<Resolvable> items) {
    int index = 0;
    while (index < items.length) {
      Resolvable r = items[index];
      for (int t = items.length - 1; t > index; t--) {
        if (r == items[t]) {
          items.removeAt(t);
        }
      }
      index++;
    }
  }

  void _process(List<Resolvable> items) {
    _compact(items);
    _findClasses(items);
  }

  void _findClasses(List<Resolvable> items) {
    for (var library in libraries) {
      for (var export in library.exports) {
        var expLibrary = export.exportedLibrary!;
        if (_findInLibrary(expLibrary, items)) {
          //all items found
          return;
        }
      }
    }
  }

  bool _findInLibrary(LibraryElement lib, List<Resolvable> items) {
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
  bool _itemsMatched(ClassElement clazz, List<Resolvable> items) {
    for (int index = items.length - 1; index >= 0; index--) {
      Resolvable item = items[index];
      if (item.typeName != clazz.name) {
        continue;
      }
      item.constructor = _matchingConstructor(clazz, item.attributes);
      if (item.constructor == null) {
        final reason = "Item with name ${clazz.name} found as a class, however"
            " no constructor match params: ${item.attributes}";
        logger.severe(reason);
        throw Exception(reason);
      }
      collector.addConstructor(clazz.name, item.constructor!, item.attributes);
      items.removeAt(index);
    }
    return items.isEmpty;
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
