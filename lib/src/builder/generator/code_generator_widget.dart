import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import '../dart_extensions.dart';
import '../widget_helpers.dart';
import 'code_generator_const_values.dart';

import '../class_finders.dart';
import '../found_items.dart';
import '../progress_collector.dart';
import 'reflection_writer.dart';

class CodeGeneratorWidgets extends CodeGeneratorConstValues {
  final Iterable<FoundWidget> widgets;

  CodeGeneratorWidgets(
      Iterable<FoundWidget> widgets,
      ClassConstructorsCollector classCollector,
      ProgressCollector? progressCollector,
      Logger logger)
      : widgets = widgets.sorted((a, b) => a.name.compareTo(b.name)),
        super(classCollector, progressCollector, logger);

  void generateWidgetsCode() {
    List<Resolvable> allConsts = [];
    for (var widget in widgets) {
      //TODO: Currently support only one constructor for widgets
      final constructable = _widgetCtrFor(widget.name);
      final constructor = constructable?.constructor;
      if (constructor != null) {
        _generateBuilderMethod(widget);
        widget.useCustomDataProcessor =
            (constructable!.specialDataProcessor != null) ||
                _needCustomDataProcessor(widget, constructor);

        _generateDataProcessorMethod(widget, constructor);
      }
      collectConst(widget.constItems, allConsts);
    }
    final constValClasses = allConsts.map((e) => e.typeName).toSet();
    generateConstValueMethods(constValClasses);
    codeExt.writeSnippets(sb);
    _generateRegisterMethod();
  }

  //Detect enums or types other than String. Don't analyze constVals those are
  //processed in different way.
  bool _needCustomDataProcessor(
      FoundWidget widget, ConstructorElement constructor) {
    Set<String> supported = const <String>{"int", "double", "bool"};

    bool result = constructor.parameters.any((p) =>
    widget.attributes.contains(p.name) &&
        (p.type.element?.kind == ElementKind.ENUM ||
            supported.contains(p.type.element?.name)));

    return result;
  }

  void _generateRegisterMethod() {
    sb.writeln("void registerWidgetBuilders() {");
    for (var widget in widgets) {
      _writeWidgetBuilderRegisterCall(widget);
      if (widget.constItems.isNotEmpty) {
        writeConstBuilder(widget.name, widget.constItems);
      }
    }
    sb.writeln("}\n");
  }

  void _writeWidgetBuilderRegisterCall(FoundWidget widget) {
    final widgetCtr = _widgetCtrFor(widget.name);
    if (widgetCtr?.constructor != null) {
      if (widgetCtr?.skipBuilder == false) {
        sb.write("  Registry.");
        sb.write(_determineAddMethod(widget));
        sb.write('("');
        sb.write(widget.name);
        sb.write('", ');
        writeBuilderName(widget.name);
        if (widget.useCustomDataProcessor) {
          sb.write(", dataProcessor:");
          _writeProcessorName(widget);
        }
        sb.writeln(");");
      } else if (widgetCtr?.specialDataProcessor != null) {
        assert(widget.useCustomDataProcessor);
        sb.write("  Registry.");
        sb.write(widgetCtr?.specialDataProcessor);
        sb.write('(');
        _writeProcessorName(widget);
        sb.writeln(");");
      }
    }
  }

  String _determineAddMethod(FoundWidget widget) {
    switch (widget.parentship) {
      case Parentship.noChildren:
        return "addWidgetBuilder";

      case Parentship.oneChild:
        return "addWidgetContainerBuilder";

      case Parentship.multipleChildren:
        return "addWidgetContainerBuilder";

      default:
        {
          final r = "Internal error: Widget ${widget.name} has parentship set"
              " to ${widget.parentship}, this is illegal here.";
          logger.severe(r);
          throw Exception(r);
        }
    }
  }

  void _generateBuilderMethod(FoundWidget widget) {
    final widgetCtr = _widgetCtrFor(widget.name);
    if (widgetCtr?.skipBuilder == true) {
      return;
    }
    verifyRequiredCtrParams(widgetCtr!);
    final rw = ReflectionWriter(widgetCtr, codeExt, sb);
    childHandled = false;

    //function signature
    sb.write("Widget ");
    writeBuilderName(widget.name);
    sb.writeln("(WidgetData data) {");

    //body
    sb.write("  return ");
    //sb.write(widget.name);
    rw.writeCtrName();
    sb.writeln("(");
    rw.writeCtrParams(writeAttribGetter, noWrappers: true);

    //Special case for parenthood
    if (!childHandled && widget.parentship != Parentship.noChildren) {
      _handleChildren(widget, widgetCtr);
    }
    sb.writeln("  );");

    //function end
    sb.writeln("}\n");
  }

  void _handleChildren(FoundWidget widget, Constructable widgetCtr) {
    final childParam = findChildParam(widgetCtr.constructor!);
    final childrenParam = findChildrenParam(widgetCtr.constructor!);

    final rw = ReflectionWriter(widgetCtr, codeExt, sb);
    String errorPart = "";
    if (widget.parentship == Parentship.oneChild) {
      final anyParam = childrenParam ?? childParam;
      if (anyParam != null) {
        rw.writeCtrParam(anyParam, true, writeAttribGetter);
        return;
      }
      errorPart = "single child";
    } else if (widget.parentship == Parentship.multipleChildren) {
      if (childrenParam != null) {
        rw.writeCtrParam(childrenParam, true, writeAttribGetter);
        return;
      }
      errorPart = "multiple children";
    }

    final reason = "Widget ${widget.name} has $errorPart in xml, but"
        " corresponding class doesn't expect it.";
    logger.severe(reason);
    throw Exception(reason);
  }

  Constructable? _widgetCtrFor(String typeName) {
    return classCollector.constructorsFor(typeName).firstOrNull;
  }


  void _generateDataProcessorMethod(
      FoundWidget widget, ConstructorElement ctr) {
    if (widget.useCustomDataProcessor) {
      sb.write("dynamic ");
      _writeProcessorName(widget);
      sb.writeln("(Map<String, dynamic> inData) {");
      for (var p in ctr.parameters) {
        if (!widget.attributes.contains(p.name)) {
          continue;
        }
        if (p.type.element?.kind == ElementKind.ENUM) {
          //eg.: inData.updateEnum("textAlign", TextAlign.values);
          sb.write('  inData.updateEnum("');
          sb.write(p.name);
          sb.write('", ');
          sb.write(p.type.element?.name);
          sb.writeln(".values);");
          codeExt.needMapStringToEnum();
        } else if (p.type.element?.name == "int") {
          //eg.: inData.updateInt("width");
          sb.write('  inData.updateInt("');
          sb.write(p.name);
          sb.writeln('");');
          codeExt.needMapStringToInt();
        } else if (p.type.element?.name == "double") {
          //eg.: inData.updateDouble("width");
          sb.write('  inData.updateDouble("');
          sb.write(p.name);
          sb.writeln('");');
          codeExt.needMapStringToDouble();
        } else if (p.type.element?.name == "bool") {
          //eg.: inData.updateBool("enabled");
          sb.write('  inData.updateBool("');
          sb.write(p.name);
          sb.writeln('");');
          codeExt.needMapStringToBool();
        }
      }
      sb.writeln("  return inData;");
      sb.writeln("}\n");
    }
  }

  void _writeProcessorName(FoundWidget widget) {
    sb.write("_");
    sb.write(widget.name.deCapitalize());
    sb.write("DataProcessor");
  }

}
