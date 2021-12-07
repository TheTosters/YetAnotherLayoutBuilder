extension StringExtension on String {
  String capitalize() {
    if (length == 1) {
      return toUpperCase();
    } else if (length > 1) {
      return "${this[0].toUpperCase()}${substring(1)}";
    } else {
      return this;
    }
  }

  String deCapitalize() {
    if (length == 1) {
      return toLowerCase();
    } else if (length > 1) {
      return "${this[0].toLowerCase()}${substring(1)}";
    } else {
      return this;
    }
  }
}

extension ListExtension<T> on List<T> {
  void addIfAbsent(T value, bool Function(T inList) test) {
    if (!any(test)) {
      add(value);
    }
  }

  void addAllIfAbsent(
      Iterable<T> values, bool Function(T inList, T newValue) test) {
    for (var v in values) {
      bool found = false;
      for (T element in this) {
        if (test(element, v)) {
          found = true;
          break;
        }
      }
      if (!found) {
        add(v);
      }
    }
  }
}
