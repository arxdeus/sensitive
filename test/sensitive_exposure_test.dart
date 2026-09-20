import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:sensitive/src/rules/sensitive_exposure.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'src/annotations_source.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SensitiveExposureTest);
  });
}

/// The annotated declarations shared by the fixtures.
const _preamble = '''
import 'package:sensitive/sensitive.dart';

class AuthError implements Exception {
  AuthError(this.message);
  final String message;
}

class Logger {
  void info(String message) {}
  void severe(String message) {}
}

final logger = Logger();

@Sensitive()
String globalToken = 'x';

@Sensitive('OAuth refresh token')
String documentedToken = 'x';

String publicName = 'x';

class Session {
  @Sensitive()
  final String token = 'x';

  final String user = 'x';
}
''';

@reflectiveTest
class SensitiveExposureTest extends AnalysisRuleTest {
  @override
  void setUp() {
    newPackage(
      'sensitive',
    ).addFile('lib/sensitive.dart', annotationsSource);
    rule = SensitiveExposureRule();
    super.setUp();
  }

  /// Asserts that [body], appended to the shared preamble, is clean.
  Future<void> assertClean(String body) =>
      assertNoDiagnostics('$_preamble\n$body');

  /// Asserts that [body], appended to the shared preamble, reports a lint on
  /// the last occurrence of [target], with a message containing [messageParts].
  Future<void> assertReportsOn(
    String body,
    String target, {
    List<String> messageParts = const [],
  }) async {
    final content = '$_preamble\n$body';
    final offset = content.lastIndexOf(target);
    expect(
      offset,
      isNonNegative,
      reason: "fixture contains no expression matching '$target'",
    );
    await assertDiagnostics(content, [
      lint(offset, target.length, messageContainsAll: messageParts),
    ]);
  }

  // --- Reports. ---

  Future<void> test_reports_inInterpolation() async {
    await assertReportsOn(
      r'''
void f(Session s) {
  final line = 'token: ${s.token}';
  line.length;
}
''',
      's.token',
      messageParts: ['token', 'interpolated'],
    );
  }

  Future<void> test_reports_forThisField() async {
    await assertReportsOn(
      r'''
class Client extends Session {
  String describe() => 'token: $token';
}
''',
      'token',
      messageParts: ['interpolated'],
    );
  }

  Future<void> test_reports_forTopLevelVariable() async {
    await assertReportsOn(r'''
String f() => 'value: $globalToken';
''', 'globalToken');
  }

  Future<void> test_reports_withReasonInMessage() async {
    await assertReportsOn(
      r'''
String f() => 'value: $documentedToken';
''',
      'documentedToken',
      messageParts: ['OAuth refresh token'],
    );
  }

  Future<void> test_reports_forAnnotatedParameter() async {
    await assertReportsOn(r'''
void f(@Sensitive() String secret) {
  print('$secret');
}
''', 'secret');
  }

  Future<void> test_reports_forAnnotatedLocal() async {
    await assertReportsOn(r'''
void f() {
  @Sensitive()
  final secret = 'x';
  print('$secret');
}
''', 'secret');
  }

  Future<void> test_reports_forFieldFormalParameter() async {
    await assertReportsOn(r'''
class Holder {
  @Sensitive()
  final String token;

  Holder(this.token) {
    print('$token');
  }
}
''', 'token');
  }

  Future<void> test_reports_inStringConcatenation() async {
    await assertReportsOn(
      r'''
void f(Session s) {
  print('token: ' + s.token);
}
''',
      's.token',
      messageParts: ['concatenated'],
    );
  }

  Future<void> test_reports_forAnnotatedGetter() async {
    // An explicit getter carries the annotation on the accessor, not on the
    // synthetic variable a read resolves to.
    await assertReportsOn(
      r'''
class Vault {
  @Sensitive()
  String get secret => 'x';

  String describe() => 'secret: $secret';
}
''',
      'secret',
      messageParts: ['interpolated'],
    );
  }

  Future<void> test_reports_forToStringCall() async {
    await assertReportsOn(
      r'''
void f(Session s) {
  s.token.toString();
}
''',
      's.token',
      messageParts: ['toString'],
    );
  }

  Future<void> test_reports_whenPassedToPrint() async {
    await assertReportsOn(
      r'''
void f(Session s) {
  print(s.token);
}
''',
      's.token',
      messageParts: ['logging sink'],
    );
  }

  Future<void> test_reports_whenPassedToLoggerMethod() async {
    await assertReportsOn(
      r'''
void f(Session s) {
  logger.severe(s.token);
}
''',
      's.token',
      messageParts: ['logging sink'],
    );
  }

  Future<void> test_reports_whenPassedToNamedLoggerArgument() async {
    await assertReportsOn(
      r'''
void log({String? message}) {}

void f(Session s) {
  log(message: s.token);
}
''',
      's.token',
      messageParts: ['logging sink'],
    );
  }

  Future<void> test_reports_inExceptionConstructor() async {
    await assertReportsOn(
      r'''
void f(Session s) {
  throw AuthError(s.token);
}
''',
      's.token',
      messageParts: ['exception message'],
    );
  }

  Future<void> test_reports_inErrorConstructor() async {
    await assertReportsOn(
      r'''
class AuthFailure extends Error {
  AuthFailure(this.detail);
  final String detail;
}

void f(Session s) {
  throw AuthFailure(s.token);
}
''',
      's.token',
      messageParts: ['exception message'],
    );
  }

  Future<void> test_reports_throughLocalAlias() async {
    await assertReportsOn(r'''
void f(Session s) {
  final copy = s.token;
  print('$copy');
}
''', 'copy');
  }

  Future<void> test_reports_throughConditional() async {
    await assertReportsOn(r'''
void f(Session s, bool flag) {
  print(flag ? s.token : s.user);
}
''', 'flag ? s.token : s.user');
  }

  Future<void> test_reports_onceForConditionalOfTwoSecrets() async {
    await assertReportsOn(r'''
void f(Session s, bool flag) {
  print(flag ? s.token : globalToken);
}
''', 'flag ? s.token : globalToken');
  }

  Future<void> test_reports_forReassignedAnnotatedLocal() async {
    await assertReportsOn(r'''
void f() {
  @Sensitive()
  var secret = 'x';
  secret = 'y';
  print('$secret');
}
''', 'secret');
  }

  // --- Clean. ---

  Future<void> test_clean_whenValueIsNotAnnotated() async {
    await assertClean(r'''
void f(Session s) {
  print('user: ${s.user} $publicName');
}
''');
  }

  Future<void> test_clean_whenSecretIsUsedWithoutExposure() async {
    await assertClean(r'''
bool f(Session s, String input) => s.token == input;
''');
  }

  Future<void> test_clean_whenOnlyLengthIsLogged() async {
    await assertClean(r'''
void f(Session s) {
  print('token length: ${s.token.length}');
}
''');
  }

  Future<void> test_clean_forSameNamedFieldOfAnotherType() async {
    await assertClean(r'''
class Other {
  final String token = 'x';
}

void f(Other other) {
  print('${other.token}');
}
''');
  }

  Future<void> test_clean_forNumericAddition() async {
    // `+` only concatenates for strings; adding numbers cannot leak text.
    await assertClean(r'''
class Card {
  @Sensitive()
  final int pin = 1;

  int next() => pin + 1;
}
''');
  }

  Future<void> test_clean_forAnnotatedSetter() async {
    // The annotation sits on the setter, so reading the unannotated getter is
    // not an exposure.
    await assertClean(r'''
class Vault {
  String _value = 'x';

  @Sensitive()
  set secret(String value) => _value = value;

  String get secret => _value;

  String describe() => 'value: $secret';
}
''');
  }

  Future<void> test_clean_forNonLoggingCall() async {
    await assertClean(r'''
void send(String value) {}

void f(Session s) {
  send(s.token);
}
''');
  }

  Future<void> test_clean_forNonExceptionConstructor() async {
    await assertClean(r'''
class Request {
  Request(this.token);
  final String token;
}

Request f(Session s) => Request(s.token);
''');
  }

  Future<void> test_clean_whenAnnotationComesFromAnotherPackage() async {
    // Written without the shared preamble, so that the only `Sensitive` in
    // scope is this look-alike from the fixture itself.
    await assertNoDiagnostics(r'''
class Sensitive {
  const Sensitive();
}

class Fake {
  @Sensitive()
  final String token = 'x';
}

void f(Fake fake) => print('${fake.token}');
''');
  }
}
