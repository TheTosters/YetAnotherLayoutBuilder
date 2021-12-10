import '../builder/annotations.dart';

@SkipWidgetBuilder()
@SpecialDataProcessor("setStyleDataProcessor")
@MatchAnyConstructor()
class YalbStyle {
  YalbStyle({
    @ConvertFunction.withFunc("double.tryParse", true, [])
    double? width,

    @ConvertFunction.withFunc("double.tryParse", true, [])
    double? height,
  });
}