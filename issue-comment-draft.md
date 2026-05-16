I started looking at migration tooling for this and built a small dependency-free
audit prototype to map the edge cases before attempting a real `dart fix`.

Early findings:

- Simple unprefixed imports can likely be URI-rewritten from
  `package:flutter/material.dart` to `package:material_ui/material_ui.dart` and
  from `package:flutter/cupertino.dart` to
  `package:cupertino_ui/cupertino_ui.dart`.
- The harder part is adding explicit framework imports. A lot of real files use
  design imports as a convenient umbrella for `Widget`, `BuildContext`,
  `StatelessWidget`, `StatefulWidget`, `State`, `Text`, `Navigator`,
  `EdgeInsets`, `Color`, `VoidCallback`, animation classes, services, etc.
- `show` combinators need symbol-level splitting. For example
  `show Scaffold, Widget, BuildContext` likely becomes a design package import
  for `Scaffold` plus `package:flutter/widgets.dart` for `Widget` and
  `BuildContext`.
- `hide` combinators and public `export 'package:flutter/material.dart';` /
  `export 'package:flutter/cupertino.dart';` should probably be manual-review
  cases because they affect downstream API surfaces.
- Prefix imports are mechanically easy to rewrite, but they do not solve
  unprefixed framework symbols. If the file already imports
  `package:flutter/widgets.dart`, that is fine; otherwise the migration needs
  more context.
- `part` files matter. The usage that requires `widgets.dart` can appear in a
  `part` file while the design import lives in the library file.

The prototype currently reports:

- candidate dependency additions;
- candidate import URI rewrites;
- likely explicit Flutter framework imports;
- manual-review notes for exports, `show` / `hide`, prefixes, and part files.

I am not proposing this as the final implementation. It is just a conservative
audit pass to make the migration cases concrete before deciding how much belongs
in `dart fix` versus a separate migration tool.

