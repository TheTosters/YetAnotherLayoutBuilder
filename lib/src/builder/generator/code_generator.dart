import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/generator/code_generator_widget.dart';

import '../class_finders.dart';
import '../found_items.dart';
import '../progress_collector.dart';

class CodeGenerator extends CodeGeneratorWidgets {
  CodeGenerator(
      Iterable<FoundWidget> widgets,
      ClassConstructorsCollector classCollector,
      ProgressCollector? progressCollector,
      Logger logger)
      : super(widgets, classCollector, progressCollector, logger);

  String generate() {
    sb.clear();
    _generateNotice();
    _generateProgressLog();
    _generateImports();
    generateWidgetsCode();
    return sb.toString();
  }

  void _collectConstImports(List<FoundConst> constItems, Set<String> imports) {
    for (var c in constItems) {
      final constructable =
          classCollector.constructorsFor(c.typeName).firstOrNull;
      if (constructable != null && constructable.package.isNotEmpty) {
        imports.add(constructable.package);
      }
      if (c.constItems.isNotEmpty) {
        _collectConstImports(c.constItems, imports);
      }
    }
  }

  Set<String> _collectImports() {
    Set<String> imports = {};
    for (final widget in widgets) {
      final constructable =
          classCollector.constructorsFor(widget.name).firstOrNull;
      if (constructable != null && constructable.package.isNotEmpty) {
        imports.add(constructable.package);
      }
      _collectConstImports(widget.constItems, imports);
    }
    imports.removeWhere((element) {
      return element.isEmpty ||
          element.startsWith("package:yet_another_layout_builder");
    });
    if (imports.contains("package:flutter/material.dart")) {
      imports.removeAll([
        "package:flutter/widgets.dart",
        "package:flutter/rendering.dart",
        "package:flutter/painting.dart"
      ]);
    }
    return imports;
  }

  void _generateImports() {
    final imports = _collectImports();
    for (final import in imports) {
      sb.write("import '");
      sb.write(import);
      sb.writeln("';");
    }
    sb.writeln(
        "import 'package:yet_another_layout_builder/yet_another_layout_builder.dart';");
    sb.writeln();
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
        final nodes = (tmp?[file.toString()] as Iterable)
            .map((e) =>
                classCollector.hasConstructor(e) ? e : "$e (not resolved)")
            .toList();
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
}
