import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart'
    as yalb;

class ListViewExample extends StatefulWidget {
  const ListViewExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _BlocksState();
}

class _BlocksState extends State<ListViewExample> {
  yalb.LayoutBuilder? builder;

  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("List view example"),
        ),
        body: FutureBuilder<String>(
            future: _loadFileContent("assets/listview.xml"),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                builder ??= yalb.LayoutBuilder(snapshot.data!, {
                  "prv": _factoryDataProvider
                });
                return builder!.build(context);
              }
              return const CircularProgressIndicator();
            }));
  }

  List<yalb.WidgetFactoryItem> _factoryDataProvider() {
    final result = [
      yalb.WidgetFactoryItem("HeaderBlock", {"headerText": "List header"}),
    ];
    for(int t = 0; t < 10; t++) {
      result.add(
        yalb.WidgetFactoryItem("RowBlock", {
          "styleName": t % 2 == 0 ? "LightGray" : "DarkGray",
          "rowText": "This is $t row!"
        }),
      );
    }
    return result;
  }
}
