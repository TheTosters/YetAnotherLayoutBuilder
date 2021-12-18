# Yet Another Layout Builder
[![Pub Package](https://img.shields.io/pub/v/yet_another_layout_builder.svg)](https://pub.dev/packages/yet_another_layout_builder)
[![GitHub Issues](https://img.shields.io/github/issues/TheTosters/YetAnotherLayoutBuilder.svg)](https://github.com/TheTosters/YetAnotherLayoutBuilder/issues)
[![GitHub Forks](https://img.shields.io/github/forks/TheTosters/YetAnotherLayoutBuilder.svg)](https://github.com/TheTosters/YetAnotherLayoutBuilder/network)
[![GitHub Stars](https://img.shields.io/github/stars/TheTosters/YetAnotherLayoutBuilder.svg)](https://github.com/TheTosters/YetAnotherLayoutBuilder/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/TheTosters/YetAnotherLayoutBuilder/blob/master/LICENSE)

Yet another Flutter library for building layouts from xml assets (YALB). Using builder for
generating most of needed code to perform transform from xml to widgets.

## Features

- Automatic resolving Widget classes from xml nodes using it's names.
- Automatic resolving widgets constructor by used xml attributes / subnodes.
- This library tries to use builder to provide as much as possible code from xml assets.
- Parse of xml and processing data is separated from Widgets build phase. This allow to create
  runtime builder which can be used any time needed without time consuming parsing.

## Getting started

It is worth to look first into examples to get general overview what's going on. There are two
major phases of working with YALB:
- Writing xml files with layouts and generating code using builder.
- Integration of engine with application (delivering runtime data, providers or other needed things).
Keep in mind that you probably will go to each phase several times across application development,
every time you add new attributes/nodes it's worth to run builder to prepare needed helpers. However
if you don't add any new elements (no new node types, no new attributes) just reusing already present
then there is no need to perform build. Next sections guide you through those phases.

### First layout
Create empty flutter app and put simple layout named ```layout.xml``` into ```assets``` folder:
```xml
  <Container>
    <_color a="255" r="100" g="100" b="100"/>
    <_padding __EdgeInsets="" value="15"/>
    <Column>
       <Text data="This is Big Text" textScaleFactor="3.3"/>
    </Column>
 </Container>
```
Don't forget to add it to ```pubspec.yaml``` as follow:
```yaml
flutter:
  assets:
    - assets/layout.xml
```
Now we have to run builder, go to folder with your application and execute following line:
```
dart run build_runner build
```
Done, you should see new file named ```widget_repository.g.dart``` in your ```lib``` folder.

### Bind layout to code
After creating empty flutter app you should have single stateful widget with single state generated.
In our example class with this state is called ```_MyHomePageState```, we need to do few things to
use YALB in it. First let's add imports at top of file:

```dart
import 'package:yet_another_layout_builder/yet_another_layout_builder.dart' as yalb;
import 'widget_repository.g.dart';
```

Before we use other widget builder, we need to register all needed code helpers. To do so add
following line into your ```main``` function:

```dart
void main() {
  registerWidgetBuilders();     //<---- add this line
  runApp(const MyApp());
}
```

Now we can move to ```_MyHomePageState```, we add filed in which we hold builder, and modify
```build``` method, to use YAML builder for part of widgets tree. We keep ```Scaffold``` with title
but, inject layout into body. To perform this we need helper function ```_loadFileContent``` which
loads xml from asset into string:
```dart
  Future<String> _loadFileContent(String path) {
    return rootBundle.loadString(path);
  }
```
This method can be used with ```FutureBuilder``` along with YALB builder:
```dart
FutureBuilder<String>(
    future: _loadFileContent("assets/layout.xml"),          //Loads a xml
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        builder ??= yalb.LayoutBuilder(snapshot.data!, {}); //Create builder if it not exists
        return builder!.build(context);                     //Performs build of widget tree
      }
      return Container();
    })
```

Final code should look similar to:

```dart
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
                builder ??= yalb.LayoutBuilder(
                    snapshot.data!, {"MyText": "This is my text"});
                return builder!.build(context);
              }
              return Container();
            }));
  }
}
```
Now it's time to run it and see if it works!

## Registry.

TODO: What, why, where?

## How ```LayoutBuilder``` works?

Before you read this paragraph please read info about registry, and how things are designed. Ok, so
in reality our builder is just a provider of code blocks (widget builders or other classes needed by
widgets) for registry. What code needs to be generated is decided by analyze of xml assets from
folder assets. If for some reason you don't want to use builder it's up to you, it's totally fine to
fill registry by manually written code.

### LayoutBuilder rule: Node name

Builder follows specific rules for code generation. Depending what it finds some parsers and
extensions will be included, and sometimes not.
- If xml node name doesn't start with '_' character: It's considered to be name of widget class. It
 is case sensitive! Builder will try to find widget class which match this name.
- If xml node name start with '_' character: Then it's considered as a parameter to parent widget
node, name of parameter is name of node without '_', note lower case! Again this is case sensitive.
There are more important information about this nodes in later section!

So let's look at example for this rules:
```xml
  <Container>
     <_color a="255" r="233" g="100" b="0"/>
     <Text/>
  </Container>
```
So we have two widgets: Container and Text, and Container has a single attribute color. What this
give us? If you look into documentation of flutter widget classes, then you can use any class
constructor listed there, but you have to preserve names of attributes. If you do so, then builder
will resolve it correctly.
For example consider class constructor:
```dart
const Text(
    String data,
    {Key? key,
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    double? textScaleFactor,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
    TextHeightBehavior? textHeightBehavior}
)
```
you can use it in xml in following way:
```xml
  <Text data="some text to show" maxLines="4">
```
or (equivalent)
```xml
  <Text>
     <_data value="some text to show"/>
     <_maxLines value="4"/>
  </Text>
```
When to use which form? It's up to you however there is one limitation: If parameter is not a
primitive (String, int, double, bool) then it must be used as child node, for example:
```xml
  <Container>
    <_color a="255" r="0xFF" g="0" b="0xFF"/>
  </Container>
  <Container>
    <_color value="FF00FF"/>
  </Container>
```
As you can see Color class have several constructors, builder can detect it by matching node
attributes and prepare one or several builders. All depends what it find in xml.to

### LayoutBuilder rule: Attribute node (const value)

As mentioned earlier if node starts with '_' it's considered as a parameter for parent node (widget).
Ok we know name of attribute but what about type? There are two things which you need to know:
- If name of attribute is also type name of this attribute then you have to nothing to do (see
  above example with usage of color).
- If name and type name are different, then you have to add special attribute which name starts with
  2x '_' sign. Name of this attribute should be same as requested type name, value of it is ignored.
Ok, example:
```xml
  <Container>
    <_color a="255" r="0xFF" g="0" b="0xFF"/>
  </Container>
  <Container>
    <_padding __EdgeInsets="" value="5"/>
  </Container>
```
Color is straight forward: name and type are this same. But for padding we manually pointing
```EdgeInsets``` class (note capital case!).

### LayoutBuilder rule: Node attributes

As mentioned earlier, for each node attributes are collected and later used to identify proper
constructor. So attribute names must match names of parameters in constructor. It's not necessary to
keep order (unless class have positional parameter!) however keeping it might prevent some
unexpected behaviours. Please keep in mind that attributes should be used only for primitive types
(String, int, double, bool) for all other types use _Attribute node_.

### LayoutBuilder rule: Children

Some widgets allows (or requires) child or children. To do so just embed xml node into other xml
node. But keep in mind that child must be a widget! Look at this:

```xml
  <Container>
     <_color a="255" r="233" g="100" b="0"/>
     <Text>
       <_data value="text"/>
     </Text>
  </Container>
```
Container has a single child: Text. But Text doesn't have any child! If some widget can have
multiple children it might look like:
```xml
  <Column>
     <Text data="line 1"/>
     <Text data="line 2"/>
     <Text data="line 3"/>
  </Column>
```

### LayoutBuilder: Using external data

While creating widgets there is often need to deliver some runtime information to newly created
layout. YALB supports this in two ways:
- When creating builder through call to ```LayoutBuilder(xmlString, {})``` second argument is a
  ```Map``` with String keys and dynamic. Values from this map can be accessed in XML.
- Before call to ```build()``` method on ```LayoutBuilder``` it's possible to update objects passed
  while constructing builder by call to ```updateObjects()```. Note that updated will be only
  objects which are used by widgets.

How to access objects passed to  ```LayoutBuilder``` from XML? There are two ways to do it, let's
look into simple code:

```dart
    final builder = LayoutBuilder(xmlString, {
      "MyText": "This is my Text",
      "MyPadding": EdgeInsets.all(22),
      "ButtonCallback": () {
        setState((){
          print("Pressed!");
        });
      },
    });
    return builder.build(context);
```

and corresponding xml:

```xml
  <Container padding="@MyPadding">
    <TextButton onPressed="@ButtonCallback">
        <Text data="$MyText"/>
    </TextButton>
  </Container>
```

As you probably noted accessing to objects is done by using proper key (case sensitive!) preceded by
```$``` or ```@``` sign. What is difference?
- If you want force ```String``` value to be used, place ```$``` in front. On object taken from map
will be executed ```toString()``` method and result will be used as a parameter. *NOTE* it is not
this same ad ```Dart``` string interpolation, no extra magic can be done.
- If you want to pass object without any change of type, then use ```@```, it pass value as it is
directly to constructor parameter.

You probably noticed that any kind of data can be passed, so it's straight forward way to:
- Pass some code build widget or styling and attach it to xml based build.
- Pass callbacks and functions which can be called by widgets.
- Pass texts if any of them can be changed in runtime.
- Pass dynamic information for special nodes (described later).
- Pass builders for widgets like ```ListView```.

### LayoutBuilder: Designated constructors
After analyze of ```widget_repository.g.dart``` file sometimes methods with name
```...ValSelectorAutoGen``` can be found. This is special case when several different constructors
are used to create instance of object. There are two patterns which are used:

**Compare by given attributes, code will take form:**
```dart
if ({"a", "b", "g", "r"}.containsAll(data.keys)) {
  return _color0ValBuilderAutoGen(parent, data);
}
```

**Compare by designated constructor, code will take form:**
```dart
if (data["_ctr"] == "only") {
  return _edgeInsets0ValBuilderAutoGen(parent, data);
}
```
Notice **_ctr** key name. This is special case, when builder detect attribute in form:
```xml
<_margin __EdgeInsets="only"/>
```
Then to ```data``` associated with this node will be added key **_ctr** with value of attribute
which name starts with ```__```. In this case ```data["_ctr"] = "only"```.

#### PITFALLS

Because YALB separates parse and build phases there are some nasty pitfalls when working with
external data. Here are most common with explanation:

**Passing class field as an object.**
This might look like:
```dart
class MyState extends State<MyHomePage> {
  yalb.LayoutBuilder? builder;
  String _myField = "This is text";

@override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
        future: _loadFileContent("assets/layout.xml"),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            builder ??= yalb.LayoutBuilder(snapshot.data!, {
              "MyText": _myField,
              "callback": () {
                setState((){
                    _myField = "Second text"
                });
              },
            });
            return builder!.build(context);
          }
          return Container();
        }));
  }
}
```
Let's assume in xml you have button which call callback from objects, as a result text in some
widget should change. But this will not work. Why? Because when ```LayoutBuilder``` perform parsing
of xml it collects all data referenced by widgets described in xml. Then whole build process is
structured along with all needed data in needed places. From this moment build structure is "baked"
and will not change even if you change value of field ```_myField```. Because value taken from it
is copied and Strings in Dart are immutable. Okay... how to fix this? Here is solution:
```dart
    "callback": () {
        setState((){
            builder!.updateObjects({"MyText" : "My next text"});
        });
    },
```
or ...
```dart
    "callback": () {
        setState((){
            builder!.updateObjects({"MyText" : _myField});
        });
    },
```
if value of ```_myField``` changed and you don't want to use const text.

**External data + const value => NO GO.**

Lets take code from previous pitfall, but use it with this xml:
```xml
    <TextButton onPressed="@ButtonCallback">
        <Text>
            <_data="$MyText"/>
        </Text>
    </TextButton>
```
This creates situation in which change of ```MyText``` by any means is impossible (yet... maybe it
will change in future ). Why? Since argument for ```Text``` is given as embedded node started
with ```_``` (often referred as const value) it will be eliminated from build process after
parsing xml. Such xml will be processed in way which evaluates data argument for constructor and
then this value is considered as final, and passed to constructor without possibility to change in
any way.

**My data processor is not used? (advanced)**

If you remember section about ```Registry``` there are methods like:
```dart
Registry.addWidgetBuilder("name", _builder, dataProcessor:_dataProcessor);
```
When xml is parsed, all arguments from xml node are collected and passed to ```_dataProcessor```
which can change it as needed. But this will happen only on parse phase! When you call
```updateObjects``` on ```LayoutBuilder``` newly given values will not be passed to
```_dataProcessor```. So keep this in mind updating objects!

## Builder configuration options
As mentioned earlier Dart/Flutter build_runner is used to execute code generation for widget. There
are some extra options which can be passed to this builder. First create file ```build.yaml``` in
root of your project, and add following keys:
```yaml
targets:
  $default:
    builders:
      yet_another_layout_builder|widgetRepoBuilder:
        options:
```
Then add required options described in next sections.

### Option: ignore_input
Thi is list of xml files which should be ignored while parsing ```assets``` directory. Example:
```yaml
targets:
  $default:
    builders:
      yet_another_layout_builder|widgetRepoBuilder:
        options:
          ignore_input:
            - ignored.xml
            - another_file.xml
```

### Option: ignore_nodes
By default builder will not process any xml elements which doesn't match with classes in packages.
However sometimes it might match some name, and for some reasons this is not wanted. To prevent such
match use this option. Example:
```yaml
targets:
  $default:
    builders:
      yet_another_layout_builder|widgetRepoBuilder:
        options:
          ignore_nodes:
            - Container
            - Color
```

### Option: collect_progress
By default some basic information about parse process are collected and put as a comment into
generated file. If this is unwanted specify this option with value ```false```. Example:
```yaml
targets:
  $default:
    builders:
      yet_another_layout_builder|widgetRepoBuilder:
        options:
          collect_progress: false
```

### Option: extra_widget_packages
By default several common flutter packages are used to find ```Widget```s. However if some 3rd party
packages should be also used in this process please add it like:
```yaml
targets:
  $default:
    builders:
      yet_another_layout_builder|widgetRepoBuilder:
        options:
          extra_widget_packages:
            - package:flutter/painting.dart
```

### Option: extra_attribute_packages
This option is similar to ```extra_widget_packages```, however it applies for attributes (xml
elements started with ```_``` character). Different set of packages is used for class search, it
can be extended in following way:
```yaml
targets:
  $default:
    builders:
      yet_another_layout_builder|widgetRepoBuilder:
        options:
          extra_attribute_packages:
            - package:flutter/painting.dart
```

## Thanks

I would like to thanks guys who created [xml_layout](https://pub.dev/packages/xml_layout) package
for inspiring me to create my own variation in this area. It was fun to analyze and extend you work.