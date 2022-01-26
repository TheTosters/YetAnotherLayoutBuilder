import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:logging/logging.dart';

import '../dart_extensions.dart';
import '../class_finders.dart';
import '../progress_collector.dart';
import 'code_snippets.dart';

class CodeGeneratorBase {
  final Logger logger;
  final ProgressCollector? progressCollector;
  final CodeSnippetsWriter codeExt = CodeSnippetsWriter();
  final StringBuffer sb = StringBuffer();
  final ClassConstructorsCollector classCollector;

  //TODO: Very ugly, there will be a time when I come back with fire & steel
  //and purge this abomination.
  late bool childHandled;

  CodeGeneratorBase(this.classCollector, this.progressCollector, this.logger);

  void verifyRequiredCtrParams(Constructable item) {
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

  void writeAttribGetter(ParameterElement param) {
    bool canBeNull = param.type.nullabilitySuffix == NullabilitySuffix.question;
    final name = param.name;
    if (name == "child") {
      childHandled = true;
      if (canBeNull) {
        sb.write("data.children?.first");
      } else {
        sb.write("data.children!.first");
      }
    } else if (name == "children") {
      childHandled = true;
      sb.write("data.children");
      if (!canBeNull) {
        sb.write("!");
      }
    } else {
      sb.write('data["');
      sb.write(name);
      sb.write('"]');
    }
  }

  void writeStringSet(Set<String> set) {
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

  bool isBuilderSelectorNeeded(String typeName) {
    final val = classCollector.constructorsFor(typeName);
    return val.length > 1;
  }

  void writeBuilderName(String typeName, {int? index}) {
    sb.write("_");
    sb.write(typeName.deCapitalize());
    if (index != null) {
      sb.write(index);
    }
    sb.write("BuilderAutoGen");
  }

  void writeSelectorName(String typeName) {
    sb.write("_");
    sb.write(typeName.deCapitalize());
    sb.write("SelectorAutoGen");
  }
}
