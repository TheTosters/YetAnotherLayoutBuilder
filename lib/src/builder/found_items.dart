enum Parentship { noChildren, oneChild, multipleChildren, oneChildOrNone, multipleChildrenOrNone }

/// This is widget info class, created for each xml node which is considered
/// to be an widget for which builders should be prepared
class FoundWidget {
  final String name; //equivalent of type name eg. "Container"
  final Set<String> attributes;
  final List<FoundConst> constItems;
  Parentship parentship = Parentship.noChildren;
  bool useCustomDataProcessor = false;

  FoundWidget(this.name, this.attributes, this.constItems);

  @override
  String toString() {
    return 'FoundWidget{name: $name}';
  }
}

/// This class holds info needed to generate builder for any constValue node
/// which later will be embed into data for widget
class FoundConst {
  /// Type name of resulting const
  final String typeName;

  //Value of type pointing attrib in form __EdgeInsets="fromLTRB" -> fromLTRB
  final String? designatedCtrName;

  /// Name of attribute to which value of this const should be written after
  /// generation
  final String destAttrib;

  final Set<String> attributes;
  final List<FoundConst> constItems;

  FoundConst(this.typeName, this.destAttrib, Set<String> attributes,
      this.designatedCtrName)
      : attributes = Set.from(attributes),
        constItems = [];

  @override
  String toString() {
    return 'FoundConst{typeName: $typeName, destAttrib: $destAttrib}';
  }
}
