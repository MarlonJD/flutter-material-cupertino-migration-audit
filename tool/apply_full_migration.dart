import 'dart:io';

const _frameworkUri = 'package:flutter/widgets.dart';

const _designLibraries = <_DesignLibrary>[
  _DesignLibrary(
    dependency: 'material_ui',
    legacyUri: 'package:flutter/material.dart',
    packageUri: 'package:material_ui/material_ui.dart',
  ),
  _DesignLibrary(
    dependency: 'cupertino_ui',
    legacyUri: 'package:flutter/cupertino.dart',
    packageUri: 'package:cupertino_ui/cupertino_ui.dart',
  ),
];

const _frameworkSymbols = {
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
};

final _directivePattern = RegExp(
  r"""^([ \t]*)(import|export)\s+(['"])([^'"]+)\3([^;]*);""",
  multiLine: true,
);
final _partPattern = RegExp(
  r"""^\s*part\s+['"]([^'"]+)['"]\s*;""",
  multiLine: true,
);
final _partOfPattern = RegExp(r'^\s*part\s+of\s+', multiLine: true);
final _asPattern = RegExp(r'\bas\s+([A-Za-z_]\w*)');
final _showPattern = RegExp(r'\bshow\s+([^;]+?)(?:\s+hide\b|$)');
final _hidePattern = RegExp(r'\bhide\s+([^;]+?)(?:\s+show\b|$)');
final _topLevelSectionPattern = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_]*:',
  multiLine: true,
);

void main(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final roots = args.map(_pathToEntity).toList();
  for (final root in roots) {
    if (!root.existsSync()) {
      stderr.writeln('Path does not exist: ${root.path}');
      exitCode = 64;
      return;
    }
  }

  final files = <File>[];
  for (final root in roots) {
    files.addAll(_collectDartFiles(root));
  }

  final partOwners = _buildPartOwnerIndex(files);
  var changedFiles = 0;
  final dependencies = <String>{};

  for (final file in files) {
    final result = _rewriteFile(
      file,
      partOwners[file.absolute.path] ?? const [],
    );
    dependencies.addAll(result.dependencies);
    if (!result.changed) {
      continue;
    }
    file.writeAsStringSync(result.source);
    changedFiles += 1;
  }

  var changedPubspecs = 0;
  for (final root in roots.whereType<Directory>()) {
    if (_updatePubspec(root, dependencies)) {
      changedPubspecs += 1;
    }
  }

  stdout.writeln(
    'Full migration supplement updated $changedFiles Dart file(s) '
    'and $changedPubspecs pubspec file(s).',
  );
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/apply_full_migration.dart <app-or-dart-file> [...]',
  );
}

FileSystemEntity _pathToEntity(String path) {
  final file = File(path);
  if (file.existsSync()) {
    return file;
  }
  return Directory(path);
}

List<File> _collectDartFiles(FileSystemEntity entity) {
  if (entity is File) {
    return entity.path.endsWith('.dart') ? [entity] : const [];
  }
  if (entity is! Directory) {
    return const [];
  }

  final files = <File>[];
  for (final child in entity.listSync(recursive: false, followLinks: false)) {
    final name = child.path.split(Platform.pathSeparator).last;
    if (child is Directory) {
      if (name == '.dart_tool' || name == '.git' || name == 'build') {
        continue;
      }
      files.addAll(_collectDartFiles(child));
    } else if (child is File && child.path.endsWith('.dart')) {
      files.add(child);
    }
  }
  return files;
}

Map<String, List<File>> _buildPartOwnerIndex(List<File> files) {
  final index = <String, List<File>>{};
  for (final file in files) {
    final source = file.readAsStringSync();
    if (_partOfPattern.hasMatch(source)) {
      continue;
    }
    for (final match in _partPattern.allMatches(source)) {
      final uri = match.group(1)!;
      if (uri.startsWith('package:') || uri.startsWith('dart:')) {
        continue;
      }
      final part = File('${file.parent.path}/$uri');
      if (part.existsSync()) {
        index.putIfAbsent(file.absolute.path, () => []).add(part);
      }
    }
  }
  return index;
}

_RewriteResult _rewriteFile(File file, List<File> parts) {
  final source = file.readAsStringSync();
  if (_partOfPattern.hasMatch(source)) {
    return _RewriteResult(source: source);
  }

  final partSource = parts.map((part) => part.readAsStringSync()).join('\n');
  final state = _RewriteState(
    hasWidgetsImport: _hasDirective(source, 'import', _frameworkUri),
    hasWidgetsExport: _hasDirective(source, 'export', _frameworkUri),
    frameworkUsage: _scanFrameworkUsage(
      '${_maskCommentsAndStrings(source)}\n${_maskCommentsAndStrings(partSource)}',
    ),
  );
  final dependencies = <String>{};
  final buffer = StringBuffer();
  var lastEnd = 0;
  var changed = false;

  for (final match in _directivePattern.allMatches(source)) {
    final kind = match.group(2)!;
    final uri = match.group(4)!;
    final rest = match.group(5) ?? '';
    final library = _libraryFor(uri);
    if (library == null) {
      continue;
    }

    dependencies.add(library.dependency);
    final replacement = _rewriteDirective(
      kind: kind,
      rest: rest,
      library: library,
      state: state,
    );
    final original = match.group(0)!;

    buffer
      ..write(source.substring(lastEnd, match.start))
      ..write(replacement);
    lastEnd = match.end;
    changed = changed || replacement != original;
  }

  if (lastEnd == 0) {
    return _RewriteResult(source: source);
  }

  buffer.write(source.substring(lastEnd));
  return _RewriteResult(
    changed: changed,
    dependencies: dependencies,
    source: buffer.toString(),
  );
}

bool _hasDirective(String source, String kind, String uri) {
  return _directivePattern
      .allMatches(source)
      .any((match) => match.group(2) == kind && match.group(4) == uri);
}

_DesignLibrary? _libraryFor(String uri) {
  for (final library in _designLibraries) {
    if (uri == library.legacyUri || uri == library.packageUri) {
      return library;
    }
  }
  return null;
}

String _rewriteDirective({
  required String kind,
  required String rest,
  required _DesignLibrary library,
  required _RewriteState state,
}) {
  final prefix = _asPattern.firstMatch(rest)?.group(1);
  if (prefix != null) {
    return '$kind \'${library.packageUri}\'$rest;';
  }

  final showNames = _parseCombinatorNames(_showPattern, rest);
  if (showNames.isNotEmpty) {
    return _rewriteShowDirective(kind, library, showNames, state);
  }

  final hideNames = _parseCombinatorNames(_hidePattern, rest);
  if (hideNames.isNotEmpty) {
    return _rewriteHideDirective(kind, library, hideNames, state);
  }

  final directives = <String>[];
  final needsFrameworkDirective =
      kind == 'export' || state.frameworkUsage.isNotEmpty;
  if (needsFrameworkDirective) {
    final widgets = _takeWidgetsDirective(kind, state);
    if (widgets != null) {
      directives.add(widgets);
    }
  }
  directives.add(_formatDirective(kind, library.packageUri));
  return directives.join('\n');
}

String _rewriteShowDirective(
  String kind,
  _DesignLibrary library,
  List<String> names,
  _RewriteState state,
) {
  final frameworkNames = <String>[];
  final designNames = <String>[];
  for (final name in names) {
    if (_frameworkSymbols.contains(name)) {
      frameworkNames.add(name);
    } else {
      designNames.add(name);
    }
  }

  final directives = <String>[];
  if (frameworkNames.isNotEmpty) {
    final widgets = _takeWidgetsDirective(
      kind,
      state,
      showNames: frameworkNames,
    );
    if (widgets != null) {
      directives.add(widgets);
    }
  }
  if (designNames.isNotEmpty) {
    directives.add(
      _formatDirective(kind, library.packageUri, showNames: designNames),
    );
  }
  return directives.join('\n');
}

String _rewriteHideDirective(
  String kind,
  _DesignLibrary library,
  List<String> names,
  _RewriteState state,
) {
  final frameworkHidden = <String>[];
  final designHidden = <String>[];
  for (final name in names) {
    if (_frameworkSymbols.contains(name)) {
      frameworkHidden.add(name);
    } else {
      designHidden.add(name);
    }
  }

  final directives = <String>[];
  if (kind == 'export' || state.frameworkUsage.isNotEmpty) {
    final widgets = _takeWidgetsDirective(
      kind,
      state,
      hideNames: frameworkHidden,
    );
    if (widgets != null) {
      directives.add(widgets);
    }
  }
  directives.add(
    _formatDirective(kind, library.packageUri, hideNames: designHidden),
  );
  return directives.join('\n');
}

String? _takeWidgetsDirective(
  String kind,
  _RewriteState state, {
  List<String> showNames = const [],
  List<String> hideNames = const [],
}) {
  if (kind == 'import') {
    if (state.hasWidgetsImport || state.addedWidgetsImport) {
      return null;
    }
    state.addedWidgetsImport = true;
    return _formatDirective(
      kind,
      _frameworkUri,
      showNames: showNames,
      hideNames: hideNames,
    );
  }

  if (state.hasWidgetsExport || state.addedWidgetsExport) {
    return null;
  }
  state.addedWidgetsExport = true;
  return _formatDirective(
    kind,
    _frameworkUri,
    showNames: showNames,
    hideNames: hideNames,
  );
}

String _formatDirective(
  String kind,
  String uri, {
  List<String> showNames = const [],
  List<String> hideNames = const [],
}) {
  final combinators = <String>[];
  if (showNames.isNotEmpty) {
    combinators.add('show ${showNames.join(', ')}');
  }
  if (hideNames.isNotEmpty) {
    combinators.add('hide ${hideNames.join(', ')}');
  }
  if (combinators.isEmpty) {
    return '$kind \'$uri\';';
  }
  if (showNames.length + hideNames.length == 1) {
    return '$kind \'$uri\' ${combinators.join(' ')};';
  }
  return '$kind \'$uri\'\n    ${combinators.join(' ')};';
}

List<String> _parseCombinatorNames(RegExp pattern, String rest) {
  final match = pattern.firstMatch(rest);
  if (match == null) {
    return const [];
  }
  return match
      .group(1)!
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toList();
}

Set<String> _scanFrameworkUsage(String source) {
  final usage = <String>{};
  for (final symbol in _frameworkSymbols) {
    if (RegExp('\\b${RegExp.escape(symbol)}\\b').hasMatch(source)) {
      usage.add(symbol);
    }
  }
  return usage;
}

String _maskCommentsAndStrings(String source) {
  final buffer = StringBuffer();
  var index = 0;
  while (index < source.length) {
    if (source.startsWith('//', index)) {
      final end = source.indexOf('\n', index);
      if (end == -1) {
        buffer.write(' ' * (source.length - index));
        break;
      }
      buffer
        ..write(' ' * (end - index))
        ..write('\n');
      index = end + 1;
      continue;
    }
    if (source.startsWith('/*', index)) {
      final end = source.indexOf('*/', index + 2);
      final commentEnd = end == -1 ? source.length : end + 2;
      buffer.write(
        source.substring(index, commentEnd).replaceAll(RegExp(r'[^\n]'), ' '),
      );
      index = commentEnd;
      continue;
    }
    final char = source[index];
    if (char == '\'' || char == '"') {
      final quote = char;
      final triple = source.startsWith(quote * 3, index);
      final delimiter = triple ? quote * 3 : quote;
      final start = index;
      index += delimiter.length;
      while (index < source.length) {
        if (!triple && source[index] == r'\') {
          index += 2;
          continue;
        }
        if (source.startsWith(delimiter, index)) {
          index += delimiter.length;
          break;
        }
        index += 1;
      }
      buffer.write(
        source.substring(start, index).replaceAll(RegExp(r'[^\n]'), ' '),
      );
      continue;
    }
    buffer.write(char);
    index += 1;
  }
  return buffer.toString();
}

bool _updatePubspec(Directory root, Set<String> dependencies) {
  if (dependencies.isEmpty) {
    return false;
  }
  final file = File('${root.path}/pubspec.yaml');
  if (!file.existsSync()) {
    return false;
  }

  var source = file.readAsStringSync();
  final missing =
      dependencies
          .where(
            (dependency) => !RegExp(
              '^  ${RegExp.escape(dependency)}:',
              multiLine: true,
            ).hasMatch(source),
          )
          .toList()
        ..sort();
  if (missing.isEmpty) {
    return false;
  }

  final lines = missing.map((dependency) => '  $dependency: any').join('\n');
  final dependenciesMatch = RegExp(
    r'^dependencies:\s*$',
    multiLine: true,
  ).firstMatch(source);
  if (dependenciesMatch == null) {
    source = source.trimRight();
    source = '$source\n\ndependencies:\n$lines\n';
    file.writeAsStringSync(source);
    return true;
  }

  final nextSection = _topLevelSectionPattern
      .allMatches(source, dependenciesMatch.end)
      .firstOrNull;
  final insertOffset = nextSection?.start ?? source.length;
  final prefix = source.substring(0, insertOffset).trimRight();
  final suffix = source.substring(insertOffset);
  source = '$prefix\n$lines\n$suffix';
  file.writeAsStringSync(source);
  return true;
}

class _DesignLibrary {
  const _DesignLibrary({
    required this.dependency,
    required this.legacyUri,
    required this.packageUri,
  });

  final String dependency;
  final String legacyUri;
  final String packageUri;
}

class _RewriteState {
  _RewriteState({
    required this.hasWidgetsImport,
    required this.hasWidgetsExport,
    required this.frameworkUsage,
  });

  final bool hasWidgetsImport;
  final bool hasWidgetsExport;
  final Set<String> frameworkUsage;
  bool addedWidgetsImport = false;
  bool addedWidgetsExport = false;
}

class _RewriteResult {
  const _RewriteResult({
    required this.source,
    this.changed = false,
    this.dependencies = const {},
  });

  final bool changed;
  final Set<String> dependencies;
  final String source;
}
