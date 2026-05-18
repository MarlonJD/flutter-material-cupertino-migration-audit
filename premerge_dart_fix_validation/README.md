# Pre-Merge Dart Fix Validation

This validation path checks the Material/Cupertino migration cases against a
real `dart fix` run after installing the proposal into the Dart SDK's
`lib/_internal/fix_data.yaml`. It then runs the local full migration supplement
to cover the cases that are not expressible by the current data-driven
`replacedBy` fix alone.

Run from the repository root:

```sh
/path/to/new-enough/dart-sdk/bin/dart run tool/run_premerge_dart_fix_validation.dart
```

The script adds the temporary `library` / `newLibrary` transforms to the SDK
fix-data file if they are missing, creates a small external app with fake
`flutter`, `material_ui`, and `cupertino_ui` packages, runs `dart fix --apply`,
runs `tool/apply_full_migration.dart`, and compares the result with the
expected migration output.

It checks:

- simple Material import replacement;
- explicit `package:flutter/widgets.dart` imports for framework symbols that
  used to arrive through `material.dart`;
- `show` combinator splitting;
- export surface preservation;
- prefix preservation;
- framework symbol usage from `part` files;
- pubspec dependency additions.
