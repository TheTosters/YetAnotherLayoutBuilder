import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/code_snippets.dart';

import 'found_widget.dart';
import 'progress_collector.dart';

class CodeGenerator {
  final Iterable<FoundWidget> widgets;
  final Logger logger;
  final ProgressCollector? progressCollector;
  late bool _childHandled;

  final Set<CodeSnippets> _neededExt = {};

  CodeGenerator(
      Iterable<FoundWidget> widgets, this.progressCollector, this.logger)
      : widgets = widgets.sorted((a, b) => a.name!.compareTo(b.name!));

  String generate() {
    StringBuffer sb = StringBuffer();
    _generateNotice(sb);
    _generateProgressLog(sb);
    _generateImports(sb);
    for (var widget in widgets) {
      if (widget.constructor != null) {
        _generateBuilderMethod(widget, sb);
        widget.useCustomDataProcessor = widget.constructor?.parameters.any(
                (p) =>
                    widget.attributes.contains(p.name) &&
                    p.type.element?.kind == ElementKind.ENUM) ??
            false;
        _generateDataProcessorMethod(widget, sb);
      }
    }
    for (var ext in _neededExt) {
      sb.write(codeSnippetsPool[ext]);
      sb.writeln("\n"); //2x /n :P
    }
    _generateRegisterMethod(sb);
    return sb.toString();
  }

  void _generateImports(StringBuffer sb) {
    sb.writeln("import 'package:flutter/material.dart';");
    sb.writeln(
        "import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';");
    sb.writeln();
  }

  void _generateRegisterMethod(StringBuffer sb) {
    sb.writeln("void registerWidgetBuilders() {");
    for (var widget in widgets) {
      if (widget.constructor == null) {
        continue;
      }
      sb.write("  Registry.");
      sb.write(_determineAddMethod(widget));
      sb.write("(\"");
      sb.write(widget.name);
      sb.write("\", ");
      _writeBuilderName(widget, sb);
      if (widget.useCustomDataProcessor) {
        sb.write(", dataProcessor:");
        _writeProcessorName(widget, sb);
      }
      sb.writeln(");");
    }
    sb.writeln("}\n");
  }

  void _writeBuilderName(FoundWidget widget, StringBuffer sb) {
    sb.write("_");
    sb.write(widget.name?.substring(0, 1).toLowerCase());
    sb.write(widget.name?.substring(1));
    sb.write("BuilderAutoGen");
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

  void _generateBuilderMethod(FoundWidget widget, StringBuffer sb) {
    //function signature
    sb.write("Widget ");
    _writeBuilderName(widget, sb);
    sb.writeln("(WidgetData data) {");
    //body
    sb.write("  return ");
    sb.write(widget.name);
    sb.writeln("(");
    _childHandled = false;
    for (var p in widget.constructor!.parameters) {
      bool inAttribs = widget.attributes.contains(p.name);
      if (p.isRequiredPositional || p.isRequiredNamed) {
        if (!inAttribs) {
          final reason = "Constructor ${widget.constructor} requires param"
              " ${p.name} but it's not specified in xml!";
          logger.severe(reason);
          throw Exception(reason);
        }
      }
      if (inAttribs) {
        _writeCtrParam(p, sb);
      }
    }
    //Special case for parenthood
    if (!_childHandled && widget.parentship != Parentship.noChildren) {
      _handleChildren(widget, sb);
    }
    sb.writeln("  );");
    //function end
    sb.writeln("}\n");
  }

  void _handleChildren(FoundWidget widget, StringBuffer sb) {
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
    _writeCtrParam(param, sb);
  }

  void _writeCtrParam(ParameterElement p, StringBuffer sb) {
    sb.write("    "); //lvl 2 indent
    bool canBeNull = p.type.nullabilitySuffix == NullabilitySuffix.question;
    if (p.isPositional) {
      _writeAttribGetter(p.name, canBeNull, sb);
      sb.writeln(",");
    } else {
      sb.write(p.name);
      sb.write(": ");
      _writeAttribGetter(p.name, canBeNull, sb);
      sb.writeln(",");
    }
  }

  void _writeAttribGetter(String name, bool canBeNull, StringBuffer sb) {
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

  void _generateNotice(StringBuffer sb) {
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

  void _generateProgressLog(StringBuffer sb) {
    if (progressCollector == null) {
      return;
    }
    final tmp = progressCollector!.data[ProgressCollector.keyProcessedFiles];
    _writeProcessedFileList("Parsed files:", tmp, sb);
    sb.writeln();

    final tmp2 = progressCollector!.data[ProgressCollector.keyIgnoredFiles];
    _writeCommentList("Found but ignored files:", 1, tmp2, sb);
    sb.writeln();
  }

  void _writeCommentList(
      String title, int indent, Iterable? list, StringBuffer sb) {
    if (list != null && list.isNotEmpty) {
      _writeComment(title, indent, sb);
      for (var file in list) {
        _writeComment(null, indent + 1, sb);
        sb.writeln(file.toString());
      }
    }
  }

  void _writeProcessedFileList(String title, Iterable? list, StringBuffer sb) {
    if (list == null || list.isEmpty) {
      return;
    }
    _writeComment(title, 1, sb);
    for (var file in list) {
      _writeComment(file.toString(), 2, sb);

      final tmp = progressCollector?.data[ProgressCollector.keyProcessedNodes];
      final nodes = tmp?[file.toString()];
      _writeCommentList("Processed nodes:", 3, nodes, sb);

      final tmp2 = progressCollector?.data[ProgressCollector.keyIgnoredNodes];
      final nodes2 = tmp2?[file.toString()];
      _writeCommentList("Ignored nodes:", 3, nodes2, sb);
    }
  }

  void _writeComment(String? title, int indentLvl, StringBuffer sb) {
    sb.write("//");
    for (int t = 1; t < indentLvl; t++) {
      sb.write("  ");
    }
    if (title != null) {
      sb.writeln(title);
    }
  }

  void _generateDataProcessorMethod(FoundWidget widget, StringBuffer sb) {
    if (!widget.useCustomDataProcessor) {
      return;
    }
    sb.write("dynamic ");
    _writeProcessorName(widget, sb);
    sb.writeln("(Map<String, dynamic> inData) {");
    for (var p in widget.constructor!.parameters) {
      bool inAttribs = widget.attributes.contains(p.name);
      if (inAttribs && p.type.element?.kind == ElementKind.ENUM) {
        //eg.: inData.updateEnum("textAlign", TextAlign.values);
        sb.write('  inData.updateEnum("');
        sb.write(p.name);
        sb.write('", ');
        sb.write(p.type.element?.name);
        sb.writeln(".values);");
        _neededExt.add(CodeSnippets.mapStringToEnum);
        widget.useCustomDataProcessor = true;
      }
    }
    sb.writeln("  return inData;");
    sb.writeln("}\n");
  }

  void _writeProcessorName(FoundWidget widget, StringBuffer sb) {
    sb.write("_");
    sb.write(widget.name?.substring(0, 1).toLowerCase());
    sb.write(widget.name?.substring(1));
    sb.write("DataProcessor");
  }
}
