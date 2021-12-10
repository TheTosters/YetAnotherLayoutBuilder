import 'package:flutter/material.dart';

import 'widget_repository.g.dart';
import 'custom_registry.dart';
import 'style_example.dart';
import 'external_data_example.dart';

void main() {
  registerWidgetBuilders();
  registerItems();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YALB Demo',
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
  State<MyHomePage> createState() => _SelectorState();
}

class _SelectorState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            children: [
              TextButton(
                  onPressed: () => _goto(StyleExample()),
                  child: const Text("Style example")),
              TextButton(
                  onPressed: () => _goto(ExternalDataExample()),
                  child: const Text("External Data example"))
            ],
          ),
        ));
  }

  void _goto(StatefulWidget dest) {
    setState(() {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => dest));
    });
  }
}
