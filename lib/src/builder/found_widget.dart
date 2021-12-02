import 'package:analyzer/dart/element/element.dart';

enum Parentship { noChildren, oneChild, multipleChildren }

class FoundWidget {
  //Filled by xml analyzer
  String? name;
  Set<String> attributes = {};
  Parentship parentship = Parentship.noChildren;

  //filled by widget class validator
  ConstructorElement? constructor;

  bool useCustomDataProcessor = false;

  FoundWidget(this.name);
}
