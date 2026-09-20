# Changelog

## 1.0.0

Initial release as a standalone package.

An analyzer plugin that keeps secrets out of logs. Mark a value `@Sensitive()`
and the `sensitive_exposure` rule reports it being interpolated into a string,
concatenated, converted with `toString()`, passed to a logging sink, or put
into an exception or error constructor.

```dart
@Sensitive('PII')
final String email;

log('signing in $email');  // sensitive_exposure
```

- Covers fields, getters, parameters, locals and top-level variables, and
  treats an annotation on a field as covering its `this.x` constructor
  parameter.
- Follows local aliases and conditionals, so renaming a secret into a local
  does not hide it.
- Recognises logging sinks by method name, because loggers live in many
  different packages and a secret reaching any of them is a leak.
- Leaves derived non-secret values alone, so logging `email.length` is fine.
- Identifies `@Sensitive` by its declaring package, so a same-named annotation
  from somewhere else cannot trigger the rule.

Previously this rule shipped inside `arxdeus_lints` alongside rules about
object lifetimes. Keeping a secret out of a log has nothing to do with
disposing a controller, and a project that wanted one had to take the other.
Migrating from that version means importing `@Sensitive` from
`package:sensitive_exposure_lint/sensitive_exposure_lint.dart`, adding this
package to `dependencies` and to the `plugins` section, and changing any
`// ignore: arxdeus_lints/sensitive_exposure` comment to the
`sensitive_exposure_lint/` prefix. The rule reports identical diagnostics.
