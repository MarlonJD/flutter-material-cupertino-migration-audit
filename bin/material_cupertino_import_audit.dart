import 'dart:collection';
import 'dart:io';

const _designLibraries = <DesignLibrary>[
  DesignLibrary(
    name: 'material',
    flutterUri: 'package:flutter/material.dart',
    packageUri: 'package:material_ui/material_ui.dart',
    dependency: 'material_ui',
  ),
  DesignLibrary(
    name: 'cupertino',
    flutterUri: 'package:flutter/cupertino.dart',
    packageUri: 'package:cupertino_ui/cupertino_ui.dart',
    dependency: 'cupertino_ui',
  ),
];

const _frameworkSymbolLibraries = <String, Set<String>>{
  'package:flutter/widgets.dart': {
    'Action',
    'Alignment',
    'AnimatedBuilder',
    'AnimatedWidget',
    'AspectRatio',
    'AutomaticKeepAliveClientMixin',
    'BuildContext',
    'Builder',
    'Center',
    'Column',
    'ConnectionState',
    'Container',
    'DefaultTextStyle',
    'Directionality',
    'EdgeInsets',
    'Expanded',
    'Flexible',
    'FocusNode',
    'Form',
    'FormState',
    'GestureDetector',
    'GlobalKey',
    'GridView',
    'Icon',
    'IconData',
    'Image',
    'IndexedWidgetBuilder',
    'InheritedWidget',
    'Key',
    'LayoutBuilder',
    'ListView',
    'LocalKey',
    'MediaQuery',
    'Navigator',
    'Padding',
    'Page',
    'PageRoute',
    'Positioned',
    'Route',
    'RouteSettings',
    'Row',
    'SafeArea',
    'ScrollController',
    'ScrollPhysics',
    'SingleChildScrollView',
    'SizedBox',
    'SliverList',
    'Spacer',
    'Stack',
    'State',
    'StatefulBuilder',
    'StatefulWidget',
    'StatelessWidget',
    'StreamBuilder',
    'Text',
    'TextEditingController',
    'ValueKey',
    'Widget',
    'WidgetBuilder',
    'WidgetsApp',
  },
  'package:flutter/foundation.dart': {
    'ChangeNotifier',
    'Diagnosticable',
    'Key',
    'Listenable',
    'ValueChanged',
    'ValueGetter',
    'ValueListenable',
    'ValueNotifier',
    'VoidCallback',
    'immutable',
    'protected',
    'required',
    'visibleForTesting',
  },
  'package:flutter/painting.dart': {
    'Border',
    'BorderRadius',
    'BoxDecoration',
    'BoxFit',
    'BoxShadow',
    'Color',
    'Colors',
    'Decoration',
    'Gradient',
    'ImageProvider',
    'LinearGradient',
    'NetworkImage',
    'Radius',
    'RoundedRectangleBorder',
    'TextAlign',
    'TextDirection',
    'TextStyle',
  },
  'package:flutter/services.dart': {
    'Clipboard',
    'HapticFeedback',
    'LogicalKeyboardKey',
    'PlatformException',
    'SystemChrome',
    'TextInputAction',
    'TextInputFormatter',
  },
  'package:flutter/animation.dart': {
    'Animation',
    'AnimationController',
    'AnimationStatus',
    'CurvedAnimation',
    'Curves',
    'Tween',
  },
  'package:flutter/gestures.dart': {
    'DragStartDetails',
    'DragUpdateDetails',
    'GestureRecognizer',
    'PointerDownEvent',
    'TapGestureRecognizer',
  },
  'package:flutter/rendering.dart': {
    'BoxConstraints',
    'CustomPainter',
    'RenderBox',
    'RenderObject',
    'Size',
  },
};

const _materialSymbols = {
  'AppBar',
  'BottomNavigationBar',
  'ButtonStyle',
  'Card',
  'Checkbox',
  'Chip',
  'CircularProgressIndicator',
  'Colors',
  'Drawer',
  'ElevatedButton',
  'FloatingActionButton',
  'IconButton',
  'InkWell',
  'ListTile',
  'Material',
  'MaterialApp',
  'MaterialPageRoute',
  'Scaffold',
  'SnackBar',
  'TextButton',
  'TextField',
  'Theme',
  'ThemeData',
};

const _cupertinoSymbols = {
  'CupertinoActionSheet',
  'CupertinoActivityIndicator',
  'CupertinoAlertDialog',
  'CupertinoApp',
  'CupertinoButton',
  'CupertinoColors',
  'CupertinoIcons',
  'CupertinoNavigationBar',
  'CupertinoPageRoute',
  'CupertinoPageScaffold',
  'CupertinoPicker',
  'CupertinoSlider',
  'CupertinoSwitch',
  'CupertinoTabBar',
  'CupertinoTextField',
};

final _importExportPattern = RegExp(
  r"""^\s*(import|export)\s+['"]([^'"]+)['"]([^;]*);""",
  multiLine: true,
);
final _partPattern = RegExp(
  r"""^\s*part\s+['"]([^'"]+)['"]\s*;""",
  multiLine: true,
);
final _asPattern = RegExp(r'\bas\s+([A-Za-z_]\w*)');
final _showPattern = RegExp(r'\bshow\s+([^;]+?)(?:\s+hide\b|$)');
final _hidePattern = RegExp(r'\bhide\s+([^;]+?)(?:\s+show\b|$)');

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final roots = args.map((arg) => Directory(arg)).toList();
  final dartFiles = <File>[];
  for (final root in roots) {
    if (!root.existsSync()) {
      stderr.writeln('Path does not exist: ${root.path}');
      exitCode = 64;
      return;
    }
    dartFiles.addAll(_collectDartFiles(root));
  }

  final analyses = <String, FileAnalysis>{};
  for (final file in dartFiles) {
    final analysis = analyzeFile(file);
    if (analysis.hasDesignImportOrExport || analysis.partUris.isNotEmpty) {
      analyses[file.path] = analysis;
    }
  }

  final partOwners = _buildPartOwnerIndex(analyses);
  for (final entry in partOwners.entries) {
    final owner = analyses[entry.value];
    if (owner == null) {
      continue;
    }
    final partFile = File(entry.key);
    if (!partFile.existsSync()) {
      owner.notes.add(
        'Missing part file referenced by library: ${partFile.path}',
      );
      continue;
    }
    final partUsage = scanFrameworkUsage(partFile.readAsStringSync());
    if (partUsage.isNotEmpty && owner.hasUnprefixedDesignImport) {
      owner.partFrameworkUsage[partFile.path] = partUsage;
    }
  }

  final interesting =
      analyses.values
          .where(
            (analysis) =>
                analysis.hasDesignImportOrExport ||
                analysis.frameworkImportsNeeded.isNotEmpty ||
                analysis.notes.isNotEmpty ||
                analysis.partFrameworkUsage.isNotEmpty,
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  _printReport(interesting, dartFiles.length);
}

FileAnalysis analyzeFile(File file) {
  final source = file.readAsStringSync();
  final maskedSource = maskCommentsAndStrings(source);
  final directives = parseDirectives(source);
  final designDirectives = directives
      .where(
        (directive) => _designLibraries.any(
          (library) => library.flutterUri == directive.uri,
        ),
      )
      .toList();

  final existingFlutterImports = directives
      .where((directive) => directive.kind == 'import')
      .map((directive) => directive.uri)
      .where((uri) => uri.startsWith('package:flutter/'))
      .toSet();

  final frameworkUsage = scanFrameworkUsage(maskedSource);
  final designUsage = scanDesignUsage(maskedSource);
  final analysis = FileAnalysis(
    path: file.path,
    directives: designDirectives,
    existingFlutterImports: existingFlutterImports,
    frameworkUsage: frameworkUsage,
    designUsage: designUsage,
    partUris: parseParts(source),
  );

  for (final directive in designDirectives) {
    if (directive.kind == 'export') {
      analysis.notes.add(
        'Re-export of ${directive.uri} is a downstream API surface. Automated migration should not silently change it.',
      );
    }
    if (directive.hideNames.isNotEmpty) {
      analysis.notes.add(
        'Uses hide combinator on ${directive.uri}: ${directive.hideNames.join(', ')}. This likely needs manual review.',
      );
    }
    if (directive.showNames.isNotEmpty) {
      final frameworkNames = <String>[];
      for (final names in _frameworkSymbolLibraries.values) {
        frameworkNames.addAll(directive.showNames.where(names.contains));
      }
      if (frameworkNames.isNotEmpty) {
        analysis.notes.add(
          'show combinator mixes design and framework symbols: ${frameworkNames.toSet().join(', ')}.',
        );
      }
    }
    if (directive.prefix != null) {
      analysis.notes.add(
        'Prefixed import "${directive.prefix}" can be URI-rewritten, but unprefixed framework usage must come from another import.',
      );
    }
  }

  return analysis;
}

List<File> _collectDartFiles(Directory root) {
  return root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
}

List<Directive> parseDirectives(String source) {
  return _importExportPattern.allMatches(source).map((match) {
    final trailing = match.group(3) ?? '';
    return Directive(
      kind: match.group(1)!,
      uri: match.group(2)!,
      prefix: _asPattern.firstMatch(trailing)?.group(1),
      showNames: _parseCombinatorNames(
        _showPattern.firstMatch(trailing)?.group(1),
      ),
      hideNames: _parseCombinatorNames(
        _hidePattern.firstMatch(trailing)?.group(1),
      ),
    );
  }).toList();
}

List<String> parseParts(String source) {
  return _partPattern
      .allMatches(source)
      .map((match) => match.group(1)!)
      .toList();
}

Set<String> _parseCombinatorNames(String? text) {
  if (text == null) {
    return const {};
  }
  return text
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map((part) => part.split(RegExp(r'\s+')).first)
      .toSet();
}

Map<String, String> _buildPartOwnerIndex(Map<String, FileAnalysis> analyses) {
  final owners = <String, String>{};
  for (final analysis in analyses.values) {
    if (analysis.partUris.isEmpty) {
      continue;
    }
    final ownerFile = File(analysis.path);
    final ownerDir = ownerFile.parent;
    for (final partUri in analysis.partUris) {
      final partPath = File('${ownerDir.path}/$partUri').absolute.path;
      owners[partPath] = analysis.path;
    }
  }
  return owners;
}

Map<String, Set<String>> scanFrameworkUsage(String source) {
  final usage = SplayTreeMap<String, Set<String>>();
  for (final entry in _frameworkSymbolLibraries.entries) {
    final symbols = <String>{};
    for (final symbol in entry.value) {
      if (_containsIdentifier(source, symbol)) {
        symbols.add(symbol);
      }
    }
    if (symbols.isNotEmpty) {
      usage[entry.key] = symbols;
    }
  }
  return usage;
}

Map<String, Set<String>> scanDesignUsage(String source) {
  final usage = <String, Set<String>>{};
  final material = _materialSymbols
      .where((symbol) => _containsIdentifier(source, symbol))
      .toSet();
  final cupertino = _cupertinoSymbols
      .where((symbol) => _containsIdentifier(source, symbol))
      .toSet();
  if (material.isNotEmpty) {
    usage['material'] = material;
  }
  if (cupertino.isNotEmpty) {
    usage['cupertino'] = cupertino;
  }
  return usage;
}

bool _containsIdentifier(String source, String identifier) {
  return RegExp(
    '(?<![A-Za-z0-9_\\.])${RegExp.escape(identifier)}(?![A-Za-z0-9_])',
  ).hasMatch(source);
}

String maskCommentsAndStrings(String source) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';

    if (char == '/' && next == '/') {
      while (index < source.length && source[index] != '\n') {
        buffer.write(' ');
        index++;
      }
      continue;
    }

    if (char == '/' && next == '*') {
      buffer.write('  ');
      index += 2;
      while (index + 1 < source.length &&
          !(source[index] == '*' && source[index + 1] == '/')) {
        buffer.write(source[index] == '\n' ? '\n' : ' ');
        index++;
      }
      if (index + 1 < source.length) {
        buffer.write('  ');
        index += 2;
      }
      continue;
    }

    if (char == "'" || char == '"') {
      final quote = char;
      final triple =
          index + 2 < source.length &&
          source.substring(index, index + 3) == _repeat(quote, 3);
      final end = triple ? _repeat(quote, 3) : quote;
      buffer.write(triple ? '   ' : ' ');
      index += triple ? 3 : 1;
      while (index < source.length) {
        if (!triple && source[index] == '\\') {
          buffer.write('  ');
          index += 2;
          continue;
        }
        if (source.startsWith(end, index)) {
          buffer.write(' ' * end.length);
          index += end.length;
          break;
        }
        buffer.write(source[index] == '\n' ? '\n' : ' ');
        index++;
      }
      continue;
    }

    buffer.write(char);
    index++;
  }
  return buffer.toString();
}

void _printReport(List<FileAnalysis> analyses, int scannedFiles) {
  final dependencies = <String>{};
  var materialFiles = 0;
  var cupertinoFiles = 0;
  var manualReviewFiles = 0;
  var frameworkImportFiles = 0;

  for (final analysis in analyses) {
    for (final library in analysis.designLibraries) {
      dependencies.add(library.dependency);
      if (library.name == 'material') {
        materialFiles++;
      } else if (library.name == 'cupertino') {
        cupertinoFiles++;
      }
    }
    if (analysis.notes.isNotEmpty) {
      manualReviewFiles++;
    }
    if (analysis.frameworkImportsNeeded.isNotEmpty ||
        analysis.partFrameworkUsage.isNotEmpty) {
      frameworkImportFiles++;
    }
  }

  print('Material/Cupertino import audit');
  print('Scanned Dart files: $scannedFiles');
  print('Files with Material imports/exports: $materialFiles');
  print('Files with Cupertino imports/exports: $cupertinoFiles');
  print(
    'Files likely needing explicit framework imports: $frameworkImportFiles',
  );
  print('Files needing manual review: $manualReviewFiles');
  if (dependencies.isNotEmpty) {
    print('Potential pubspec dependencies: ${dependencies.join(', ')}');
  }
  print('');

  for (final analysis in analyses) {
    print(analysis.path);
    for (final directive in analysis.directives) {
      final library = _designLibraries.firstWhere(
        (library) => library.flutterUri == directive.uri,
      );
      final prefix = directive.prefix == null ? '' : ' as ${directive.prefix}';
      final show = directive.showNames.isEmpty
          ? ''
          : ' show ${directive.showNames.join(', ')}';
      final hide = directive.hideNames.isEmpty
          ? ''
          : ' hide ${directive.hideNames.join(', ')}';
      print('  ${directive.kind}: ${directive.uri}$prefix$show$hide');
      print(
        '    candidate: ${directive.kind} "${library.packageUri}"$prefix$show$hide;',
      );
    }

    if (analysis.frameworkImportsNeeded.isNotEmpty) {
      print('  likely explicit Flutter imports:');
      for (final entry in analysis.frameworkImportsNeeded.entries) {
        print(
          '    ${entry.key} (${entry.value.take(8).join(', ')}${entry.value.length > 8 ? ', ...' : ''})',
        );
      }
    }

    if (analysis.designUsage.isNotEmpty) {
      print('  design symbols seen:');
      for (final entry in analysis.designUsage.entries) {
        print(
          '    ${entry.key}: ${entry.value.take(8).join(', ')}${entry.value.length > 8 ? ', ...' : ''}',
        );
      }
    }

    if (analysis.partFrameworkUsage.isNotEmpty) {
      print('  part files using framework symbols through this library:');
      for (final entry in analysis.partFrameworkUsage.entries) {
        final symbols =
            entry.value.values.expand((symbols) => symbols).toSet().toList()
              ..sort();
        print(
          '    ${entry.key}: ${symbols.take(8).join(', ')}${symbols.length > 8 ? ', ...' : ''}',
        );
      }
    }

    for (final note in analysis.notes) {
      print('  manual-review: $note');
    }
    print('');
  }
}

void _printUsage() {
  print(
    'Usage: dart run bin/material_cupertino_import_audit.dart <path> [<path> ...]',
  );
  print('');
  print(
    'Audits Dart files for Flutter Material/Cupertino decoupling migration risks.',
  );
}

String _repeat(String value, int count) => List.filled(count, value).join();

class DesignLibrary {
  const DesignLibrary({
    required this.name,
    required this.flutterUri,
    required this.packageUri,
    required this.dependency,
  });

  final String name;
  final String flutterUri;
  final String packageUri;
  final String dependency;
}

class Directive {
  const Directive({
    required this.kind,
    required this.uri,
    required this.prefix,
    required this.showNames,
    required this.hideNames,
  });

  final String kind;
  final String uri;
  final String? prefix;
  final Set<String> showNames;
  final Set<String> hideNames;
}

class FileAnalysis {
  FileAnalysis({
    required this.path,
    required this.directives,
    required this.existingFlutterImports,
    required this.frameworkUsage,
    required this.designUsage,
    required this.partUris,
  });

  final String path;
  final List<Directive> directives;
  final Set<String> existingFlutterImports;
  final Map<String, Set<String>> frameworkUsage;
  final Map<String, Set<String>> designUsage;
  final List<String> partUris;
  final Map<String, Map<String, Set<String>>> partFrameworkUsage = {};
  final List<String> notes = [];

  bool get hasDesignImportOrExport => directives.isNotEmpty;

  bool get hasUnprefixedDesignImport => directives.any(
    (directive) => directive.kind == 'import' && directive.prefix == null,
  );

  Iterable<DesignLibrary> get designLibraries sync* {
    for (final directive in directives) {
      yield _designLibraries.firstWhere(
        (library) => library.flutterUri == directive.uri,
      );
    }
  }

  Map<String, Set<String>> get frameworkImportsNeeded {
    final needed = SplayTreeMap<String, Set<String>>();
    if (!hasUnprefixedDesignImport) {
      return needed;
    }
    for (final entry in frameworkUsage.entries) {
      if (!existingFlutterImports.contains(entry.key)) {
        needed[entry.key] = entry.value;
      }
    }
    return needed;
  }
}
