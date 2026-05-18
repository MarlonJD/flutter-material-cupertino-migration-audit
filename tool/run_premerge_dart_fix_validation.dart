import 'dart:io';

const _fixDataInsert = '''
  - title: 'Migrate Material library import'
    date: 2026-05-07
    library: 'package:flutter/material.dart'
    changes:
      - kind: 'replacedBy'
        newLibrary: 'package:material_ui/material_ui.dart'

  - title: 'Migrate Cupertino library import'
    date: 2026-05-07
    library: 'package:flutter/cupertino.dart'
    changes:
      - kind: 'replacedBy'
        newLibrary: 'package:cupertino_ui/cupertino_ui.dart'

''';

void main() {
  final dart = Platform.resolvedExecutable;
  final sdkRoot = Directory(File(dart).parent.parent.path);
  final sdkFixData = File('${sdkRoot.path}/lib/_internal/fix_data.yaml');
  if (!sdkFixData.existsSync()) {
    stderr.writeln('Could not find SDK fix data at ${sdkFixData.path}');
    exitCode = 66;
    return;
  }

  _installSdkFixData(sdkFixData);

  final root = Directory.systemTemp.createTempSync('sdk_library_fix_cases_');
  final app = Directory('${root.path}/app')..createSync(recursive: true);
  _writeFixture(root, app);

  final checks = [
    _run(dart, ['analyze', sdkFixData.path], Directory.current),
    _run(dart, ['analyze', 'lib'], app),
    _run(dart, ['fix', '--dry-run'], app),
    _run(dart, ['fix', '--apply'], app),
    _run(dart, [
      'run',
      'tool/apply_full_migration.dart',
      app.path,
    ], Directory.current),
    _run(dart, ['analyze', 'lib'], app),
  ];

  for (final result in checks) {
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      stdout.writeln('Fixture kept at: ${root.path}');
      exitCode = result.exitCode;
      return;
    }
  }

  final failures = _compareOutputs(app);
  if (failures.isNotEmpty) {
    stderr.writeln('Validation failed:');
    for (final failure in failures) {
      stderr.writeln(failure);
    }
    stdout.writeln('Fixture kept at: ${root.path}');
    exitCode = 1;
    return;
  }

  stdout.writeln('Pre-merge dart fix validation passed.');
  stdout.writeln('Fixture: ${root.path}');
}

void _installSdkFixData(File file) {
  final source = file.readAsStringSync();
  if (source.contains("library: 'package:flutter/material.dart'")) {
    return;
  }
  const marker = 'transforms:\n';
  if (!source.contains(marker)) {
    throw StateError('Could not find transforms marker in ${file.path}');
  }
  file.writeAsStringSync(source.replaceFirst(marker, '$marker$_fixDataInsert'));
}

ProcessResult _run(String executable, List<String> args, Directory workingDir) {
  stdout.writeln('\$ ${[executable, ...args].join(' ')}');
  return Process.runSync(
    executable,
    args,
    workingDirectory: workingDir.path,
    runInShell: false,
  );
}

void _writeFixture(Directory root, Directory app) {
  final flutter = Directory('${root.path}/flutter/lib')
    ..createSync(recursive: true);
  final cupertinoUi = Directory('${root.path}/cupertino_ui/lib')
    ..createSync(recursive: true);
  final materialUi = Directory('${root.path}/material_ui/lib')
    ..createSync(recursive: true);
  Directory('${app.path}/lib').createSync(recursive: true);
  Directory('${app.path}/.dart_tool').createSync(recursive: true);

  File('${flutter.path}/material.dart').writeAsStringSync('''
@Deprecated('Use package:material_ui/material_ui.dart.')
library flutter.material;

export 'widgets.dart' show BuildContext, StatelessWidget, Text, Widget;

import 'widgets.dart';

class Scaffold extends Widget {
  const Scaffold({this.body});

  final Widget? body;
}
''');
  File('${flutter.path}/cupertino.dart').writeAsStringSync('''
@Deprecated('Use package:cupertino_ui/cupertino_ui.dart.')
library flutter.cupertino;

export 'widgets.dart' show BuildContext, StatelessWidget, Text, Widget;

import 'widgets.dart';

class CupertinoPageScaffold extends Widget {
  const CupertinoPageScaffold({required this.child});

  final Widget child;
}
''');
  File('${flutter.path}/widgets.dart').writeAsStringSync('''
library flutter.widgets;

class BuildContext {}

abstract class Widget {
  const Widget();
}

abstract class StatelessWidget extends Widget {
  const StatelessWidget();

  Widget build(BuildContext context);
}

class Text extends Widget {
  const Text(this.data);

  final String data;
}
''');
  File('${materialUi.path}/material_ui.dart').writeAsStringSync('''
import 'package:flutter/widgets.dart';

class Scaffold extends Widget {
  const Scaffold({this.body});

  final Widget? body;
}
''');
  File('${cupertinoUi.path}/cupertino_ui.dart').writeAsStringSync('''
import 'package:flutter/widgets.dart';

class CupertinoPageScaffold extends Widget {
  const CupertinoPageScaffold({required this.child});

  final Widget child;
}
''');

  File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: sdk_library_fix_cases
publish_to: none
environment:
  sdk: ^3.9.0
''');
  File('${app.path}/.dart_tool/package_config.json').writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "flutter",
      "rootUri": "file://${root.path}/flutter",
      "packageUri": "lib/",
      "languageVersion": "3.9"
    },
    {
      "name": "cupertino_ui",
      "rootUri": "file://${root.path}/cupertino_ui",
      "packageUri": "lib/",
      "languageVersion": "3.9"
    },
    {
      "name": "material_ui",
      "rootUri": "file://${root.path}/material_ui",
      "packageUri": "lib/",
      "languageVersion": "3.9"
    },
    {
      "name": "sdk_library_fix_cases",
      "rootUri": "../",
      "packageUri": "lib/",
      "languageVersion": "3.9"
    }
  ],
  "generated": "2026-05-18T00:00:00.000000Z",
  "generator": "manual"
}
''');

  _writeCase(app, 'simple.dart', '''
import 'package:flutter/material.dart';

class SimpleCase extends StatelessWidget {
  const SimpleCase();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('simple'));
  }
}
''');
  _writeCase(app, 'show_case.dart', '''
import 'package:flutter/material.dart'
    show BuildContext, Scaffold, StatelessWidget, Text, Widget;

class ShowCase extends StatelessWidget {
  const ShowCase();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('show'));
  }
}
''');
  _writeCase(app, 'prefix.dart', '''
import 'package:flutter/material.dart' as material;
import 'package:flutter/widgets.dart';

class PrefixCase extends StatelessWidget {
  const PrefixCase();

  @override
  Widget build(BuildContext context) {
    return const material.Scaffold(body: Text('prefix'));
  }
}
''');
  _writeCase(app, 'export_surface.dart', '''
export 'package:flutter/material.dart';
''');
  _writeCase(app, 'part_owner.dart', '''
import 'package:flutter/material.dart';

part 'part_child.dart';

class PartOwnerCase extends StatelessWidget {
  const PartOwnerCase();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text(partLabel));
  }
}
''');
  _writeCase(app, 'part_child.dart', '''
part of 'part_owner.dart';

const partLabel = 'part';
''');

  _writeCase(app, 'cupertino_simple.dart', '''
import 'package:flutter/cupertino.dart';

class CupertinoSimpleCase extends StatelessWidget {
  const CupertinoSimpleCase();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(child: Text('cupertino simple'));
  }
}
''');
  _writeCase(app, 'cupertino_show_case.dart', '''
import 'package:flutter/cupertino.dart'
    show BuildContext, CupertinoPageScaffold, StatelessWidget, Text, Widget;

class CupertinoShowCase extends StatelessWidget {
  const CupertinoShowCase();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(child: Text('cupertino show'));
  }
}
''');
  _writeCase(app, 'cupertino_prefix.dart', '''
import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/widgets.dart';

class CupertinoPrefixCase extends StatelessWidget {
  const CupertinoPrefixCase();

  @override
  Widget build(BuildContext context) {
    return const cupertino.CupertinoPageScaffold(child: Text('cupertino prefix'));
  }
}
''');
  _writeCase(app, 'cupertino_export_surface.dart', '''
export 'package:flutter/cupertino.dart';
''');
  _writeCase(app, 'cupertino_part_owner.dart', '''
import 'package:flutter/cupertino.dart';

part 'cupertino_part_child.dart';

class CupertinoPartOwnerCase extends StatelessWidget {
  const CupertinoPartOwnerCase();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(child: Text(cupertinoPartLabel));
  }
}
''');
  _writeCase(app, 'cupertino_part_child.dart', '''
part of 'cupertino_part_owner.dart';

const cupertinoPartLabel = 'cupertino part';
''');
}

void _writeCase(Directory app, String name, String contents) {
  File('${app.path}/lib/$name').writeAsStringSync(contents);
}

List<String> _compareOutputs(Directory app) {
  final expected = <String, String>{
    'pubspec.yaml': '''
name: sdk_library_fix_cases
publish_to: none
environment:
  sdk: ^3.9.0

dependencies:
  cupertino_ui: any
  material_ui: any
''',
    'simple.dart': '''
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

class SimpleCase extends StatelessWidget {
  const SimpleCase();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('simple'));
  }
}
''',
    'show_case.dart': '''
import 'package:flutter/widgets.dart'
    show BuildContext, StatelessWidget, Text, Widget;
import 'package:material_ui/material_ui.dart' show Scaffold;

class ShowCase extends StatelessWidget {
  const ShowCase();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('show'));
  }
}
''',
    'prefix.dart': '''
import 'package:material_ui/material_ui.dart' as material;
import 'package:flutter/widgets.dart';

class PrefixCase extends StatelessWidget {
  const PrefixCase();

  @override
  Widget build(BuildContext context) {
    return const material.Scaffold(body: Text('prefix'));
  }
}
''',
    'export_surface.dart': '''
export 'package:flutter/widgets.dart';
export 'package:material_ui/material_ui.dart';
''',
    'part_owner.dart': '''
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';

part 'part_child.dart';

class PartOwnerCase extends StatelessWidget {
  const PartOwnerCase();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text(partLabel));
  }
}
''',
    'cupertino_simple.dart': '''
import 'package:flutter/widgets.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

class CupertinoSimpleCase extends StatelessWidget {
  const CupertinoSimpleCase();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(child: Text('cupertino simple'));
  }
}
''',
    'cupertino_show_case.dart': '''
import 'package:flutter/widgets.dart'
    show BuildContext, StatelessWidget, Text, Widget;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageScaffold;

class CupertinoShowCase extends StatelessWidget {
  const CupertinoShowCase();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(child: Text('cupertino show'));
  }
}
''',
    'cupertino_prefix.dart': '''
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';

class CupertinoPrefixCase extends StatelessWidget {
  const CupertinoPrefixCase();

  @override
  Widget build(BuildContext context) {
    return const cupertino.CupertinoPageScaffold(child: Text('cupertino prefix'));
  }
}
''',
    'cupertino_export_surface.dart': '''
export 'package:flutter/widgets.dart';
export 'package:cupertino_ui/cupertino_ui.dart';
''',
    'cupertino_part_owner.dart': '''
import 'package:flutter/widgets.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

part 'cupertino_part_child.dart';

class CupertinoPartOwnerCase extends StatelessWidget {
  const CupertinoPartOwnerCase();

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(child: Text(cupertinoPartLabel));
  }
}
''',
  };

  final failures = <String>[];
  for (final entry in expected.entries) {
    final path = entry.key == 'pubspec.yaml'
        ? '${app.path}/${entry.key}'
        : '${app.path}/lib/${entry.key}';
    final actual = File(path).readAsStringSync();
    if (actual != entry.value) {
      failures.add('- ${entry.key} did not match expected migration output.');
    }
  }
  return failures;
}
