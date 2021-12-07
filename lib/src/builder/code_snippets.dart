part "code_snippets_base.dart";

/// All possible code snippets must be accessed through this enum
enum CodeSnippets {
  /// Allow to convert map value from string to proper enum value
  mapStringToEnum,

  ///  Allow to convert map value from string to int
  mapStringToInt,

  ///  Allow to convert map value from string to double
  mapStringToDouble,

  ///  Allow to convert map value from string to bool
  mapStringToBool,

  /// allows to parse dec or hex string into to int without 0x prefix
  parseInt,

  /// allows to parse Strings into int especially for usage in Color class
  parseIntForColor
}

class NeededExtensionsCollector {
  /// Code snippets which should be put inside map extension
  final Set<CodeSnippets> _mapExt = {};

  /// Code snippets which should be used as a free functions
  final Set<CodeSnippets> _functions = {};

  void needMapStringToEnum() {
    _mapExt.add(CodeSnippets.mapStringToEnum);
  }

  void needMapStringToInt() {
    _mapExt.add(CodeSnippets.mapStringToInt);
    _functions.add(CodeSnippets.parseInt);
  }

  void needMapStringToDouble() {
    _mapExt.add(CodeSnippets.mapStringToDouble);
  }

  void needMapStringToBool() {
    _mapExt.add(CodeSnippets.mapStringToBool);
  }

  void needIntParse() {
    _functions.add(CodeSnippets.parseInt);
  }

  void needIntForColorParse() {
    _functions.add(CodeSnippets.parseIntForColor);
  }

  /// Generic access, use with care! Don't mess _mapExt and _functions
  void needFunctionSnippets(Iterable<String> snippetIds) {
    for (var id in snippetIds) {
      _functions.add(strToCodeSnippets(id));
    }
  }

  /// Generic access, use with care! Don't mess _mapExt and _functions
  void needMapExtension(Iterable<String> snippetIds) {
    for (var id in snippetIds) {
      _mapExt.add(strToCodeSnippets(id));
    }
  }

  CodeSnippets strToCodeSnippets(String key) {
    final tmp = "CodeSnippets.$key";
    return CodeSnippets.values.firstWhere((d) => d.toString() == tmp);
  }
}

class CodeSnippetsWriter extends NeededExtensionsCollector {
  void writeSnippets(StringBuffer sb) {
    for (var id in _functions) {
      sb.writeln(_codeSnippetsPool[id]);
      sb.writeln();
    }
    _writeMapExtension(sb);
  }

  void _writeMapExtension(StringBuffer sb) {
    if (_mapExt.isNotEmpty) {
      sb.writeln("extension MapUpdate on Map {");
      for (var id in _mapExt) {
        sb.writeln(_codeSnippetsPool[id]);
        sb.writeln();
      }
      sb.writeln("}\n");
    }
  }
}
