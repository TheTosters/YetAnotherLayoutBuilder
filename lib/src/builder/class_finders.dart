import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/annotations.dart';

class Constructable {
  final Set<String> attributes;
  ConstructorElement? constructor;
  bool skipBuilder = false;
  String? specialDataProcessor;

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
      ClassElement clazz, ConstructorElement ctr, Set<String> attributes) {
    final typeName = clazz.name;
    _constructors.update(typeName, (value) {
      Constructable? found;
      for (var knownCtr in value) {
        if (knownCtr.constructor!.name == ctr.name) {
          found = knownCtr;
          break;
        }
      }
      if (found == null) {
        value.add(Constructable()
          ..constructor = ctr
          ..skipBuilder = hasAnnotation(clazz, "SkipWidgetBuilder")
          ..specialDataProcessor = getSpecialDataProcessor(clazz)
          ..attributes.addAll(attributes));
      } else {
        found.attributes.addAll(attributes);
        found.skipBuilder |= hasAnnotation(clazz, "SkipWidgetBuilder");
        found.specialDataProcessor ??= getSpecialDataProcessor(clazz);
      }
      return value;
    },
        ifAbsent: () => [
              Constructable()
                ..constructor = ctr
                ..skipBuilder = hasAnnotation(clazz, "SkipWidgetBuilder")
                ..specialDataProcessor = getSpecialDataProcessor(clazz)
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

  Future<void> prepare(Resolver resolver, Iterable? extraPackages) async {
    List<Uri> libUri = [
      Uri.parse("package:yet_another_layout_builder/workaround.dart"),
      Uri.parse("package:flutter/painting.dart"),
    ];
    for (var ep in extraPackages ?? []) {
      libUri.add(Uri.parse(ep));
    }
    await _prepareLibraries(resolver, libUri);
  }

  void process(List<Resolvable> constValues) {
    _process(constValues);
  }
}

class WidgetClassFinder extends GenericClassFinder {
  WidgetClassFinder(ClassConstructorsCollector collector, Logger logger)
      : super(collector, logger);

  Future<void> prepare(Resolver resolver, Iterable? extraPackages) async {
    List<Uri> libUri = [
      Uri.parse("package:yet_another_layout_builder/special_nodes.dart"),
      Uri.parse("package:flutter/widgets.dart"),
      Uri.parse("package:flutter/material.dart"),
      Uri.parse("package:flutter/cupertino.dart"),
      Uri.parse("package:flutter/rendering.dart"),
    ];
    for (var ep in extraPackages ?? []) {
      libUri.add(Uri.parse(ep));
    }
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
      collector.addConstructor(clazz, item.constructor!, item.attributes);
      items.removeAt(index);
    }
    return items.isEmpty;
  }

  ConstructorElement? _matchingConstructor(
      ClassElement clazz, Set<String> wanted) {
    final matchers = const [
      _matchAnnotedAsMatchAny,
      _matchNoRequiredParams,
      _matchByParamNames,
    ];
    for (var matcher in matchers) {
      final result = matcher(clazz, wanted);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

/// Constructor matcher which covers following case:
/// - wanted params are subset of params in constructor
/// - if constructor has required params, it must exist is [wantedParams]
/// - if [wantedParams] have param named *child* constructor must have one of
/// params *children* or *child*.
///
/// Match: if params are found in constructor
ConstructorElement? _matchByParamNames(
    ClassElement clazz, Set<String> wantedParams) {
  final childSpecialCase = wantedParams.contains("child");
  for (var ctr in clazz.constructors) {
    Set<String> allParams = ctr.parameters.map((param) => param.name).toSet();
    if (allParams.containsAll(wantedParams)) {
      return ctr;
    }
    //Special case: wanted have child, but allParam expect children. This is
    //also match!
    if (childSpecialCase) {
      final iterator = wantedParams.map((e) => e == "child" ? "children" : e);
      if (allParams.containsAll(iterator)) {
        return ctr;
      }
    }
  }
  return null;
}

/// Constructor matcher which covers following case:
/// - class is annotated with [MatchAnyConstructor] annotation
///
/// Match: if annotation is used, any constructor is returned
ConstructorElement? _matchAnnotedAsMatchAny(
    ClassElement clazz, Set<String> wantedParams) {
  return hasAnnotation(clazz, "MatchAnyConstructor")
      ? clazz.constructors.first
      : null;
}

/// Constructor matcher which covers following case:
/// - wantedParams is empty
///
/// Match: If constructor don't have any required params (all optional or non)
ConstructorElement? _matchNoRequiredParams(
    ClassElement clazz, Set<String> wantedParams) {
  if (wantedParams.isEmpty) {
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
  }
  return null;
}

ElementAnnotation? findAnnotation(Element e, String annotationName) {
  final annotation = e.metadata.firstWhereOrNull(
      (an) => an.element?.enclosingElement?.name == annotationName);
  return annotation;
}

bool hasAnnotation(Element e, String annotationName) {
  return e.metadata
      .any((an) => an.element?.enclosingElement?.name == annotationName);
}

/// Check if given constructor parameter represents [Widget] child/children.
bool isChildParam(ParameterElement p) {
  bool r = (p.name == "child") || (p.name == "children");
  r &= p.type.element?.name == "Widget";
  return r;
}

/// Check if given constructor expect Child parameter, if so then return it
/// otherwise return ```null```
ParameterElement? findChildParam(ConstructorElement ctr) {
  final param = ctr.parameters.firstWhereOrNull((p) => p.name == "child");
  return param?.type.element?.name == "Widget" ? param : null;
}

/// Check if given constructor expect Children parameter, if so then return it
/// otherwise return ```null```
ParameterElement? findChildrenParam(ConstructorElement ctr) {
  final param = ctr.parameters.firstWhereOrNull((p) => p.name == "children");
  //It might be wise to check if this is list/iterable of Widget? Maybe...
  return param;
}
