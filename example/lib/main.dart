import 'package:example/custom_registry.dart';
import 'package:flutter/material.dart';

import 'style_example.dart';
import 'widget_repository.g.dart';

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
          TextButton(onPressed: () => _goto(StyleExample()), child: const Text("Style example"))
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
