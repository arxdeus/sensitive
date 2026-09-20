<!--
The title should read as a conventional commit, since it becomes one:

    fix(rule): follow a secret through a cascade

See CONTRIBUTING.md for the types in use.
-->

## What and why

<!-- What changes, and the reason the diff does not already show. -->

## Checks

- [ ] `dart format .`
- [ ] `dart analyze --fatal-infos` is clean
- [ ] `dart test` passes
- [ ] `dart run tool/verify_example.dart` passes
- [ ] `CHANGELOG.md` updated under `## Unreleased`, if a consumer would notice

## Rule behaviour

- [ ] Unchanged
- [ ] Reports something new, and a test covers it
- [ ] Stops reporting something, and a test covers why that was wrong
- [ ] Breaking, the title carries `!`, and the body explains the migration
