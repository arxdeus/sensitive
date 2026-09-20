import 'dart:io';
import 'dart:isolate';

/// The real `sensitive_exposure_lint` annotation source, for writing into test
/// fixtures.
///
/// Read from `lib/src/annotations.dart` rather than copied, because the rule
/// matches the annotation by class name, by field name and by package. A
/// hand-written copy could drift from the real declaration, and the tests
/// would keep passing while the rule silently stopped firing for real users.
///
/// Resolved once per test isolate, and synchronously, so that it can be used
/// from `setUp`.
final String annotationsSource = _readAnnotations();

String _readAnnotations() {
  final uri = Isolate.resolvePackageUriSync(
    Uri.parse('package:sensitive_exposure_lint/src/annotations.dart'),
  );
  if (uri == null) {
    throw StateError(
      'Cannot resolve package:sensitive_exposure_lint/src/annotations.dart. '
      'Run `dart pub get` before running the tests.',
    );
  }
  return File.fromUri(uri).readAsStringSync();
}
