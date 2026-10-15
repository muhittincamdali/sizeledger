# Changelog

All notable changes to sizeledger are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). Until 1.0, the JSON report layout
(`schemaVersion` 0) may change in a minor version; the changelog says when it does.

## [Unreleased]

## [0.1.5] - 2026-10-15

### Changed

- `--max-depth` accepts 1 to 100, and `SizeLedger.analyze` lowers a higher `maxDepth` to
  `AnalysisLimits.deepestAllowed` (100). The default stays 64.

### Fixed

- With `--max-depth` raised far enough, a bundle about 254 folders deep made `--format json` print
  nothing and exit 0: `JSONEncoder` stops at 512 levels and the error was dropped. An encoding
  error now ends with a message and exit status 2, and the depth ceiling keeps reports well inside
  what JSON encoding and decoding handle, on any thread.
- A top-level Info.plist that is a symbolic link got the note "No Info.plist"; the note now says
  it is a link and that links are not followed.
- The `--max-bytes` help said "input"; the limit applies to an `.ipa` only, since a bundle folder
  is not decompressed.

### Security

- File names with the bidirectional overrides, embeddings and isolates (U+202A to U+202E, U+2066
  to U+2069) reached the table and the Markdown report as they were, so a name could display as
  something else (`gpj.exe` as `exe.jpg`) or reorder a table row. They are now replaced with
  U+FFFD there; the JSON report still keeps every codepoint.

## [0.1.4] - 2026-10-15

### Added

- `--max-files`, `--max-bytes`, `--max-ratio` and `--max-depth`, and `AnalysisLimits` with
  `SizeLedger.analyze(_:limits:)` in the library: an input with more than 500,000 files, more than
  8 GiB of declared uncompressed bytes, an `.ipa` entry that declares more than 300 times its
  stored size, or a path deeper than 64 folders is refused with exit status 2.

### Changed

- The Markdown report escapes `(` and `)` as well, and writes a URL, email address, @mention or
  `#123` reference from the app in a code span. It renders the same; the Markdown source differs.
- A path listed twice in an `.ipa` is counted once (the last entry, as an unzip tool keeps it).

### Security

- These crafted inputs stopped sizeledger or ran it out of memory or time, and now end with a
  message: a Mach-O file whose `__swift5_` section sizes add past 2^64 (crash); a ZIP64 locator or
  directory offset above `Int.max` (crash); an `.ipa` entry nested 32,000 folders deep (stack
  overflow); 50 entries sharing one 1 GB DEFLATE stream in a 1 MB file (54 s); 1,000,000
  central-directory entries (1 GB of memory).
- The JSON report wrote DEL and the C1 controls in file names as raw bytes, which a terminal can
  act on; they are now written as `\u007f`, `\u009b` and so on.
- In the Markdown report, a combining mark after `|` or a backtick got past the escaping and could
  split a table cell or close a code span, and URLs, emails, @mentions and `#` references from the
  app became links or pinged users. Escaping now works on Unicode scalars, and each case is checked
  against GitHub's renderer in `Fixtures/markdown/escaping.json`.

## [0.1.3] - 2026-10-15

### Security

- A crafted `.ipa` whose ZIP64 entries declared sizes near 2^64 bytes stopped sizeledger: adding
  the sizes up, rounding them to 4 KiB blocks and printing them overflowed. Sizes now saturate at
  the largest 64-bit value and print as `18446744073.71 GB`.

## [0.1.2] - 2026-10-15

### Added

- `scripts/bench.sh`, the benchmark behind the timing in the README: the median of N runs of
  `sizeledger analyze` with the release build, process start-up included.

### Changed

- `--quiet` without `--out` is refused with exit status 64; before, it measured the app and
  printed and wrote nothing.
- `sizeledger MyApp.ipa` (an app where the subcommand belongs) shows the `sizeledger analyze`
  command to run instead of only "Unexpected argument". The exit status is still 64.

### Security

- An `.xcarchive` whose `Products`, `Products/Applications` or `<name>.app` was a symbolic link
  made sizeledger measure the folder the link pointed to, outside the archive: the names and
  sizes of its files went into the report and Mach-O headers there were read. Links on the way to
  the archived app are now refused with exit status 2. A path you pass yourself is still followed
  when it is a link.

## [0.1.1] - 2026-10-15

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

[Unreleased]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.5...HEAD
[0.1.5]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/muhittincamdali/sizeledger/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/muhittincamdali/sizeledger/releases/tag/v0.1.0
