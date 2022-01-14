import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart'
as yalb;

class StyleTwoExample extends StatefulWidget {
  const StyleTwoExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _StyleTwoExampleState();
}

class _StyleTwoExampleState extends State<StyleTwoExample> {
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
            future: _loadFileContent("assets/styles2.xml"),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                builder ??= yalb.LayoutBuilder(snapshot.data!, {
                  "buttonBkgCol": MaterialStateProperty.all(const Color(0xFF0000FF))
                });
                return builder!.build(context);
              }
              return const CircularProgressIndicator();
            }));
  }
}
