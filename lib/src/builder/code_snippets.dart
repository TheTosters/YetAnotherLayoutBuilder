enum CodeSnippets {
  mapStringToEnum
}

//This is turbo ugly, but I've no better idea yet ;(
const Map<CodeSnippets, String> codeSnippetsPool = {
    CodeSnippets.mapStringToEnum : r'''
extension MapEnumUpdate on Map {
  void updateEnum<T>(String key, List<T> values) {
    if (containsKey(key)) {
      final tmp = "${T.toString()}.${this[key]}";
      this[key] = values.firstWhere((d) => d.toString() == tmp);
    }
  }
}''',

};