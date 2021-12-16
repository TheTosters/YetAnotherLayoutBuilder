import 'dart:collection';
import 'types.dart';

class TrackedValueIterator implements Iterator<TrackedValue> {
  TrackedValue _cur;

  TrackedValueIterator(TrackedValue first)
      : _cur = TrackedValue("", const {}, first);

  @override
  TrackedValue get current => _cur;

  @override
  bool moveNext() {
    if (_cur.next != null) {
      _cur = _cur.next!;
      return true;
    }
    return false;
  }
}

class TrackedValue with IterableMixin<TrackedValue> {
  final Map<String, dynamic> destMap;
  final String keyName;
  final TrackedValue? next;

  TrackedValue(this.keyName, this.destMap, this.next);

  @override
  Iterator<TrackedValue> get iterator => TrackedValueIterator(this);
}

/// Class used to update values in ```Map<String, dynamic>``` only if key starts
/// with ```$``` or ```@``` characters. Values for such keys are substituted
/// with corresponding value from [injectables] given in constructor. For more
/// details refer to [inject] and [reInject] methods.
class Injector {
  final ExtObjectMap injectables;
  final Map<String, TrackedValue> _objectUsageMap = {};

  Injector(this.injectables);

  Iterable<String> get namesOfUsedInjectables => _objectUsageMap.keys;

  /// Following substitution in [rawData] is done:
  /// - if key starts with [$] then value from [injectables] is taken, then
  /// call to [toString()] on this value is done, and result is put into
  /// [rawData] collection.
  /// - if key starts with [@] then value from [injectables] is taken and
  /// put into [rawData] collection.
  bool inject(Map<String, dynamic> rawData, bool track) {
    bool anyInjection = false;
    //Expect that values in rawData is always String at this moment
    rawData.updateAll((key, value) {
      if (value.startsWith("\$")) {
        anyInjection = true;
        //resolve as string
        return _processInjectable(value.substring(1), key, rawData, track)
            .toString();
      } else if (value.startsWith("@")) {
        anyInjection = true;
        //resolve as object itself
        return _processInjectable(value.substring(1), key, rawData, track);
      }
      return value;
    });
    return anyInjection;
  }

  dynamic _processInjectable(String objName, String inMapKey,
      Map<String, dynamic> destMap, bool trackResolved) {
    if (trackResolved) {
      _objectUsageMap.update(
          objName, (value) => TrackedValue(inMapKey, destMap, value),
          ifAbsent: () => TrackedValue(inMapKey, destMap, null));
    }
    if (!injectables.containsKey(objName)) {
      print("WARN xml refers to key $objName, but it's not given in objects");
    }
    return injectables[objName];
  }

  /// Goes through Maps where injectables was injected, and insert again values
  /// treating [objects] as new injectables which need to be updated. So
  /// if previously [Injector] was created with map:
  /// ```
  /// {"A": 12, "B":"text"}
  /// ```
  /// and both ```A``` and ```B``` was injected into some collections, call to
  /// ```reInject``` with following map:
  /// ```
  /// {"A": 24}
  /// ```
  /// will replace in all collections previous value of ```A``` which was 12
  /// into new 24, injected ```B``` will be unchanged.
  void reInject(ExtObjectMap objects) {
    for (var entry in objects.entries) {
      final destQueue = _objectUsageMap[entry.key];
      if (destQueue == null) {
        print("WARN updateObjects: Object with key ${entry.key} is given but"
            " it's not used in build widget process.");
        continue;
      }
      for (var d in destQueue) {
        d.destMap[d.keyName] = entry.value;
      }
    }
  }
}
