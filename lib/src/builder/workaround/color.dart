import '../annotations.dart';

/// This class do nothing, it just exposes dart:ui Color constructors and
/// annotations for builder.
class Color {
  Color(
      @ConvertFunction.withFunc("_parseIntForColor", ["parseIntForColor", "parseInt"])
      int value);
  Color.fromARGB(int a, int r, int g, int b);
  Color.fromRGBO(int r, int g, int b, double opacity);
}
