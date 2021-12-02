import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;

import 'widget_class_validator.dart';
import 'xml_analyzer.dart';
import 'code_generator.dart';
import 'package:logging/logging.dart';

Builder widgetRepoBuilder(BuilderOptions options) => WidgetRepositoryBuilder();

class WidgetRepositoryBuilder implements Builder {
  static const String outputFileName = "widget_repository.g.dart";
  static final _allFilesInAssets = Glob('assets/**');

  static AssetId _outputFile(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      path.join('lib', 'widget_repository.g.dart'),
    );
  }

  @override
  Future build(BuildStep buildStep) async {
    final logger = Logger("WidgetRepositoryBuilder");
    final validator = WidgetClassValidator(logger);
    await validator.prepare(buildStep.resolver);

    final xmlAnalyzer = XmlAnalyzer(logger);
    await for (final input in buildStep.findAssets(_allFilesInAssets)) {
      final xmlStr = await buildStep.readAsString(input);
      xmlAnalyzer.process(xmlStr, input.path);
    }

    validator.process(xmlAnalyzer.items);

    final output = _outputFile(buildStep);
    final codeGen = CodeGenerator(xmlAnalyzer.items.values, logger);
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
