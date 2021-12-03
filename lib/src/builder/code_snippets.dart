/// All possible code snippets must be accessed through this enum
enum _CodeSnippets {
  mapStringToEnum
}

//This is turbo ugly, but I've no better idea yet ;(
const Map<_CodeSnippets, String> _codeSnippetsPool = {
    _CodeSnippets.mapStringToEnum : r'''
  void updateEnum<T>(String key, List<T> values) {
    if (containsKey(key)) {
      final tmp = "${T.toString()}.${this[key]}";
      this[key] = values.firstWhere((d) => d.toString() == tmp);
    }
  }''',

};

class NeededExtensionsCollector {
  /// Code snippets which should be put inside map extension
  final Set<_CodeSnippets> _mapExt = {};

  /// Code snippets which should be used as a free functions
  final Set<_CodeSnippets> _functions = {};

  void needMapStringToEnum() {
    _mapExt.add(_CodeSnippets.mapStringToEnum);
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