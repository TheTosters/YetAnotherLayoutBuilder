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

It is worth to look first into examples to get general understanding what's going on. There are two
major phases of working with YALB:
- Writing xml files with layouts and generating code using builder.
- Integration of engine with application (delivering runtime data, providers or other needed things).
Keep in mind that you probably will go to each phase several times across application development,
every time you add new attributes/nodes it's worth to run builder to prepare needed helpers. However
if you don't add any new elements (no new node types, no new attributes) just reusing already present
then there is no need to perform build. Next sections guide you through those phases.

### First layout
Create empty flutter app and put simple layout named ```layout.xml``` into assets folder:
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

TODO:


## How builder works?

Before you read this paragraph please read info about registry, and how things are designed. Ok, so
in reality our builder is just a provider of code blocks (widget builders or other classes needed by
widgets) for registry. What code needs to be generated is decided by analyze of xml assets from
folder assets. If for some reason you don't want to use builder it's up to you, it's totally fine to
fill registry by manually written code.

### Builder rule: Node name

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

### Builder rule: Attribute node

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

### Builder rule: Node attributes

As mentioned earlier, for each node attributes are collected and later used to identify proper
constructor. So attribute names must match names of parameters in constructor. It's not necessary to
keep order (unless class have positional parameter!) however keeping it might prevent some
unexpected behaviours. Please keep in mind that attributes should be used only for primitive types
(String, int, double, bool) for all other types use _Attribute node_.

### Builder rule: Children

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
children it might look like:
```xml
  <Column>
     <Text data="line 1"/>
     <Text data="line 2"/>
     <Text data="line 3"/>
  </Column>
```

### Builder: Binding external data
TODO:
- usage of $
- usage of @
- bind of live values
- bind of callbacks
- bind of providers

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
