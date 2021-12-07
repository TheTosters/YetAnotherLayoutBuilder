import 'package:analyzer/dart/element/element.dart';

enum Parentship { noChildren, oneChild, multipleChildren }

/// This is widget info class, created for each xml node which is considered
/// to be an widget for which builders should be prepared
class FoundWidget {
  final String name;
  final Set<String> attributes;
  final List<FoundConst> constItems;
  Parentship parentship = Parentship.noChildren;
  bool useCustomDataProcessor = false;

  FoundWidget(this.name, this.attributes, this.constItems);
}

/// This class holds info needed to generate builder for any constValue node
/// which later will be embed into data for widget
class FoundConst {
  /// Type name of resulting const
  final String typeName;

  /// Name of attribute to which value of this const should be written after
  /// generation
  final String destAttrib;

  final Set<String> attributes;

  FoundConst(this.typeName, this.destAttrib, Set<String> attributes)
      : attributes = Set.unmodifiable(attributes);
}
