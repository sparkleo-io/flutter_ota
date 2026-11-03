# Contributing to flutter_ota

Thanks for helping improve ESP32 OTA over BLE for Flutter. This guide covers
how to report issues, propose changes, and get a pull request ready for review.

## Ways to contribute

- **Bug reports** — unexpected disconnects, protocol failures, progress-stream
  edge cases, or docs that don't match the code
- **Fixes and small improvements** — especially around protocol correctness,
  validation, tests, and documentation
- **Features** — open an issue first for anything that changes the public API
  or the on-wire OTA protocol so we can agree on shape before coding

## Development setup

1. Fork and clone the repository.
2. Use a Flutter install whose bundled Dart is **≥ 3.8.0** (this package requires
   `sdk: '>=3.8.0 <4.0.0'`). Always run `flutter pub get`, `dart format`,
   `flutter analyze`, and `flutter test` via that Flutter SDK on your `PATH` —
   **not** a standalone Homebrew/`dart` install. Older system Darts (e.g. 3.3)
   apply different formatter rules and can produce large, spurious `dart format`
   diffs across the repo.
3. From the repo root:

```bash
flutter pub get
cd example && flutter pub get && cd ..
```

4. Prefer a physical Android or iOS device when exercising BLE; simulators
   usually cannot talk to an ESP32.

## Checks before you open a PR

CI runs the same commands locally (again: Flutter’s Dart, not a separate one):

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test

cd example
flutter analyze --fatal-infos
flutter test
```

Confirm with `which dart` / `dart --version` that you are on the Flutter-bundled
SDK (≥ 3.8.0) before formatting. Fix format/analyze/test failures before
requesting review.

## Pull request guidelines

- Keep PRs focused — one bugfix or one feature per PR when practical.
- Match existing style: typed `OtaException`s, early validation, structured
  `logger` output (no `print` in library code).
- Add or update unit tests for protocol, chunking, integrity, and validation
  changes.
- Update `CHANGELOG.md` under an `[Unreleased]` section (or the next version)
  when the public API or user-visible behavior changes.
- For breaking API changes, update [MIGRATION.md](MIGRATION.md) and the
  relevant sections of [README.md](README.md) / [DOCUMENTATION.md](DOCUMENTATION.md).
- Do not commit secrets, local SDK paths, or build artifacts (see `.gitignore`
  and `.pubignore`).

## Protocol and API changes

The ESP-IDF and Arduino BLE sequences are documented in
[DOCUMENTATION.md §4](DOCUMENTATION.md#4-protocol-handshake-sequences). Treat
on-wire opcodes and packet layouts as a compatibility contract with device
firmware:

- Prefer additive, optional features (for example integrity flags) over
  changing existing opcodes.
- Default behavior should remain safe for devices that do not implement new
  features.
- If you must break the Dart API, bump the major version and document the
  migration path.

## Reporting security issues

If you believe you found a security-sensitive bug (for example something that
could brick devices at scale or expose firmware over the network unexpectedly),
prefer a private report to the maintainers via the repository's
[security advisories](https://github.com/sparkleo-io/flutter_ota/security) or
contact the publisher listed on [pub.dev](https://pub.dev/publishers/sparkleo.io)
rather than opening a public issue with exploit details.

## License

By contributing, you agree that your contributions are licensed under the same
[MIT License](LICENSE) as the project.
