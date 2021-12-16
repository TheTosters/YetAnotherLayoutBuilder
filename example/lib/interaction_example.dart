import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart'
    as yalb;

class InteractionExample extends StatefulWidget {
  const InteractionExample({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _BlocksState();
}

class _BlocksState extends State<InteractionExample> {
  yalb.LayoutBuilder? builder;
  bool editState = false;
  String enteredText = "";

  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Blocks example"),
        ),
        body: FutureBuilder<String>(
            future: _loadFileContent("assets/interaction.xml"),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                builder ??= yalb.LayoutBuilder(snapshot.data!, {
                  "checked": editState,
                  "enteredText": enteredText,
                  "onCheckboxChange": _onCheckboxChange,
                  "onTextChange": _onTextChange,
                  "onTextEditDone": _onTextEditDone,
                  "onBtnPressed": _onBtnPressed

                });
                builder?.updateObjects({"checked": editState, "enteredText": enteredText});
                return builder!.build(context);
              }
              return const CircularProgressIndicator();
            }));
  }

  void _onCheckboxChange(bool? value){
    setState( () => editState = value!);
  }

  void _onTextChange(String value){
    enteredText = value;  //No SetState! We don't want to rebuild layout
  }

  void _onTextEditDone() {
    setState((){}); //Just rebuild layout
  }

  void _onBtnPressed() {
    //since changes from edit box is done in _onTextChange field enteredText is
    //already up to date, we need just to rebuild layout to see it in text field
    setState((){}); //Just rebuild layout
  }
}
