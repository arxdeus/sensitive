# Changelog

All notable changes to this package are recorded here. Versions follow
[semver](https://semver.org). A new diagnostic is a minor bump rather than a
patch, because it can fail a build that passed before.

## 1.0.0

First release.

An analyzer plugin that keeps secrets out of logs. Mark a value `@Sensitive()`
and the `sensitive_exposure` rule reports it being interpolated into a string,
concatenated, converted with `toString()`, passed to a logging sink, or put into
an exception or error constructor.

```dart
@Sensitive('PII')
final String email;

log('signing in $email');  // sensitive_exposure
```

- Covers fields, getters, parameters, locals and top-level variables, and treats
  an annotation on a field as covering its `this.x` constructor parameter.
- Follows local aliases and conditionals, so renaming a secret into a local does
  not hide it.
- Recognises logging sinks by method name, because loggers live in many different
  packages and a secret reaching any of them is a leak.
- Leaves derived non-secret values alone, so logging `email.length` is fine.
- Identifies `@Sensitive` by its declaring package, so a same-named annotation
  from somewhere else cannot trigger the rule.

Diagnostics are suppressed the usual way, with the plugin name as a prefix:

```dart
// ignore: sensitive/sensitive_exposure
```

### If you used this rule inside arxdeus_lints

It shipped there once, alongside rules about object lifetimes. Keeping a secret
out of a log has nothing to do with disposing a controller, and a project that
wanted one had to take the other, so it now stands on its own.

To migrate: add `sensitive` to `dependencies` and to the `plugins` section of
`analysis_options.yaml`, import `@Sensitive` from
`package:sensitive/sensitive.dart`, and change any
`// ignore: arxdeus_lints/sensitive_exposure` comment to the `sensitive/` prefix.
The diagnostics themselves are identical.
