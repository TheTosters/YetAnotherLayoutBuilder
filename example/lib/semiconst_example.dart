import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart'
    as yalb;

class SemiConstExample extends StatefulWidget {
  const SemiConstExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _BlocksState();
}

class _BlocksState extends State<SemiConstExample> {
  yalb.LayoutBuilder? builder;

  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Semi const example"),
        ),
        body: FutureBuilder<String>(
            future: _loadFileContent("assets/semi_const.xml"),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                builder ??= yalb.LayoutBuilder(
                    snapshot.data!, {"prv": _factoryDataProvider});
                return builder!.build(context);
              }
              return const CircularProgressIndicator();
            }));
  }

  List<yalb.WidgetFactoryItem> _factoryDataProvider() {
    final result = [
      yalb.WidgetFactoryItem("cont", {"injectedColor": "0xFF8800FF"}),
      yalb.WidgetFactoryItem("cont", {"injectedColor": "0xFF888888"}),
      yalb.WidgetFactoryItem("txt", {"injectedColor": "0xFFFF00FF"}),
      yalb.WidgetFactoryItem("txt", {"injectedColor": "0xFF00FF00"}),
    ];
    return result;
  }
}
