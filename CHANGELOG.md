## 0.2.0

- Attribute builder now uses path to identify builder for const values.
- Widget builder now supports nested attributes (also for styles).
- Minor code cleanups and refactors.
- Additional example for styles (nested attributes)
- First attempt to test cases.
- Fix: nested attributes present in styles only had no proper methods generated for registry.
- Introduce @null support for attribute values.
- Support for default values for optional non nullable parameters.
- Improved constructor parameter wrapping in code generation.
- Fix: Widgets which take list of children, now got it's copy.
- Fix: required imports are added to generated widget registry.
- Support for multiple constructors for widgets.

## 0.1.1

- Fix for update map function (enums).
- Reduced dependency for analyzer from 3.0.0 to 2.8.0.

## 0.1.0

- Initial version.
