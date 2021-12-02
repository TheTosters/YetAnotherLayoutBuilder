class ProgressCollector {
  static const int keyIgnoredFiles = 1; //Set<String>
  static const int keyProcessedFiles = 2; //Set<String>
  static const int keyProcessedNodes = 3; //Map<String, Set<String>>
  static const int keyIgnoredNodes = 4; //Map<String, Set<String>>

  Map<int, dynamic> data = <int, dynamic>{};

  void addIgnoredFile(String path) {
    final files = data.putIfAbsent(keyIgnoredFiles, () => <String>{});
    files.add(path);
  }

  void addProcessedFile(String path) {
    final files = data.putIfAbsent(keyProcessedFiles, () => <String>{});
    files.add(path);
  }

  void addIgnoredNode(String nodeName, String xmlFilePath) {
    final fileToNode =
        data.putIfAbsent(keyIgnoredNodes, () => <String, Set<String>>{});
    final nodeSet = fileToNode.putIfAbsent(xmlFilePath, () => <String>{});
    nodeSet.add(nodeName);
  }

  void addProcessedNode(String nodeName, String xmlFilePath) {
    final fileToNode =
        data.putIfAbsent(keyProcessedNodes, () => <String, Set<String>>{});
    final nodeSet = fileToNode.putIfAbsent(xmlFilePath, () => <String>{});
    nodeSet.add(nodeName);
  }
}
