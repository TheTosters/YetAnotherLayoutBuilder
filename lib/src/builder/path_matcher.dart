import 'package:logging/logging.dart';
import 'package:path/path.dart';

class PathMatcher {
  final Set<String> nameOnly = {};
  final List<String> pathRelated = [];
  final List<String> wildcard = [];

  PathMatcher(Iterable? matchers) {
    if (matchers == null) {
      return;
    }
    for (var m in matchers) {
      final strM = m.toString();
      if (strM.contains('*')) {
        wildcard.add(strM);
        Logger("PathMatcher")
            .warning("Wildcards not supported, entry '$strM' ignored");
      } else if (strM.contains('/')) {
        pathRelated.add(strM);
      } else {
        nameOnly.add(strM);
      }
    }
  }

  /// Very naive implementation... maybe will be improved later
  bool match(String path) {
    if (nameOnly.isNotEmpty) {
      final name = basename(path);
      return nameOnly.contains(name);
    }

    for (var m in pathRelated) {
      if (path.endsWith(m)) {
        return true;
      }
    }

    return false;
  }
}
