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

  const ConvertFunction(this.functionName)
      : funcExt = const [],
        mapExt = const [];
  const ConvertFunction.withFunc(this.functionName, this.funcExt)
      : mapExt = const [];
  const ConvertFunction.withMap(this.functionName, this.mapExt)
      : funcExt = const [];
  const ConvertFunction.withBoth(this.functionName, this.funcExt, this.mapExt);
}

// expect other to be DartObjectImpl
ConvertFunction convertFunctionFrom(dynamic other) {
  final fName = other.fields["functionName"].toStringValue();

  final funcExt = <String>[];
  for(var tmp in other.fields["funcExt"].toListValue()) {
    funcExt.add( tmp.toStringValue() );
  }

  final mapExt = <String>[];
  for(var tmp in other.fields["mapExt"].toListValue()) {
    mapExt.add( tmp.toStringValue() );
  }

  return ConvertFunction.withBoth(fName, funcExt, mapExt);
}
