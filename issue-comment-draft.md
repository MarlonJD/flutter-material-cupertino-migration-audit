## Migration tooling audit prototype

I started looking into the migration tooling question here and put together a
small dependency-free audit prototype:

https://github.com/MarlonJD/flutter-material-cupertino-migration-audit

This is not meant to be a final implementation. The goal is to make the
practical migration cases concrete before deciding how much should live in
`dart fix` versus a separate migration tool.

## What the prototype reports

- Candidate `pubspec.yaml` dependency additions for `material_ui` and
  `cupertino_ui`.
- Candidate URI rewrites from Flutter SDK design imports to standalone package
  imports.
- Likely explicit Flutter framework imports, especially
  `package:flutter/widgets.dart`.
- Manual-review cases for public exports, combinators, prefixes, and `part`
  files.

## Early findings

### Straightforward cases

Simple unprefixed imports seem mechanically rewritable:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
```

to:

```dart
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
```

### The harder part

Many files use `material.dart` or `cupertino.dart` as umbrella imports for core
framework symbols such as:

```text
Widget, BuildContext, StatelessWidget, StatefulWidget, State, Text, Navigator,
EdgeInsets, Color, VoidCallback, AnimationController, TextInputFormatter
```

Since the new packages are not expected to re-export the full widgets library,
the migration often needs to add explicit framework imports.

## Edge cases that probably need special handling

### `show` combinators

These need symbol-level splitting:

```dart
import 'package:flutter/material.dart' show BuildContext, Scaffold, Widget;
```

could become something like:

```dart
import 'package:material_ui/material_ui.dart' show Scaffold;
import 'package:flutter/widgets.dart' show BuildContext, Widget;
```

### `hide` combinators

These seem risky to rewrite automatically because the hidden symbol set might
change meaning across the split packages.

### Public re-exports

These should probably be manual-review cases:

```dart
export 'package:flutter/material.dart';
export 'package:flutter/cupertino.dart';
```

Changing them can affect downstream package APIs, not just the current package.

### Prefixed imports

Prefixed design imports are mechanically easy to URI-rewrite:

```dart
import 'package:flutter/material.dart' as material;
```

However, they do not solve unprefixed framework symbol usage elsewhere in the
same file.

### `part` files

The design import can live in the library file while the framework symbol usage
appears in a `part` file, so a migration pass needs to consider the whole
library unit rather than only one file at a time.

## Question for maintainers

Does this audit direction seem useful for this issue?

If so, I can turn it into a targeted Flutter tool/framework PR after guidance on:

- where this should live;
- whether it should be a `dart fix`, Flutter tool command, or separate migration
  helper;
- which cases should be automatically fixed versus reported for manual review.
