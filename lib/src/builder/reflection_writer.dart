import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:collection/collection.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:yet_another_layout_builder/src/builder/found_items.dart';

import 'annotations.dart';
import 'code_snippets.dart';

typedef AttribAccessWriter = void Function(String, bool);
typedef VoidFunction = void Function();

class ReflectionWriter {
  final Constructable constructable;
  final NeededExtensionsCollector codeExt;
  final StringBuffer sb;

  ReflectionWriter(this.constructable, this.codeExt, this.sb);

  void writeCtrName() {
    sb.write(constructor.enclosingElement.name);
    if (constructor.name.isNotEmpty) {
      sb.write(".");
      sb.write(constructor.name);
    }
  }

  ConstructorElement get constructor => constructable.constructor!;

  void writeCtrParams(AttribAccessWriter attribWriter) {
    for (var p in constructor.parameters) {
      if (constructable.attributes.contains(p.name)) {
        writeCtrParam(p, attribWriter);
      }
    }
  }

  void writeCtrParam(ParameterElement p, AttribAccessWriter attribWriter) {
    ConvertFunction? convFun = _getConvertFunction(p);
    codeExt.needFunctionSnippets(convFun?.funcExt ?? const []);
    codeExt.needMapExtension(convFun?.mapExt ?? const []);

    print("${p.name} => ${p.metadata}");
    sb.write("    "); //lvl 2 indent
    bool canBeNull = p.type.nullabilitySuffix == NullabilitySuffix.question;
    if (p.isPositional) {
      _writeWrapped(convFun, canBeNull, () => attribWriter(p.name, canBeNull));
      sb.writeln(",");
    } else {
      sb.write(p.name);
      sb.write(": ");
      _writeWrapped(convFun, canBeNull, () => attribWriter(p.name, canBeNull));
      sb.writeln(",");
    }
  }

  void _writeWrapped(
      ConvertFunction? convFun, bool canBeNull, VoidFunction callback) {
    if (convFun != null) {
      sb.write(convFun.functionName);
      sb.write("(");
    }

    callback();

    if (convFun != null) {
      sb.write(")");
      if (!canBeNull) {
        sb.write("!");
      }
    }
  }

  ConvertFunction? _getConvertFunction(ParameterElement p) {
    final annotation = p.metadata.firstWhereOrNull(
        (an) => an.element?.enclosingElement?.name == "ConvertFunction");
    final value = annotation?.computeConstantValue();
    if (value != null) {
      return convertFunctionFrom(value);
    }
    //Check if expected param type is different then String, if yes perform
    //conversion
    if (p.type.isDartCoreInt) {
      return ConvertFunction.withFunc("int.parse", []);

    } else if (p.type.isDartCoreDouble) {
      return ConvertFunction.withFunc("double.parse", []);

    } else if (p.type.isDartCoreBool) {
      return ConvertFunction.withFunc("bool.parse", []);

    } else if (!p.type.isDartCoreString) {
      print("Probably this will cause problems, $p");
    }

    return null;
  }
}
