import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/code_snippets.dart';
import 'package:yet_another_layout_builder/src/builder/reflection_writer.dart';

import 'class_finders.dart';
import 'found_items.dart';
import 'progress_collector.dart';
import 'dart_extensions.dart';

class CodeGenerator {
  final Iterable<FoundWidget> widgets;
  final Logger logger;
  final ProgressCollector? progressCollector;
  late bool _childHandled;
  final CodeSnippetsWriter codeExt = CodeSnippetsWriter();
  final StringBuffer sb = StringBuffer();
  final ClassConstructorsCollector classCollector;

  CodeGenerator(Iterable<FoundWidget> widgets, this.classCollector,
      this.progressCollector, this.logger)
      : widgets = widgets.sorted((a, b) => a.name.compareTo(b.name));

  String generate() {
    sb.clear();
    Set<String> constValClasses = {};
    _generateNotice();
    _generateProgressLog();
    _generateImports();
    for (var widget in widgets) {
      //TODO: Currently support only one constructor for widgets
      final constructor = _widgetCtrFor(widget.name);
      if (constructor != null) {
        _generateBuilderMethod(widget);
        widget.useCustomDataProcessor =
            _needCustomDataProcessor(widget, constructor);
        _generateDataProcessorMethod(widget, constructor);
      }
      for (var constVal in widget.constItems) {
        //_generateConstBuilderMethod(constVal);
        constValClasses.add(constVal.typeName);
      }
    }
    _generateConstValueMethods(constValClasses);
    codeExt.writeSnippets(sb);
    _generateRegisterMethod();
    return sb.toString();
  }

  ConstructorElement? _widgetCtrFor(String typeName) {
    return classCollector.constructorsFor(typeName).firstOrNull?.constructor;
  }

  void _generateImports() {
    sb.writeln("import 'package:flutter/material.dart';");
    sb.writeln(
        "import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';");
    sb.writeln();
  }

  void _generateRegisterMethod() {
    sb.writeln("void registerWidgetBuilders() {");
    for (var widget in widgets) {
      _writeWidgetBuilderRegisterCall(widget);
      for (var constVal in widget.constItems) {
        _writeConstBuilderRegisterCall(widget.name, constVal);
      }
    }
    sb.writeln("}\n");
  }

  void _writeConstBuilderRegisterCall(String parent, FoundConst constVal) {
    if (classCollector.hasConstructor(constVal.typeName)) {
      sb.write('  Registry.addValueBuilder("');
      sb.write(parent);
      sb.write('", "');
      sb.write(constVal.destAttrib);
      sb.write('", ');
      if (_isBuilderSelectorNeeded(constVal.typeName)) {
        _writeContValSelectorName(constVal.typeName);
      } else {
        _writeConstValBuilderName(constVal.typeName);
      }
      sb.writeln(");");
    }
  }

  bool _isBuilderSelectorNeeded(String typeName) {
    final val = classCollector.constructorsFor(typeName);
    return val.length > 1;
  }

  void _writeWidgetBuilderRegisterCall(FoundWidget widget) {
    if (_widgetCtrFor(widget.name) != null) {
      sb.write("  Registry.");
      sb.write(_determineAddMethod(widget));
      sb.write('("');
      sb.write(widget.name);
      sb.write('", ');
      _writeWidgetBuilderName(widget);
      if (widget.useCustomDataProcessor) {
        sb.write(", dataProcessor:");
        _writeProcessorName(widget);
      }
      sb.writeln(");");
    }
  }

  void _writeWidgetBuilderName(FoundWidget widget) {
    sb.write("_");
    sb.write(widget.name.deCapitalize());
    sb.write("BuilderAutoGen");
  }

  void _writeConstValBuilderName(String typeName, {int? index}) {
    sb.write("_");
    sb.write(typeName.deCapitalize());
    if (index != null) {
      sb.write(index);
    }
    sb.write("ValBuilderAutoGen");
  }

  void _writeContValSelectorName(String typeName) {
    sb.write("_");
    sb.write(typeName.deCapitalize());
    sb.write("ValSelectorAutoGen");
  }

  String _determineAddMethod(FoundWidget widget) {
    switch (widget.parentship) {
      case Parentship.noChildren:
        return "addWidgetBuilder";

      case Parentship.oneChild:
        return "addWidgetContainerBuilder";

      case Parentship.multipleChildren:
        return "addWidgetContainerBuilder";
    }
  }

  void _generateBuilderMethod(FoundWidget widget) {
    final widgetCtr = classCollector.constructorsFor(widget.name).first;
    _verifyRequiredCtrParams(widgetCtr);
    final rw = ReflectionWriter(widgetCtr, codeExt, sb);
    _childHandled = false;

    //function signature
    sb.write("Widget ");
    _writeWidgetBuilderName(widget);
    sb.writeln("(WidgetData data) {");

    //body
    sb.write("  return ");
    //sb.write(widget.name);
    rw.writeCtrName();
    sb.writeln("(");
    rw.writeCtrParams(_writeAttribGetter, noWrappers: true);

    //Special case for parenthood
    if (!_childHandled && widget.parentship != Parentship.noChildren) {
      _handleChildren(widget, widgetCtr);
    }
    sb.writeln("  );");

    //function end
    sb.writeln("}\n");
  }

  void _handleChildren(FoundWidget widget, Constructable widgetCtr) {
    final childParam = findChildParam(widgetCtr.constructor!);
    final childrenParam = findChildrenParam(widgetCtr.constructor!);

    final rw = ReflectionWriter(widgetCtr, codeExt, sb);
    String errorPart = "";
    if (widget.parentship == Parentship.oneChild) {
      final anyParam = childrenParam ?? childParam;
      if (anyParam != null) {
        rw.writeCtrParam(anyParam, true, _writeAttribGetter);
        return;
      }
      errorPart = "single child";

    } else if (widget.parentship == Parentship.multipleChildren) {
      if (childrenParam != null) {
        rw.writeCtrParam(childrenParam, true, _writeAttribGetter);
        return;
      }
      errorPart = "multiple children";
    }

    final reason = "Widget ${widget.name} has $errorPart in xml, but"
        " corresponding class doesn't expect it.";
    logger.severe(reason);
    throw Exception(reason);
  }

  void _writeAttribGetter(String name, bool canBeNull) {
    if (name == "child") {
      _childHandled = true;
      if (canBeNull) {
        sb.write("data.children?.first");
      } else {
        sb.write("data.children!.first");
      }
    } else if (name == "children") {
      _childHandled = true;
      sb.write("data.children");
      if (!canBeNull) {
        sb.write("!");
      }
    } else {
      sb.write('data["');
      sb.write(name);
      sb.write('"]');
      if (!canBeNull) {
        sb.write("!");
      }
    }
  }

  void _generateNotice() {
    sb.writeln("// WARNING:");
    sb.writeln("// This is auto generated file, DO NOT MODIFY.");
    sb.writeln("//");
    sb.writeln("// Don't forget to include this file and call"
        " registerWidgetBuilders() function.");
    sb.writeln("//");
    sb.writeln("// Every time you add new types of nodes to xml files with"
        " layout execute:");
    sb.writeln("// >dart run build_runner build");
    sb.writeln();
  }

  void _generateProgressLog() {
    if (progressCollector != null) {
      final tmp = progressCollector!.data[ProgressCollector.keyProcessedFiles];
      _writeProcessedFileList("Parsed files:", tmp);
      sb.writeln();

      final tmp2 = progressCollector!.data[ProgressCollector.keyIgnoredFiles];
      _writeCommentList("Found but ignored files:", 1, tmp2);
      sb.writeln();
    }
  }

  void _writeCommentList(String title, int indent, Iterable? list) {
    if (list != null && list.isNotEmpty) {
      _writeComment(title, indent);
      for (var file in list) {
        _writeComment(null, indent + 1);
        sb.writeln(file.toString());
      }
    }
  }

  void _writeProcessedFileList(String title, Iterable? list) {
    if (list != null && list.isNotEmpty) {
      _writeComment(title, 1);
      for (var file in list) {
        _writeComment(file.toString(), 2);

        final tmp =
            progressCollector?.data[ProgressCollector.keyProcessedNodes];
        final nodes = tmp?[file.toString()];
        _writeCommentList("Processed nodes:", 3, nodes);

        final tmp2 = progressCollector?.data[ProgressCollector.keyIgnoredNodes];
        final nodes2 = tmp2?[file.toString()];
        _writeCommentList("Ignored nodes:", 3, nodes2);
      }
    }
  }

  void _writeComment(String? title, int indentLvl) {
    sb.write("//");
    for (int t = 1; t < indentLvl; t++) {
      sb.write("  ");
    }
    if (title != null) {
      sb.writeln(title);
    }
  }

  void _generateDataProcessorMethod(
      FoundWidget widget, ConstructorElement ctr) {
    if (widget.useCustomDataProcessor) {
      sb.write("dynamic ");
      _writeProcessorName(widget);
      sb.writeln("(Map<String, dynamic> inData) {");
      for (var p in ctr.parameters) {
        if (!widget.attributes.contains(p.name)) {
          continue;
        }
        if (p.type.element?.kind == ElementKind.ENUM) {
          //eg.: inData.updateEnum("textAlign", TextAlign.values);
          sb.write('  inData.updateEnum("');
          sb.write(p.name);
          sb.write('", ');
          sb.write(p.type.element?.name);
          sb.writeln(".values);");
          codeExt.needMapStringToEnum();

        } else if (p.type.element?.name == "int") {
          //eg.: inData.updateInt("width");
          sb.write('  inData.updateInt("');
          sb.write(p.name);
          sb.writeln('");');
          codeExt.needMapStringToInt();

        } else if (p.type.element?.name == "double") {
          //eg.: inData.updateDouble("width");
          sb.write('  inData.updateDouble("');
          sb.write(p.name);
          sb.writeln('");');
          codeExt.needMapStringToDouble();
        } else if (p.type.element?.name == "bool") {
          //eg.: inData.updateBool("enabled");
          sb.write('  inData.updateBool("');
          sb.write(p.name);
          sb.writeln('");');
          codeExt.needMapStringToBool();
        }
      }
      sb.writeln("  return inData;");
      sb.writeln("}\n");
    }
  }

  void _writeProcessorName(FoundWidget widget) {
    sb.write("_");
    sb.write(widget.name.deCapitalize());
    sb.write("DataProcessor");
  }

  void _generateConstBuilderMethod(Constructable constVal, {int? index}) {
    if (constVal.constructor != null) {
      final rw = ReflectionWriter(constVal, codeExt, sb);
      _verifyRequiredCtrParams(constVal);

      //function signature
      sb.write(constVal.constructor!.enclosingElement.name);
      sb.write(" ");
      _writeConstValBuilderName(constVal.constructor!.enclosingElement.name,
          index: index);
      sb.writeln("(String parent, Map<String, dynamic> data) {");

      //body
      sb.write("  return ");
      rw.writeCtrName();
      sb.writeln("(");
      rw.writeCtrParams(_writeAttribGetter);
      sb.writeln("  );");

      //function end
      sb.writeln("}\n");
    }
  }

  void _verifyRequiredCtrParams(Constructable item) {
    for (var p in item.constructor!.parameters) {
      bool paramUsed = item.attributes.contains(p.name);
      if (p.isRequiredPositional || p.isRequiredNamed) {
        if (!paramUsed && !isChildParam(p)) {
          final reason = "Constructor ${item.constructor} requires param"
              " ${p.name} but it's not specified in xml!";
          logger.severe(reason);
          throw Exception(reason);
        }
      }
    }
  }

  void _generateConstValueMethods(Set<String> constValClasses) {
    for (var typeName in constValClasses) {
      final constructables = classCollector.constructorsFor(typeName);
      //NOTE: Skipp generation for length == 0
      if (constructables.length == 1) {
        _generateConstBuilderMethod(constructables[0]);
      } else if (constructables.length > 1) {
        int index = 0;
        for (var c in constructables) {
          _generateConstBuilderMethod(c, index: index);
          index++;
        }
        _generateConstSelectorMethod(constructables);
      }
    }
  }

  void _generateConstSelectorMethod(List<Constructable> constructables) {
    //function signature
    Constructable tmp = constructables.first;
    sb.write(tmp.constructor!.enclosingElement.name);
    sb.write(" ");
    _writeContValSelectorName(tmp.constructor!.enclosingElement.name);
    sb.writeln("(String parent, Map<String, dynamic> data) {");

    //body
    int index = 0;
    sb.write(" ");
    for (var ctr in constructables) {
      sb.write(" if (");
      _writeStringSet(ctr.attributes);
      sb.writeln(".containsAll(data.keys)) {");
      sb.write("    return ");
      _writeConstValBuilderName(ctr.constructor!.enclosingElement.name,
          index: index);
      sb.write("(parent, data);\n  } else ");
      index++;
    }
    //function end
    sb.write('{\n    throw Exception("Unknown constructor for class ');
    sb.write(tmp.constructor!.enclosingElement.name);
    sb.writeln(' data: \$data");');
    sb.writeln("  }\n}\n");
  }

  void _writeStringSet(Set<String> set) {
    bool needComa = false;
    sb.write("{");
    for (var s in set) {
      if (needComa) {
        sb.write(", ");
      }
      needComa = true;
      sb.write('"');
      sb.write(s);
      sb.write('"');
    }
    sb.write("}");
  }

  //Detect enums or types other than String. Don't analyze constVals those are
  //processed in different way.
  bool _needCustomDataProcessor(
      FoundWidget widget, ConstructorElement constructor) {
    Set<String> supported = const <String>{"int", "double", "bool"};

    bool result = constructor.parameters.any((p) =>
        widget.attributes.contains(p.name) &&
        (p.type.element?.kind == ElementKind.ENUM ||
            supported.contains(p.type.element?.name)));

    return result;
  }
}
