import 'package:logging/logging.dart';
import '../class_finders.dart';
import '../dart_extensions.dart';
import '../found_items.dart';
import '../progress_collector.dart';

import 'code_generator_base.dart';
import 'reflection_writer.dart';

class CodeGeneratorConstValues extends CodeGeneratorBase {
  CodeGeneratorConstValues(
      ClassConstructorsCollector classCollector,
      ProgressCollector? progressCollector,
      Logger logger)
      : super(classCollector, progressCollector, logger);

  void generateConstValueMethods(Set<String> constValClasses) {
    for (var typeName in constValClasses) {
      final constructables = classCollector.constructorsFor(typeName);
      //NOTE: Skipp generation for length == 0
      if (constructables.length == 1) {
        _generateConstBuilderMethod(constructables[0]);
      } else if (constructables.length > 1) {
        //Designated constructor first, then: more params -> higher in list
        constructables.sort((a, b) {
          if (a.designatedCtrName != null) {
            return b.designatedCtrName == null ? -1 : 0;
          } else {
            return b.attributes.length - a.attributes.length;
          }
        });
        int index = 0;
        for (var c in constructables) {
          _generateConstBuilderMethod(c, index: index);
          index++;
        }
        _generateConstSelectorMethod(constructables);
      }
    }
  }

  void _generateConstBuilderMethod(Constructable constVal, {int? index}) {
    if (constVal.constructor != null) {
      final rw = ReflectionWriter(constVal, codeExt, sb);
      verifyRequiredCtrParams(constVal);

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
      rw.writeCtrParams(writeAttribGetter);
      sb.writeln("  );");

      //function end
      sb.writeln("}\n");
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
      if (ctr.designatedCtrName != null) {
        //Search designated ctr with key '_ctr'
        sb.write('data["_ctr"] == "');
        sb.write(ctr.designatedCtrName);
        sb.writeln('") {');
      } else {
        //Just attributes
        writeStringSet(ctr.attributes);
        sb.writeln(".containsAll(data.keys)) {");
      }
      sb.write("    return ");
      _writeConstValBuilderName(ctr.constructor!.enclosingElement.name,
          index: index);
      sb.write("(parent, data);\n  } else");
      index++;
    }
    //function end
    sb.write('{\n    throw Exception("Unknown constructor for class ');
    sb.write(tmp.constructor!.enclosingElement.name);
    sb.writeln(' data: \$data");');
    sb.writeln("  }\n}\n");
  }


  void _writeConstBuilderRegisterCall(String inTreePath, FoundConst constVal) {
    if (classCollector.hasConstructor(constVal.typeName)) {
      sb.write('  Registry.addValueBuilder("');
      sb.write(inTreePath);
      sb.write('/_');
      sb.write(constVal.destAttrib);
      sb.write('", "');
      sb.write(constVal.typeName);
      sb.write('", ');
      if (_isBuilderSelectorNeeded(constVal.typeName)) {
        _writeContValSelectorName(constVal.typeName);
      } else {
        _writeConstValBuilderName(constVal.typeName);
      }
      sb.writeln(");");
    }
  }

  void writeConstBuilder(String inTreePath, List<FoundConst> constItems) {
    for (var constVal in constItems) {
      _writeConstBuilderRegisterCall(inTreePath, constVal);
      if (constVal.constItems.isNotEmpty) {
        writeConstBuilder(
            inTreePath + '/_' + constVal.destAttrib, constVal.constItems);
      }
    }
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

  bool _isBuilderSelectorNeeded(String typeName) {
    final val = classCollector.constructorsFor(typeName);
    return val.length > 1;
  }

}
