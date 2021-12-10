import 'package:analyzer/dart/element/element.dart';

import 'class_finders.dart';

/// Annotation for constructor/function parameters
///
/// Used at parameter level to inform builder that value to this parameter
/// should be processed by pointed function before pass. For following code
/// ```dart
/// class Foo{
///   Foo(@ConvertFunction('myConvert', []) String param);
/// }
/// ```
/// builder should produce:
/// ```dart
///   Foo(
///     myConvert(someValue)
///   );
/// ```
///
/// Extensions are used to inform builder which extra code snippets should be
/// inserted. For more info dig into class [CodeSnippetsWriter]
class ConvertFunction {
  final String functionName;
  final List<String> funcExt;
  final List<String> mapExt;
  final bool nullableResult;

  const ConvertFunction(this.functionName, this.nullableResult)
      : funcExt = const [],
        mapExt = const [];
  const ConvertFunction.withFunc(
      this.functionName, this.nullableResult, this.funcExt)
      : mapExt = const [];
  const ConvertFunction.withMap(
      this.functionName, this.nullableResult, this.mapExt)
      : funcExt = const [];
  const ConvertFunction.withBoth(
      this.functionName, this.nullableResult, this.funcExt, this.mapExt);
}

class SkipWidgetBuilder {
  const SkipWidgetBuilder();
}

class SpecialDataProcessor {
  final String registryMethod;
  const SpecialDataProcessor(this.registryMethod);
}

class MatchAnyConstructor {
  const MatchAnyConstructor();
}

String? getSpecialDataProcessor(ClassElement clazz) {
  final annotation = findAnnotation(clazz, "SpecialDataProcessor");
  final dynamic value = annotation?.computeConstantValue();
  if (value != null) {
    return value.fields["registryMethod"].toStringValue();
  }
  return null;
}

// expect other to be DartObjectImpl
ConvertFunction convertFunctionFrom(dynamic other) {
  final fName = other.fields["functionName"].toStringValue();
  final nullable = other.fields["nullableResult"].toBoolValue();

  final funcExt = <String>[];
  for (var tmp in other.fields["funcExt"].toListValue()) {
    funcExt.add(tmp.toStringValue());
  }

  final mapExt = <String>[];
  for (var tmp in other.fields["mapExt"].toListValue()) {
    mapExt.add(tmp.toStringValue());
  }

  return ConvertFunction.withBoth(fName, nullable, funcExt, mapExt);
}
