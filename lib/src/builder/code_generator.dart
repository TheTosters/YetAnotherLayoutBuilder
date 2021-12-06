import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/code_snippets.dart';
import 'package:yet_another_layout_builder/src/builder/reflection_writer.dart';

import 'found_items.dart';
import 'progress_collector.dart';

class CodeGenerator {
  final Iterable<FoundWidget> widgets;
  final Logger logger;
  final ProgressCollector? progressCollector;
  late bool _childHandled;
  final CodeSnippetsWriter codeExt = CodeSnippetsWriter();
  final StringBuffer sb = StringBuffer();

  CodeGenerator(
      Iterable<FoundWidget> widgets, this.progressCollector, this.logger)
      : widgets = widgets.sorted((a, b) => a.name.compareTo(b.name));

  String generate() {
    sb.clear();
    _generateNotice();
    _generateProgressLog();
    _generateImports();
    for (var widget in widgets) {
      if (widget.constructor != null) {
        _generateBuilderMethod(widget);
        widget.useCustomDataProcessor = widget.constructor?.parameters.any(
                (p) =>
                    widget.attributes.contains(p.name) &&
                    p.type.element?.kind == ElementKind.ENUM) ??
            false;
        _generateDataProcessorMethod(widget);
      }
      for (var constVal in widget.constItems.values) {
        _generateConstBuilderMethod(constVal);
      }
    }
    codeExt.writeSnippets(sb);
    _generateRegisterMethod();
    return sb.toString();
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
      for (var constVal in widget.constItems.values) {
        _writeConstBuilderRegisterCall(widget.name, constVal);
      }
    }
    sb.writeln("}\n");
  }

  void _writeConstBuilderRegisterCall(
      String parent, FoundConst constVal) {
    if (constVal.constructor != null) {
      sb.write('  Registry.addValueBuilder("');
      sb.write(parent);
      sb.write('", "');
      sb.write(constVal.destAttrib);
      sb.write('", ');
      _writeContValBuilderName(constVal);
      sb.writeln(");");
    }
  }

  void _writeWidgetBuilderRegisterCall(FoundWidget widget) {
    if (widget.constructor != null) {
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
    sb.write(widget.name.substring(0, 1).toLowerCase());
    sb.write(widget.name.substring(1));
    sb.write("BuilderAutoGen");
  }

  void _writeContValBuilderName(FoundConst constVal) {
    sb.write("_");
    sb.write(constVal.typeName.substring(0, 1).toLowerCase());
    sb.write(constVal.typeName.substring(1));
    sb.write("ValBuilderAutoGen");
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
    _verifyRequiredCtrParams(widget);
    final rw = ReflectionWriter(widget, codeExt, sb);
    _childHandled = false;

    //function signature
    sb.write("Widget ");
    _writeWidgetBuilderName(widget);
    sb.writeln("(WidgetData data) {");

    //body
    sb.write("  return ");
    sb.write(widget.name);
    sb.writeln("(");
    rw.writeCtrParams(_writeAttribGetter);

    //Special case for parenthood
    if (!_childHandled && widget.parentship != Parentship.noChildren) {
      _handleChildren(widget);
    }
    sb.writeln("  );");

    //function end
    sb.writeln("}\n");
  }

  void _handleChildren(FoundWidget widget) {
    late String expected;
    if (widget.parentship == Parentship.oneChild) {
      expected = "child";
    } else if (widget.parentship == Parentship.multipleChildren) {
      expected = "children";
    }
    final param = widget.constructor?.parameters
        .firstWhereOrNull((p) => p.name == expected);
    if (param == null) {
      final reason = "Widget ${widget.name} has $expected in xml, but"
          " corresponding class doesn't expect it.";
      logger.severe(reason);
      throw Exception(reason);
    }
    final rw = ReflectionWriter(widget, codeExt, sb);
    rw.writeCtrParam(param, _writeAttribGetter);
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

  void _writeCommentList(
      String title, int indent, Iterable? list) {
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

        final tmp = progressCollector?.data[ProgressCollector
            .keyProcessedNodes];
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

  void _generateDataProcessorMethod(FoundWidget widget) {
    if (widget.useCustomDataProcessor) {
      sb.write("dynamic ");
      _writeProcessorName(widget);
      sb.writeln("(Map<String, dynamic> inData) {");
      for (var p in widget.constructor!.parameters) {
        bool hasParam = widget.attributes.contains(p.name);
        if (hasParam && p.type.element?.kind == ElementKind.ENUM) {
          //eg.: inData.updateEnum("textAlign", TextAlign.values);
          sb.write('  inData.updateEnum("');
          sb.write(p.name);
          sb.write('", ');
          sb.write(p.type.element?.name);
          sb.writeln(".values);");
          codeExt.needMapStringToEnum();
          widget.useCustomDataProcessor = true;
        }
      }
      sb.writeln("  return inData;");
      sb.writeln("}\n");
    }
  }

  void _writeProcessorName(FoundWidget widget) {
    sb.write("_");
    sb.write(widget.name.substring(0, 1).toLowerCase());
    sb.write(widget.name.substring(1));
    sb.write("DataProcessor");
  }

  void _generateConstBuilderMethod(FoundConst constVal) {
    if (constVal.constructor != null) {
      final rw = ReflectionWriter(constVal, codeExt, sb);
      _verifyRequiredCtrParams(constVal);
      //function signature
      sb.write(constVal.typeName);
      sb.write(" ");
      _writeContValBuilderName(constVal);
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
        if (!paramUsed) {
          final reason = "Constructor ${item.constructor} requires param"
              " ${p.name} but it's not specified in xml!";
          logger.severe(reason);
          throw Exception(reason);
        }
      }
    }
  }
}
