# sensitive

[![pub package](https://img.shields.io/pub/v/sensitive.svg)](https://pub.dev/packages/sensitive)
[![ci](https://github.com/arxdeus/sensitive/actions/workflows/ci.yml/badge.svg)](https://github.com/arxdeus/sensitive/actions/workflows/ci.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Keeps secrets out of logs, delivered as an [analyzer plugin][], so the check
runs in your IDE and in `dart analyze` / `flutter analyze` with no extra
tooling.

A secret leaks the moment it is written somewhere readable, and the usual way
that happens is a debug string nobody meant to keep. Mark the value once, and
the analyzer objects wherever it would escape into text.

| Rule | What it catches |
| --- | --- |
| `sensitive_exposure` | A value marked `@Sensitive()` that is interpolated, stringified, logged or put into an exception message. |

Requires Dart 3.11 or later (analyzer plugins are not supported before that).

## Installation

The package ships both the annotation and the rule, so it is listed twice:
once as a dependency (you write `@Sensitive` in your code) and once as a
plugin (the analyzer runs the rule).

```yaml
# pubspec.yaml
dependencies:
  sensitive: ^1.0.0
```

```yaml
# analysis_options.yaml
plugins:
  sensitive: ^1.0.0
```

The rule is registered as a *warning* rule, so it is active as soon as the
plugin is enabled. Restart the Dart Analysis Server after changing the
`plugins` section.

## `sensitive_exposure`

A secret leaks the moment it is written somewhere readable, and the usual way
that happens is a debug string nobody meant to keep:

```dart
class Session {
  @Sensitive('OAuth refresh token')
  final String token;

  Session(this.token);

  // reported: the token would land in the log.
  void debug() => print('token: $token');

  // reported: the token would land in the crash report.
  void check() {
    if (token.isEmpty) throw StateError('empty token: $token');
  }
}
```

Annotate the field, getter, parameter, local or top-level variable that holds
the secret with `@Sensitive()`, optionally with a reason that is shown in the
message. The rule then reports a reference to it in any of four places:

* string interpolation, `'... $token'`, and `'...' + token` concatenation;
* an explicit `token.toString()`;
* an argument of a call whose name looks like a logging sink (`print`,
  `debugPrint`, `log`, `info`, `warning`, `severe`, `write`, `addError` and
  friends), on any receiver, so third-party loggers are covered;
* an argument of a constructor of a type that implements `Exception` or
  extends `Error`.

Everything else is left alone, so the secret can still be compared, hashed,
sent over the wire, or stored:

```dart
bool matches(String input) => token == input;          // fine
void log() => print('token length: ${token.length}');  // fine
```

A `@Sensitive` field reached through a local alias or a conditional is still
reported, and the annotation on a field also covers the `this.token`
constructor parameter that initializes it.

## Turning the rule off

Disable it for the whole package:

```yaml
plugins:
  sensitive:
    diagnostics:
      sensitive_exposure: false
```

Suppress one diagnostic with a comment, prefixed by the plugin name. The
comment applies to the line below it:

```dart
// ignore: sensitive/sensitive_exposure
print('token: $token');
```

`// ignore_for_file: sensitive/sensitive_exposure` works as well.

## Known limits

These are deliberate boundaries, not bugs:

* **Logging sinks are recognised by name.** A sink called something else
  (`report`, `emit`) is not covered, and a non-logging method that happens to
  be called `write` is reported. The list is deliberately wide, because
  loggers live in other packages (`logging`, `logger`, `talker`, a hand-rolled
  `Log` class) and a secret reaching any of them is a leak regardless of which
  one it is.
* **Only direct references are tracked.** A secret copied into another field,
  returned from a getter, or wrapped in a record first is no longer followed.
  Aliases are followed within a single function body, and only when the local
  is never reassigned.
* **There is no quick fix**, and there should not be: redacting a secret is a
  judgement about what may safely be shown, and no mechanical rewrite can make
  it.

## Example

An example package is wired to this one by path, and is the end-to-end check
that the plugin loads and fires:

```sh
cd example
dart pub get
dart analyze lib/example.dart
```

It deliberately contains violations, so `dart analyze` exits non-zero there.
Use `dart analyze`, not `flutter analyze`: the Flutter wrapper runs its own
bundled analysis and drops diagnostics that come from a third-party analyzer
plugin.

## Development

```sh
dart analyze --fatal-infos          # must be clean
dart test                           # the rule matrix plus plugin registration
dart run tool/verify_example.dart   # the plugin loads, and fires where documented
```

That last one matters more than it looks. `dart test` drives the rule directly
through the analyzer's testing harness, which never loads the plugin the way the
analysis server does, so a plugin that fails to start leaves every test passing
while reporting nothing at all for a real user. The example is the only place the
whole path runs, and `tool/verify_example.dart` holds it to its own
`// reported:` comments.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the scope of the rule, the commit
conventions, and how a release is cut.

## License

MIT. See [LICENSE](LICENSE).

[analyzer plugin]: https://pub.dev/packages/analysis_server_plugin
