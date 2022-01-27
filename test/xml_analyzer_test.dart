import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:yet_another_layout_builder/src/builder/found_items.dart';
import 'package:yet_another_layout_builder/src/builder/styles_collector.dart';
import 'package:yet_another_layout_builder/src/builder/xml_analyzer.dart';

const String xmlStr = '''
<YalbTree>
    <YalbStyle name="label">
        <_style __TextStyle="">
            <_color value="FF00FF" />
        </_style>
    </YalbStyle>

    <YalbStyle name="button">
        <_style __ButtonStyle="" backgroundColor="@buttonBkgCol"/>
    </YalbStyle>

    <SafeArea>
        <Column>
            <OutlinedButton _yalbStyle="button" onPressed="@onAvatarPress">
                <Text data="This is button using style"/>
            </OutlinedButton>
            <Text _yalbStyle="label" data="This is label using style" />
            <Text data="Second">
              <_style __TextStyle="">
                <_color value="FFF" />
                <_dummy __SomeType="constr" val="val">
                  <_someValue value=""/>
                </_dummy>
              </_style>
            </Text>
        </Column>
    </SafeArea>
</YalbTree>
''';

void main() {
  Logger logger = Logger("test");
  List<String> ignoredNodes = [];
  final stylesCollector = StylesCollector(logger);
  XmlAnalyzer analyzer =
      XmlAnalyzer(logger, null, ignoredNodes, stylesCollector);
  analyzer.process(xmlStr, "/test");

  List<FoundWidget> expectedWidgets = [
    _buildWidget(
        name: "YalbTree",
        attributes: {"child"},
        parentship: Parentship.oneChild,
        constItems: []),
    _buildWidget(
        name: "SafeArea",
        attributes: {"child"},
        parentship: Parentship.oneChild,
        constItems: []),
    _buildWidget(
        name: "YalbStyle",
        attributes: {"name", "style"},
        parentship: Parentship.noChildren,
        constItems: [
          _buildConst(
              typeName: "TextStyle", destAttrib: "style", attributes: {})
        ]),
    _buildWidget(
        name: "YalbStyle",
        attributes: {"name", "style"},
        parentship: Parentship.noChildren,
        constItems: [
          _buildConst(
              typeName: "ButtonStyle",
              destAttrib: "style",
              attributes: {"backgroundColor"})
        ]),
    _buildWidget(
        name: "Text",
        attributes: {"data"},
        parentship: Parentship.noChildren,
        constItems: []),
    _buildWidget(
        name: "Text",
        attributes: {"data", "style"},
        parentship: Parentship.noChildren,
        constItems: [
          _buildConst(
              typeName: "TextStyle", destAttrib: "style", attributes: {})
        ]),
    _buildWidget(
        name: "OutlinedButton",
        attributes: {"child", "onPressed"},
        parentship: Parentship.oneChild,
        constItems: []),
    _buildWidget(
        name: "Column",
        attributes: {"children"},
        parentship: Parentship.multipleChildren,
        constItems: [])
  ];

  test("Check collected widgets", () {
    for (final w in analyzer.widgets) {
      expect(_isExpectedWidget(w, expectedWidgets), true);
    }
  });

  test("Check collected const", () {
    Set<String> expConstPaths = {
      "YalbStyle/style[TextStyle]/",
      "YalbStyle/style[TextStyle]/color[Color]/",
      "YalbStyle/style[ButtonStyle]/",
      "Text/style[TextStyle]/",
      "Text/style[TextStyle]/color[Color]/",
      "Text/style[TextStyle]/dummy[SomeType:constr]/",
      "Text/style[TextStyle]/dummy[SomeType:constr]/someValue[SomeValue]/"
    };
    Set<String> result = {};
    for (final w in analyzer.widgets) {
      _appendConstPath(w.name + "/", w.constItems, result);
    }
    expect(setEquals<String>(expConstPaths, result), true);
  });
}

void _appendConstPath(
    String prefix, List<FoundConst> cList, Set<String> result) {
  for (final c in cList) {
    String item;
    if (c.designatedCtrName != null) {
      item = prefix + "${c.destAttrib}[${c.typeName}:${c.designatedCtrName}]/";
    } else {
      item = prefix + "${c.destAttrib}[${c.typeName}]/";
    }
    result.add(item);
    _appendConstPath(item, c.constItems, result);
  }
}

FoundConst _buildConst(
    {required String typeName,
    String? designatedCtrName,
    required String destAttrib,
    required Set<String> attributes}) {
  return FoundConst(typeName, destAttrib, attributes, designatedCtrName);
}

FoundWidget _buildWidget(
    {required String name,
    required Set<String> attributes,
    required Parentship parentship,
    required List<FoundConst> constItems}) {
  return FoundWidget(name, attributes, constItems, null)
    ..parentship = parentship;
}

bool _isExpectedWidget(FoundWidget w, List<FoundWidget> expected) {
  for (final exp in expected) {
    if (w.name != exp.name ||
        w.parentship != exp.parentship ||
        !setEquals<String>(w.attributes, exp.attributes)) {
      continue;
    }
    return true;
  }
  return false;
}
