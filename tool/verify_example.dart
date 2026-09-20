// Checks that the example demonstrates what it claims to.
//
// The example is the only place the plugin runs end to end: the unit tests
// drive rules through the analyzer's testing harness, which never loads the
// plugin the way the analysis server does. So a mistake in registration, in
// the plugin name, or in the `plugins:` block would leave every test passing
// while the plugin did nothing for a real user. That failure mode is not
// hypothetical: this example spent its whole life resolving the plugin from
// pub.dev, where the package was not published, so the server quietly declined
// to start it and reported nothing at all.
//
// Rather than hard-code a count that drifts, this reads the example's own
// comments as the specification. A line tagged `// reported:` must produce a
// diagnostic on the statement it introduces, and every other line must produce
// none. Adding a case to the example therefore extends this check for free.
//
// Run from the package root:
//
//     dart run tool/verify_example.dart
//
// Exits non-zero, and explains which line disagreed, when the example and the
// plugin have drifted apart.

import 'dart:convert';
import 'dart:io';

void main() async {
  final example = File('example/lib/example.dart');
  if (!example.existsSync()) {
    _fail('run this from the package root: ${example.path} not found');
  }

  final expected = _expectedLines(example.readAsLinesSync());
  if (expected.isEmpty) {
    _fail('found no `// reported:` markers in ${example.path}');
  }

  final actual = await _reportedLines();

  final missing = expected.difference(actual);
  final unexpected = actual.difference(expected);

  if (missing.isEmpty && unexpected.isEmpty) {
    stdout.writeln(
      'OK: ${expected.length} diagnostics, each on the line its comment '
      'promises, and none anywhere else.',
    );
    return;
  }

  if (missing.isNotEmpty) {
    stderr.writeln(
      'Lines marked `// reported:` that produced no diagnostic: '
      '${_sorted(missing)}',
    );
    stderr.writeln(
      'Either the rule stopped firing, or the plugin is not being loaded at '
      'all. Check `dart analyze` in example/ for a plugin setup error.',
    );
  }
  if (unexpected.isNotEmpty) {
    stderr.writeln(
      'Diagnostics on lines not marked `// reported:`: ${_sorted(unexpected)}',
    );
    stderr.writeln(
      'Either the rule became too eager, or the example gained a case without '
      'a comment describing it.',
    );
  }
  exit(1);
}

/// The lines the example says should be reported.
///
/// A `// reported:` comment describes the statement below it, and such a
/// comment may span several lines, so the expectation is the first line after
/// the comment block that is neither blank nor itself a comment.
Set<int> _expectedLines(List<String> lines) {
  final expected = <int>{};

  for (var i = 0; i < lines.length; i++) {
    if (!_isMarker(lines[i])) {
      continue;
    }
    for (var j = i + 1; j < lines.length; j++) {
      final line = lines[j].trim();
      if (line.isEmpty || line.startsWith('//')) {
        continue;
      }
      expected.add(j + 1); // Analyzer line numbers are 1-based.
      break;
    }
  }
  return expected;
}

bool _isMarker(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith('//') && trimmed.contains('reported:');
}

/// The lines the analyzer actually reports `sensitive_exposure` on.
///
/// Uses the machine-readable output rather than parsing the human format,
/// which is not a stable interface.
Future<Set<int>> _reportedLines() async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['analyze', '--format=json', '.'],
    workingDirectory: 'example',
  );

  // `dart analyze` exits non-zero simply for having found diagnostics, which is
  // the expected case here, so the exit code says nothing on its own. A plugin
  // that failed to load reports on stderr while still exiting non-zero, so that
  // is surfaced rather than swallowed.
  final stderrText = (result.stderr as String).trim();
  if (stderrText.isNotEmpty) {
    stderr.writeln('dart analyze wrote to stderr:\n$stderrText');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(result.stdout as String);
  } on FormatException catch (error) {
    _fail('could not parse `dart analyze --format=json` output: $error');
  }

  if (decoded is! Map<String, Object?>) {
    _fail('unexpected analyze output shape: ${decoded.runtimeType}');
  }
  final diagnostics = decoded['diagnostics'];
  if (diagnostics is! List) {
    _fail('analyze output carried no diagnostics list');
  }

  final lines = <int>{};
  for (final diagnostic in diagnostics) {
    if (diagnostic is! Map<String, Object?>) {
      continue;
    }
    if (diagnostic['code'] != 'sensitive_exposure') {
      continue;
    }
    final location = diagnostic['location'];
    if (location is! Map<String, Object?>) {
      continue;
    }
    final range = location['range'];
    if (range is! Map<String, Object?>) {
      continue;
    }
    final start = range['start'];
    if (start is! Map<String, Object?>) {
      continue;
    }
    final line = start['line'];
    if (line is int) {
      lines.add(line);
    }
  }
  return lines;
}

List<int> _sorted(Set<int> lines) => lines.toList()..sort();

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
