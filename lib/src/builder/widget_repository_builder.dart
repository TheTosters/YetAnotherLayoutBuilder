import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/dart_extensions.dart';

import 'found_items.dart';
import 'path_matcher.dart';
import 'progress_collector.dart';
import 'class_finders.dart';
import 'xml_analyzer.dart';
import 'code_generator.dart';

Builder widgetRepoBuilder(BuilderOptions options) =>
    WidgetRepositoryBuilder(options);

class WidgetRepositoryBuilder implements Builder {
  static const String outputFileName = "widget_repository.g.dart";
  static final _allFilesInAssets = Glob('assets/**');
  final BuilderOptions options;
  final logger = Logger("WidgetRepositoryBuilder");

  WidgetRepositoryBuilder(this.options);

  static AssetId _outputFile(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      path.join('lib', 'widget_repository.g.dart'),
    );
  }

  @override
  Future build(BuildStep buildStep) async {
    final progressCollector =
        options.config["collect_progress"] ? ProgressCollector() : null;

    final xmlAnalyzer =
        XmlAnalyzer(logger, progressCollector, options.config["ignore_nodes"]);

    PathMatcher excluder = PathMatcher(options.config["ignore_input"]);
    await for (final input in buildStep.findAssets(_allFilesInAssets)) {
      if (excluder.match(input.path)) {
        logger
            .warning("XML file '${input.path}' skipped due exclusion option.");
        progressCollector?.addIgnoredFile(input.path);
        continue;
      }
      progressCollector?.addProcessedFile(input.path);
      final xmlStr = await buildStep.readAsString(input);
      xmlAnalyzer.process(xmlStr, input.path);
    }

    final widgets = xmlAnalyzer.widgets;
    final classCollector = await _resolveClasses(buildStep, widgets);

    final output = _outputFile(buildStep);
    final codeGen =
        CodeGenerator(widgets, classCollector, progressCollector, logger);
    //this might throw exception preventing console info if success
    final srcTxt = codeGen.generate();
    //this should be printed only on success
    logger.warning("Generated $outputFileName");
    logger.warning("Don't forget to import this file and call"
        " registerWidgetBuilders() function.");
    logger.warning("Every time you add new types of nodes to xml files with"
        " layout rerun builder.");
    return buildStep.writeAsString(output, srcTxt);
  }

  Future<ClassConstructorsCollector> _resolveClasses(
      BuildStep buildStep, List<FoundWidget> widgets) async {
    //TODO: There is still problem with widgets which will have different ctrs
    List<Resolvable> allConsts = [];
    List<Resolvable> allWidgets = [];
    for (var widget in widgets) {
      allWidgets.add(Resolvable(widget.name, widget.attributes));
      for (var c in widget.constItems) {
        allConsts.add(Resolvable(c.typeName, c.attributes));
      }
    }

    final collector = ClassConstructorsCollector();

    final widgetResolver = WidgetClassFinder(collector, logger);
    await widgetResolver.prepare(buildStep.resolver);
    widgetResolver.process(allWidgets);

    final constResolver = ConstValClassFinder(collector, logger);
    await constResolver.prepare(buildStep.resolver);
    constResolver.process(allConsts);

    _widgetsCompact(widgets, collector);

    //TODO: Support this in future?
    for (var w in widgets) {
      if (collector.constructorsFor(w.name).length > 1) {
        final reason =
            "${w.name}: Multiple constructors for widget not supported";
        logger.severe(reason);
        throw Exception(reason);
      }
    }

    return collector;
  }

  @override
  final buildExtensions = const {
    r"$lib$": [outputFileName]
  };

  //Removes widgets for which constructor was not found
  //Removes repeats of this same widget type
  //combine const values for same widget type
  //combine attributes for same widget type
  //TODO: This method should be in other class, not sure which one...
  void _widgetsCompact(
      List<FoundWidget> widgets, ClassConstructorsCollector collector) {
    widgets.removeWhere((w) => !collector.hasConstructor(w.name));
    int index = 0;
    while (index < widgets.length) {
      FoundWidget widget = widgets[index];
      for (int t = widgets.length - 1; t > index; t--) {
        final other = widgets[t];
        if (widget.name == other.name) {
          widget.constItems.addAllIfAbsent(other.constItems,
              (inList, toAdd) => inList.destAttrib == toAdd.destAttrib);
          widget.attributes.addAll(other.attributes);
          widgets.removeAt(t);
        }
      }
      index++;
    }
  }
}
