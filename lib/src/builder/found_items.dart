import 'package:analyzer/dart/element/element.dart';

enum Parentship { noChildren, oneChild, multipleChildren }

class Constructable {
  //*************** Filled by xml analyzer
  /// Attributes found with xml which should be used to determine constructor
  /// for this const
  final Set<String> attributes;

  //*************** filled by class validator
  ConstructorElement? constructor;

  Constructable() : attributes = {};
  Constructable.from(Constructable other)
      : attributes = Set.from(other.attributes);

  @override
  String toString() {
    return 'Constructable{attributes: $attributes, ctr:$constructor}';
  }
}

/// This is widget info class, created for each xml node which is considered
/// to be an widget for which builders should be prepared
class FoundWidget extends Constructable {
  //*************** Filled by xml analyzer
  final String name;
  Parentship parentship = Parentship.noChildren;
  //key same as constItem.destAttrib
  final Map<String, FoundConst> constItems = {};

  bool useCustomDataProcessor = false;

  FoundWidget(this.name);
}

/// This class holds info needed to generate builder for any constValue node
/// which later will be embed into data for widget
class FoundConst extends Constructable {
  //*************** Filled by xml analyzer
  /// Type name of resulting const
  final String typeName;

  /// Name of attribute to which value of this const should be written after
  /// generation
  final String destAttrib;

  FoundConst(this.typeName, this.destAttrib);
}
