import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart'
    as yalb;

class ExternalDataExample extends StatefulWidget {
  const ExternalDataExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ExternalDataState();
}

class _ExternalDataState extends State<ExternalDataExample> {
  yalb.LayoutBuilder? builder;

  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("External data example"),
        ),
        body: FutureBuilder<String>(
            future: _loadFileContent("assets/external_data.xml"),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                builder ??= yalb.LayoutBuilder(snapshot.data!, {
                  "text_1": "My injected text",
                  "text_2": "This text cant be changed by updateObjects",
                  "text_3": "Note usage @ in xml",
                  "number": 22.44,
                  "onButtonPress": () => print("Yes, it works!"),
                  "changeableCaption": "Caption will change on press",
                  "onChangeableButtonPress": () {
                    setState(() {
                      builder?.updateObjects({"changeableCaption": "Whooaa!"});
                    });
                  },
                  "injectedWidget": const CircularProgressIndicator()
                });
                return builder!.build(context);
              }
              return const CircularProgressIndicator();
            }));
  }
}
