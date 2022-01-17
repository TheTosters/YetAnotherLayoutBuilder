import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';

import 'annotations.dart';
import 'class_finders.dart';
import 'code_snippets.dart';

typedef AttribAccessWriter = void Function(ParameterElement);
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

  void writeCtrParams(AttribAccessWriter attribWriter,
      {bool noWrappers = false}) {
    for (var p in constructor.parameters) {
      if (constructable.attributes.contains(p.name)) {
        writeCtrParam(p, noWrappers, attribWriter);
      }
    }
  }

  void writeCtrParam(
      ParameterElement p, bool noWrappers, AttribAccessWriter attribWriter) {
    ConvertFunction? convFun = noWrappers ? null : _getConvertFunction(p);
    codeExt.needFunctionSnippets(convFun?.funcExt ?? const []);
    codeExt.needMapExtension(convFun?.mapExt ?? const []);

    sb.write("    "); //lvl 2 indent
    if (p.isPositional) {
      _writeWrapped(p, convFun, () => attribWriter(p));
      sb.writeln(",");
    } else {
      sb.write(p.name);
      sb.write(": ");
      _writeWrapped(p, convFun, () => attribWriter(p));
      sb.writeln(",");
    }
  }

  void _writeWrapped(
      ParameterElement p, ConvertFunction? convFun, VoidFunction callback) {
    if (p.name == "child" || p.name == "children") {
      callback();
      return;
    }
    if (convFun != null) {
      sb.write(convFun.functionName);
      sb.write("(");
    }

    callback();

    bool canBeNull = p.type.nullabilitySuffix == NullabilitySuffix.question;
    if (convFun != null) {
      if (convFun.nullableResult) {
        sb.write(" ?? ''");
      }
      sb.write(")");
      if (convFun.nullableResult) {
        if (p.hasDefaultValue) {
          sb.write(" ?? ");
          sb.write(p.defaultValueCode);
        } else if (!canBeNull) {
          sb.write("!");
        }
      }
    } else {
      //No convert function, but still need to check
      if (p.hasDefaultValue) {
        sb.write(" ?? ");
        sb.write(p.defaultValueCode);
      } else if (!canBeNull) {
        sb.write("!");
      }
    }
  }

  ConvertFunction? _getConvertFunction(ParameterElement p) {
    final annotation = findAnnotation(p, "ConvertFunction");
    final value = annotation?.computeConstantValue();
    if (value != null) {
      return convertFunctionFrom(value);
    }
    //Check if expected param type is different then String, if yes perform
    //conversion
    if (p.type.isDartCoreInt) {
      return p.type.nullabilitySuffix == NullabilitySuffix.question
          ? ConvertFunction.withFunc("int.tryParse", true, [])
          : ConvertFunction.withFunc("int.parse", false, []);
    } else if (p.type.isDartCoreDouble) {
      return p.type.nullabilitySuffix == NullabilitySuffix.question
          ? ConvertFunction.withFunc("double.tryParse", true, [])
          : ConvertFunction.withFunc("double.parse", false, []);
    } else if (p.type.isDartCoreBool) {
      return ConvertFunction.withFunc("'true' == ", false, []);
    } else if (!p.type.isDartCoreString) {
      print("Probably this will cause problems, $p");
    }

    return null;
  }
}
