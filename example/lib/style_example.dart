import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart'
    as yalb;

class StyleExample extends StatefulWidget {
  const StyleExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _StyleExampleState();
}

class _StyleExampleState extends State<StyleExample> {
  yalb.LayoutBuilder? builder;

  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Style example"),
        ),
        body: FutureBuilder<String>(
            future: _loadFileContent("assets/styles.xml"),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                builder ??= yalb.LayoutBuilder(snapshot.data!, {});
                return builder!.build(context);
              }
              return const CircularProgressIndicator();
            }));
  }
}
