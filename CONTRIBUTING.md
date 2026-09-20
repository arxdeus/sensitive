# Contributing

Thanks for taking an interest. The most useful thing you can do before writing
code is to open an issue with the Dart snippet you expected a diagnostic on, or
the one you did not.

## Scope

One rule, `sensitive_exposure`, answering one question: could this value reach
somewhere a person or a log file can read it? Interpolation, concatenation,
`toString()`, a logging sink, an exception message.

Two things are deliberately out of scope. The rule does not try to prove a value
is safe, only to report the ways it is obviously not, so it will always miss
some paths. And it does not attempt taint tracking across function boundaries:
the cost in false positives is not worth it for a rule people are meant to leave
switched on.

A false positive is worse than a false negative here, because a rule that cries
wolf gets switched off, and then it reports nothing at all.

## Getting set up

```sh
git clone https://github.com/arxdeus/sensitive
cd sensitive && dart pub get
```

The example is its own package and resolves separately:

```sh
cd example && dart pub get
```

## Checks

Everything CI runs, you can run:

```sh
dart format .
dart analyze --fatal-infos          # must be clean
dart test                           # the rule's behaviour
dart run tool/verify_example.dart   # the plugin actually loads and fires
dart pub publish --dry-run          # the archive still validates
```

The third one is less obvious than it looks, and is the one worth understanding.

`dart test` drives the rule through the analyzer's testing harness, which calls
it directly. That is a fine way to test rule logic, and a useless way to find
out whether the *plugin* works: the harness never registers it, never loads it
the way the analysis server does, and never reads your `analysis_options.yaml`.
So a plugin that registers under the wrong name, or fails to start at all,
leaves every test passing while the rule does nothing whatsoever for a real
user.

This package shipped exactly that fault. The example enabled the plugin with a
version constraint, the analysis server dutifully looked for it on pub.dev where
it was not published, and setup failed silently. Every `// reported:` comment in
the example was a claim nothing checked.

`tool/verify_example.dart` closes that. It reads the example's own comments as
the specification: a line tagged `// reported:` must produce a diagnostic, and
every other line must produce none. Adding a case to the example extends the
check for free, and neither a rule regression nor a plugin that fails to load
can pass it.

This is also why the example's `analysis_options.yaml` names the plugin by
`path:` rather than by version. A `pubspec_overrides.yaml` will not redirect it,
because the analysis server resolves a plugin independently of the package
around it.

## Commit messages

Commits follow [Conventional Commits][cc]:

```
<type>(<optional scope>): <summary in the imperative mood>
```

| Type | For |
| --- | --- |
| `feat` | The rule reports something it did not before. |
| `fix` | A false positive, or a leak that went unreported. |
| `perf` | Same diagnostics, less work. Rules run on every node of every file. |
| `refactor` | Internal shape, no behaviour change. |
| `docs` | README, CHANGELOG, comments. |
| `test` | Tests and the tools that check invariants. |
| `build` | `pubspec.yaml`, dependency constraints, the archive. |
| `ci` | Workflows. |
| `chore` | Anything left over. |

Append `!` after the type for a breaking change, and explain the migration in
the body. Renaming the annotation or the rule is breaking: both appear in
consumers' source, the rule name in every `// ignore:` comment.

Keep the summary under about 72 characters, lowercase, no trailing period.

## Pull requests

- One concern per pull request.
- Every behaviour change needs a test. For a rule, that means both directions:
  the case that should now be reported, and the nearby case that must stay
  quiet.
- If the change is worth a reader's attention, add it to the example, which
  documents and tests it in one place.
- Update `CHANGELOG.md` under an `## Unreleased` heading for anything a consumer
  would notice. Version bumps happen at release time, not in the pull request.

## Releasing

1. `CHANGELOG.md`: turn `## Unreleased` into the version.
2. `pubspec.yaml`: bump `version`, following [semver][]. A new diagnostic is a
   minor bump, since it can fail a build that passed before.
3. `dart pub publish --dry-run` must be clean.
4. Merge, then tag: `git tag v<version> && git push origin v<version>`.

The tag triggers the `publish` workflow, which publishes through GitHub's OIDC
token. There is no stored pub credential to leak.

## License

By contributing you agree that your contribution is MIT licensed, as the rest of
the package is.

[cc]: https://www.conventionalcommits.org/en/v1.0.0/
[semver]: https://semver.org
