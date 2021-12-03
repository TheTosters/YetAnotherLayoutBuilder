part "code_snippets_base.dart";

/// All possible code snippets must be accessed through this enum
enum _CodeSnippets {
  /// Allow to convert map value from string to proper enum value
  mapStringToEnum,

  ///  Allow to convert map value from string to int
  mapStringToInt,

  /// allows to parse dec or hex string into to int without 0x prefix
  parseInt,

  /// allows to parse Strings into int especially for usage in Color class
  parseIntForColor
}

class NeededExtensionsCollector {
  /// Code snippets which should be put inside map extension
  final Set<_CodeSnippets> _mapExt = {};

  /// Code snippets which should be used as a free functions
  final Set<_CodeSnippets> _functions = {};

  void needMapStringToEnum() {
    _mapExt.add(_CodeSnippets.mapStringToEnum);
  }

  void needMapStringToInt() {
    _mapExt.add(_CodeSnippets.mapStringToEnum);
    _functions.add(_CodeSnippets.parseInt);
  }

  void needIntParse() {
    _functions.add(_CodeSnippets.parseInt);
  }

  void needIntForColorParse() {
    _functions.add(_CodeSnippets.parseIntForColor);
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