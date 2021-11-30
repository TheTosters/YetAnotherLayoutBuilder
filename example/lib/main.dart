import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart' as yalb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Yet Another Layout Builder'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  yalb.LayoutBuilder? builder;
  
  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder<String>(
          future: _loadFileContent("assets/layout.xml"),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              builder ??= yalb.LayoutBuilder();
              return builder!.build(context);
            }
            return Container();
          })
    );
  }
}
