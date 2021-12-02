import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

import 'path_matcher.dart';
import 'progress_collector.dart';
import 'widget_class_validator.dart';
import 'xml_analyzer.dart';
import 'code_generator.dart';

Builder widgetRepoBuilder(BuilderOptions options) =>
    WidgetRepositoryBuilder(options);

class WidgetRepositoryBuilder implements Builder {
  static const String outputFileName = "widget_repository.g.dart";
  static final _allFilesInAssets = Glob('assets/**');
  final BuilderOptions options;

  WidgetRepositoryBuilder(this.options);

  static AssetId _outputFile(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      path.join('lib', 'widget_repository.g.dart'),
    );
  }

  @override
  Future build(BuildStep buildStep) async {
    final logger = Logger("WidgetRepositoryBuilder");
    final progressCollector =
        options.config["collect_progress"] ? ProgressCollector() : null;

    final validator = WidgetClassValidator(logger);
    await validator.prepare(buildStep.resolver);

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

    validator.process(xmlAnalyzer.items);

    final output = _outputFile(buildStep);
    final codeGen =
        CodeGenerator(xmlAnalyzer.items.values, progressCollector, logger);
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

  @override
  final buildExtensions = const {
    r"$lib$": [outputFileName]
  };
}
