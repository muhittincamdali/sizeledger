# Changelog

All notable changes to sizeledger are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Until 1.0, the JSON report layout
(`schemaVersion` 0) may change in a minor version; the changelog says when it does.

## [Unreleased]

### Added

- README translations: Türkçe, 简体中文, 日本語, 한국어, Español, Deutsch, Français, Português (Brasil)
  and Русский, linked from the language selector.

### Changed

- Load commands of more than 1 MiB in one Mach-O slice (was 16 MiB) are reported as damaged; real
  binaries have tens of kilobytes.

### Fixed

- A ZIP64 entry whose offset or size is above `Int.max`, and a universal binary whose slice offset
  plus size overflows, are reported as damaged instead of stopping sizeledger.

### Security

- A crafted `.ipa` could make sizeledger use unbounded memory: a universal binary whose fat header
  put a slice 1 GB into a DEFLATE entry made it keep every decompressed byte in front of that
  slice (3.77 GB resident for a 1 MB file). Mach-O headers are now read as ranges of at most
  4 KiB, or as far as a slice's load commands reach, and decompression keeps only the 32 KiB that
  DEFLATE back-references need; the same file now takes 11.5 MB on a Mac (Apple silicon).

## [0.1.0] - 2026-10-15

First release: `sizeledger analyze` and the SizeLedgerKit library.

### Added

- `sizeledger analyze <input>` for an `.app` folder, an `.ipa` or an `.xcarchive`: totals, a
  breakdown by category (main executable, frameworks, app extensions, App Clips, watch app,
  localizations, asset catalogs, code signature, other resources), the largest components, the
  `.lproj` languages across the whole bundle, and every Mach-O binary with its architecture
  slices.
- Three sizes kept apart: the files added up, an install size estimate (whole 4 KiB blocks) and,
  for an `.ipa`, the compressed size; notes for simulator builds, universal binaries, files
  outside the bundle, App Clips and unreadable input.
- Output as a terminal table, GitHub Markdown or JSON (`--format`), the JSON report written to a
  file with `--out`, `--top`, `--color` and `--quiet`. Exit status 0, 2 for unreadable input and
  64 for invalid options.
- SizeLedgerKit: `SizeLedger.analyze(_:)`, `SizeReport` with a stable JSON encoding, text and
  Markdown renderers, documented with DocC.
- A ZIP reader (with ZIP64), a DEFLATE decoder and a Mach-O parser (thin, fat and fat64) in
  Swift, so the library has no dependencies and runs on macOS and Linux.
- SampleShop, a two-version sample app built for the iOS Simulator by a script, with report
  snapshots and a check that the totals agree with `du` within 1% on macOS and Linux.
- Release binaries for macOS (universal) and Linux (x86_64, aarch64), and a Homebrew formula
  written by the release workflow.

[Unreleased]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/muhittincamdali/sizeledger/releases/tag/v0.1.0
