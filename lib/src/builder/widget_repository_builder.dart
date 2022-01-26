import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';
import 'package:yet_another_layout_builder/src/builder/styles_collector.dart';

import 'found_items.dart';
import 'path_matcher.dart';
import 'progress_collector.dart';
import 'class_finders.dart';
import 'widget_helpers.dart';
import 'xml_analyzer.dart';
import 'generator/code_generator.dart';

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

    final stylesCollector = StylesCollector(logger);
    final xmlAnalyzer = XmlAnalyzer(logger, progressCollector,
        options.config["ignore_nodes"] ?? [], stylesCollector);

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
    addStyleRelatedAttributes(widgets, classCollector, stylesCollector);

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
      allWidgets.add(Resolvable(widget.name, widget.attributes, null, ""));
      collectConst(widget.constItems, allConsts);
    }

    final collector = ClassConstructorsCollector();

    final widgetResolver = WidgetClassFinder(collector, logger);
    await widgetResolver.prepare(
        buildStep.resolver, options.config["extra_widget_packages"]);
    widgetResolver.process(allWidgets);

    final constResolver = ConstValClassFinder(collector, logger);
    await constResolver.prepare(
        buildStep.resolver, options.config["extra_attribute_packages"]);
    constResolver.process(allConsts);

    widgetsCompact(widgets, collector);

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
}
