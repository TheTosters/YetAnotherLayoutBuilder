part of "code_snippets.dart";

//This is turbo ugly, but I've no better idea yet ;(
const Map<CodeSnippets, String> _codeSnippetsPool = {
  CodeSnippets.mapStringToEnum : r'''
  void updateEnum<T>(String key, List<T> values) {
    if (containsKey(key)) {
      final tmp = "${T.toString()}.${this[key]}";
      this[key] = values.firstWhere((d) => d.toString() == tmp);
    }
  }''',

  CodeSnippets.mapStringToInt: r'''
    void updateInt(String key) {
    if (containsKey(key)) {
      this[key] = _improvedIntParse(this[key]!);
    }
  }

  void updateAllInt(Iterable<String> keys) {
    for(var s in keys) {
      updateInt(s);
    }
  }''',

  CodeSnippets.parseInt: r'''
int? _improvedIntParse(String value) {
  return int.tryParse(value) ?? int.parse(value, radix: 16);
}''',

  CodeSnippets.parseIntForColor: r'''
int? _parseIntForColor(String v) {
  if (v.startsWith("#")) {
    v = v.substring(1);

  } else if (v.startsWith("0x")) {
    return _improvedIntParse(v);
  }

  //Support for 3 digit html color
  if (v.length == 3) {
    v = "0xFF${v[0]}${v[0]}${v[1]}${v[1]}${v[2]}${v[2]}";

  } else if (v.length == 6) {
    //Add opacity component if missing otherwise color will be full transparent
    v = "0xFF$v";
  }

  return _improvedIntParse(v);
}'''
};
