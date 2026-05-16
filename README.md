# Material/Cupertino Migration Audit PoC

Small, dependency-free prototype for investigating Flutter's Material/Cupertino
decoupling migration tooling in
[flutter/flutter#172935](https://github.com/flutter/flutter/issues/172935).

The script does not try to rewrite code. It audits Dart files and reports the
places where an automated migration would probably need to:

- add `material_ui` / `cupertino_ui` dependencies;
- rewrite `package:flutter/material.dart` and `package:flutter/cupertino.dart`
  imports to standalone package imports;
- add explicit framework imports such as `package:flutter/widgets.dart` because
  the new design packages are not expected to re-export the whole widgets
  library;
- ask for manual review around `export`, `show` / `hide`, prefix imports, and
  `part` files.

## Run

Use the Dart SDK directly:

```sh
/Users/marlonjd/Developer/flutter/bin/cache/dart-sdk/bin/dart run bin/material_cupertino_import_audit.dart fixtures
```

Or from a normal Flutter checkout where `dart` is available:

```sh
dart run bin/material_cupertino_import_audit.dart path/to/flutter/app
```

## Why this is useful

The open migration issue asks whether `dart fix` or another tool can automate
the transition. This PoC maps the practical cases a fix would need to handle:

- simple imports are easy to rewrite;
- files relying on `material.dart` / `cupertino.dart` for core framework symbols
  need extra imports;
- `show` combinators need symbol-level splitting;
- `hide` combinators and re-exports are likely manual-review cases;
- library `part` files can make symbol usage appear outside the file that owns
  the import.

This is intentionally conservative. It highlights risk and migration shape
without needing analyzer internals or network-installed dependencies.

