# Material/Cupertino Migration Fix PoC

Small, dependency-free prototype for investigating and validating Flutter's
Material/Cupertino decoupling migration tooling in
[flutter/flutter#172935](https://github.com/flutter/flutter/issues/172935).

The repository has two pieces:

- an audit script that reports the migration surface in a Flutter app;
- a full migration supplement that completes the gaps left by the current
  data-driven `replacedBy` fix behavior.

The audit reports:

- standalone package dependencies that a fix should ensure;
- rewrite targets for `package:flutter/material.dart` and
  `package:flutter/cupertino.dart` imports/exports;
- likely explicit framework imports such as `package:flutter/widgets.dart`
  because the new design packages are not expected to re-export the whole
  widgets library;
- validation notes for exports, combinators, and library parts that should be
  covered by tests before deciding whether anything needs manual handling.

The full migration supplement rewrites imports/exports to the standalone
packages, adds `package:flutter/widgets.dart` where framework symbols are still
used, splits mixed `show` combinators, preserves prefixed imports, handles
library `part` files, and adds the needed `material_ui` / `cupertino_ui`
dependencies to `pubspec.yaml`.

## Audit

Use the Dart SDK directly:

```sh
/Users/marlonjd/Developer/flutter/bin/cache/dart-sdk/bin/dart run bin/material_cupertino_import_audit.dart fixtures
```

Or from a normal Flutter checkout where `dart` is available:

```sh
dart run bin/material_cupertino_import_audit.dart path/to/flutter/app
```

## Full Migration Supplement

Run the supplement against an app root after a baseline `dart fix --apply` run:

```sh
dart run tool/apply_full_migration.dart path/to/flutter/app
```

This is intentionally a prototype of the behavior that a custom SDK-side fix
producer would need to perform if the migration must be fully covered by
`dart fix`.

## Pre-Merge Validation

The repository includes a runnable pre-merge validation script that tests the
new data-driven `library` / `newLibrary` migration shape against the real
SDK fix infrastructure. The script creates a temporary external app with fake
`flutter`, `material_ui`, and `cupertino_ui` packages, injects temporary fix
data into the selected SDK's `lib/_internal/fix_data.yaml`, runs
`dart fix --dry-run` and `dart fix --apply`, then runs the full migration
supplement and compares the result with golden output.

Run it from the repository root:

```sh
/path/to/new-enough/dart-sdk/bin/dart run tool/run_premerge_dart_fix_validation.dart
```

The validation covers simple library rewrites, explicit `widgets.dart` imports,
`show` combinators, public exports, prefix preservation, `part` files, and
pubspec dependency additions.

## Why this is useful

The open migration issue asks whether `dart fix` can automate the transition.
Maintainer feedback indicates that dependency additions, simple URI rewrites,
prefix handling, and references from part files are expected to be covered by
the existing fix infrastructure or by data-driven fix support.

This PoC is now scoped around validating and prototyping the remaining
interesting cases:

- files relying on `material.dart` / `cupertino.dart` for core framework symbols
  might need extra imports;
- `show` combinators need to be split when they mix design and framework
  symbols;
- public re-exports need to preserve both the standalone design API and the
  framework API surface that previously came through Flutter's umbrella
  libraries;
- library `part` files are included because symbol usage can appear outside the
  file that owns the import;
- pubspec dependencies need to be added alongside import rewrites.

This is intentionally conservative. It highlights migration cases to validate
without needing analyzer internals or network-installed dependencies.
