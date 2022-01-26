import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../class_finders.dart';
import '../dart_extensions.dart';
import '../found_items.dart';
import '../progress_collector.dart';
import '../widget_helpers.dart';
import 'code_generator_const_values.dart';
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
      final constructables = classCollector.constructorsFor(widget.name);
      if (constructables.length == 1) {
        final constructable = constructables[0];
        _generateBuilderMethod(widget, constructable);
        widget.useCustomDataProcessor =
            (constructable.specialDataProcessor != null) ||
                _needCustomDataProcessor(widget, constructable.constructor!);
        _generateDataProcessorMethod(
            widget, constructable.constructor!.parameters);
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
        List<ParameterElement> ctrParams = [];
        for (var c in constructables) {
          _generateBuilderMethod(widget, c, index: index);
          widget.useCustomDataProcessor |= (c.specialDataProcessor != null) ||
              _needCustomDataProcessor(widget, c.constructor!);
          ctrParams.addAllIfAbsent(
              c.constructor!.parameters,
              (inList, newValue) =>
                  inList.name == newValue.name && inList.type == newValue.type);
          index++;
        }
        _generateDataProcessorMethod(widget, ctrParams);
        _generateWidgetSelectorMethod(constructables, widget.parentship);
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
    final widgetCtr = classCollector.constructorsFor(widget.name).firstOrNull;
    if (widgetCtr?.constructor != null) {
      //TODO: Observer, this can be potentialy problematic
      //if one constructor should be skipped, and another not
      if (widgetCtr?.skipBuilder == false) {
        sb.write("  Registry.");
        sb.write(_determineAddMethod(widget));
        sb.write('("');
        sb.write(widget.name);
        sb.write('", ');
        if (isBuilderSelectorNeeded(widget.name)) {
          writeSelectorName(widget.name);
        } else {
          writeBuilderName(widget.name);
        }
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

  void _generateBuilderMethod(FoundWidget widget, Constructable widgetCtr,
      {int? index}) {
    if (widgetCtr.skipBuilder == true) {
      return;
    }
    verifyRequiredCtrParams(widgetCtr);
    final rw = ReflectionWriter(widgetCtr, codeExt, sb);
    childHandled = false;

    //function signature
    sb.write(widget.name);
    sb.write(" ");
    writeBuilderName(widget.name, index: index);
    sb.writeln("(WidgetData data) {");

    //body
    sb.write("  return ");
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
/* TODO: what to do here?
    final reason = "Widget ${widget.name} has $errorPart in xml, but"
        " corresponding class doesn't expect it.";
    logger.severe(reason);
    throw Exception(reason);
 */
  }

  void _generateDataProcessorMethod(
      FoundWidget widget, Iterable<ParameterElement> ctrParams) {
    if (widget.useCustomDataProcessor) {
      sb.write("dynamic ");
      _writeProcessorName(widget);
      sb.writeln("(Map<String, dynamic> inData) {");
      for (var p in ctrParams) {
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

  void _generateWidgetSelectorMethod(
      List<Constructable> constructables, Parentship parentship) {
    //function signature
    Constructable tmp = constructables.first;
    sb.write(tmp.constructor!.enclosingElement.name);
    sb.write(" ");
    writeSelectorName(tmp.constructor!.enclosingElement.name);
    sb.writeln("(WidgetData wData) {");

    //body
    int index = 0;
    sb.write(" ");
    bool hasDefaultCtr = false;
    for (var ctr in constructables) {
      if (index != 0) {
        sb.write(" else");
      }
      if (ctr.designatedCtrName != null) {
        //Search designated ctr with key '_ctr'
        sb.write(' if (wData.data["_ctr"] == "');
        sb.write(ctr.designatedCtrName);
        sb.writeln('") {');
      } else {
        //Just attributes
        hasDefaultCtr |= _constructConditionForParams(ctr.attributes);
        // sb.write("wData.data.isNotEmpty && ");
        // writeStringSet(ctr.attributes);
        // sb.writeln(".containsAll(wData.data.keys)) {");
      }
      sb.write("    return ");
      writeBuilderName(ctr.constructor!.enclosingElement.name, index: index);
      sb.write("(wData);\n  }");
      index++;
    }
    if (!hasDefaultCtr) {
      //function end
      sb.write(' else {\n    throw Exception("Unknown constructor for class ');
      sb.write(tmp.constructor!.enclosingElement.name);
      sb.writeln(' data: \$wData");');
      sb.writeln("  }\n");
    }
    sb.writeln("\n}\n");
  }

  bool _constructConditionForParams(Set<String> attributes) {
    Iterable<String> filtered = attributes
        .where((element) => element != "children" && element != "child");
    if (filtered.isEmpty) {
      sb.write(" {\n");
      return true;
    }
    sb.write(" if (wData.data.isNotEmpty && ");
    writeStringSet(filtered);
    sb.writeln(".containsAll(wData.data.keys)) {");
    return false;
  }
}
