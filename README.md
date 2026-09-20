# sensitive_exposure_lint

Keeps secrets out of logs, delivered as an [analyzer plugin][], so the check
runs in your IDE and in `dart analyze` / `flutter analyze` with no extra
tooling.

A secret leaks the moment it is written somewhere readable, and the usual way
that happens is a debug string nobody meant to keep. Mark the value once, and
the analyzer objects wherever it would escape into text.

| Rule | What it catches |
| --- | --- |
| `sensitive_exposure` | A value marked `@Sensitive()` that is interpolated, stringified, logged or put into an exception message. |

Requires Dart 3.10 or later (analyzer plugins are not supported before that).

## Installation

The package ships both the annotation and the rule, so it is listed twice:
once as a dependency (you write `@Sensitive` in your code) and once as a
plugin (the analyzer runs the rule).

```yaml
# pubspec.yaml
dependencies:
  sensitive_exposure_lint: ^1.0.0
```

```yaml
# analysis_options.yaml
plugins:
  sensitive_exposure_lint: ^1.0.0
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
  sensitive_exposure_lint:
    diagnostics:
      sensitive_exposure: false
```

Suppress one diagnostic with a comment, prefixed by the plugin name. The
comment applies to the line below it:

```dart
// ignore: sensitive_exposure_lint/sensitive_exposure
print('token: $token');
```

`// ignore_for_file: sensitive_exposure_lint/sensitive_exposure` works as well.

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

This package is developed inside the [`qol_lints`][ws] workspace, which checks
it out as a submodule alongside its sibling packages. Its pubspec declares
`resolution: workspace`, so a lone clone of *this* repository cannot resolve on
its own: `dart pub get` needs the workspace root above it. Work on it there.

```sh
git clone --recurse-submodules https://github.com/arxdeus/qol_lints
cd qol_lints && dart pub get
cd packages/sensitive_exposure_lint
dart analyze   # must be clean
dart test      # the rule matrix plus plugin registration
```

## License

MIT. See [LICENSE](LICENSE).

[analyzer plugin]: https://pub.dev/packages/analysis_server_plugin

[ws]: https://github.com/arxdeus/qol_lints
