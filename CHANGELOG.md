## 1.0.0

- Depends on `analyzer_plugin_toolkit` by version rather than by path. The
  repository is a pub workspace, so that constraint still resolves to the
  working tree during development while being the constraint the package
  actually publishes with.

- Extracted from `arxdeus_lints`, where this rule shipped alongside the
  object-lifetime rules. Keeping a secret out of a log has nothing to do with
  disposing a controller, so it is now its own plugin: a project that wants
  `@Sensitive` no longer has to take `missing_dispose` and `stateful_in_build`
  with it, and either package can be enabled without the other.

  What moved, unchanged in behaviour:

  - The `@Sensitive` annotation, now `package:sensitive_exposure_lint`.
  - The `sensitive_exposure` rule, which reports an annotated value being
    interpolated into a string, converted with `toString()`, passed to a
    logging sink, or put into an exception message.

  Migration: replace the `arxdeus_lints` import used for `@Sensitive` with
  `package:sensitive_exposure_lint/sensitive_exposure_lint.dart`, add
  `sensitive_exposure_lint` to `dependencies` and to the `plugins` section,
  and change any `// ignore: arxdeus_lints/sensitive_exposure` comment to the
  `sensitive_exposure_lint/` prefix. Nothing else changed: the rule reports
  identical diagnostics.
