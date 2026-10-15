<!-- brand:start -->

<p align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/banner-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/banner-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/banner-light.svg" alt="sizeledger: Shows where every megabyte of an iOS app comes from: by category, framework, asset catalog, language and architecture."></picture></p>

<!-- lang-selector:start -->
<p align="center"><a href="README.md">English</a> · <a href="README.tr.md">Türkçe</a> · <a href="README.zh-CN.md">简体中文</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a> · <a href="README.de.md">Deutsch</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>
<!-- lang-selector:end -->

<p align="center">
<a href="https://github.com/muhittincamdali/sizeledger/actions/workflows/ci.yml"><img src="https://github.com/muhittincamdali/sizeledger/actions/workflows/ci.yml/badge.svg" alt="CI status"></a>
<a href="https://github.com/muhittincamdali/sizeledger/releases"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-version-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-version-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-version-light.svg" alt="Latest version: v0.1.2"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/blob/main/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-platforms-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-platforms-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-platforms-light.svg" alt="Supported platforms: macOS 13+, Linux (x86_64, arm64)"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/blob/main/Package.swift"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-language-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-language-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-language-light.svg" alt="Language version: Swift 6.2+ · Swift 6 mode"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/blob/main/LICENSE"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-license-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-license-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/badge-license-light.svg" alt="License: MIT"></picture></a>
</p>

<p align="center">
<a href="#quick-start"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-start-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-start-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-start-en-light.svg" alt="Get started"></picture></a>
<a href="https://muhittincamdali.github.io/sizeledger/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-docs-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-docs-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-docs-en-light.svg" alt="Documentation"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/tree/main/docs/guides"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-guides-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-guides-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-guides-en-light.svg" alt="Guides"></picture></a>
<a href="https://github.com/muhittincamdali/sizeledger/tree/main/Examples"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-examples-en-dark.svg"><source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-examples-en-light.svg"><img src="https://raw.githubusercontent.com/muhittincamdali/sizeledger/main/.github/brand/button-examples-en-light.svg" alt="Examples"></picture></a>
</p>

<!-- brand:end -->

Point sizeledger at an `.ipa`, an `.app` or an `.xcarchive` and it shows where the app's bytes
are: by category, by framework and resource, by language and by CPU architecture. It reads the
files only; it does not build, run, upload or change anything, and it works the same on macOS and
Linux.

<picture><source media="(prefers-color-scheme: dark)" srcset="docs/media/demo-analyze-dark.svg"><source media="(prefers-color-scheme: light)" srcset="docs/media/demo-analyze-light.svg"><img src="docs/media/demo-analyze-light.svg" alt="sizeledger analyze on SampleShop 2.0: 8.75 MB in 21 files, 8.80 MB install estimate, 2.72 MB compressed; catalog.json is 70.8% of the app, Assets.car 18.1%; seven languages; three universal binaries with x86_64 and arm64 slices"></picture>

<sub>Recorded from the real command (<code>node scripts/demo.mjs</code>) on
<a href="Fixtures/README.md">SampleShop 2.0</a>, a SwiftUI app this repository builds for the iOS
Simulator. The output is the same on a Mac (Apple silicon) and in the Linux CI images.</sub>

## Highlights

- **One table for the whole app.** Main executable, frameworks and dylibs, app extensions, App
  Clips, watch app, localizations, asset catalogs, code signature and everything else. The
  categories always add up to the total.
- **Every framework and extension on its own line**, and every `.lproj` language summed across
  the app and its frameworks.
- **Architecture slices of every binary**: which binaries are universal and how much each slice
  takes, with segment sizes and Swift metadata in the JSON.
- **Three sizes kept apart**: what the files add up to, an install size estimate (whole 4 KiB
  blocks, as APFS stores them) and, for an `.ipa`, the compressed size. sizeledger does not claim
  to know the App Store's download size; [here is why](docs/guides/why-install-size-is-an-estimate.md).
- **For people and for CI**: a terminal table, Markdown for a pull request or job summary, and a
  JSON report with a stable key order that you can commit, `jq` and compare.
- **A Swift library too**: [SizeLedgerKit](https://muhittincamdali.github.io/sizeledger/) gives
  the same report to your own tools. No dependencies: the ZIP reader, DEFLATE decoder and Mach-O
  parser are part of it.

## Quick start

**1. Install** (macOS or Linux with [Homebrew](https://brew.sh)):

```sh
brew install muhittincamdali/tap/sizeledger
```

Without Homebrew, use a [release binary or build from source](#installation).

**2. Measure your app.** Any of these works: an `.ipa` you exported, the `.app` from a build, or
an `.xcarchive` from **Product › Archive**.

```sh
sizeledger analyze path/to/MyApp.ipa
```

**3. Read the table.** "By category" says what kind of content is heavy; "Largest items" names
the files, frameworks and folders; "Binaries" shows which ones carry more than one architecture.
The notes at the end say when a number needs context (for example, a simulator build). Save the
full report with `--out size/main.json` to keep it or compare it later.

[Read your first breakdown](docs/guides/read-your-first-breakdown.md) walks through a real
report line by line.

## What works today

| Feature | Status |
| --- | --- |
| `analyze` an `.app`, `.ipa` or `.xcarchive`: categories, components, languages, binaries and slices, file tree | works |
| Output as a terminal table, Markdown or JSON (`--format`, `--out`) | works |
| macOS 13+ and Linux (x86_64 and arm64, Swift 6.2 and 6.4.1 in CI) | works |
| SizeLedgerKit library with DocC documentation | works |
| `diff` of two reports, with a Markdown summary for pull requests | planned (0.2) |
| `budget` rules in YAML (per path, total, App Clip limit) with exit code 1, and a GitHub Action | planned (0.3) |
| Single-file HTML treemap; asset catalog renditions through `assetutil` on macOS | planned (0.8) |
| Frozen JSON schema (version 1) | planned (1.0) |
| Android `.apk` and `.aab` | planned (1.1) |

Until `budget` exists, a limit check in CI is one line of `jq`; see
[Size checks in CI](docs/guides/size-checks-in-ci.md).

## Installation

| Method | Command |
| --- | --- |
| Homebrew (macOS, Linux) | `brew install muhittincamdali/tap/sizeledger` |
| Release binary | Download `sizeledger-<version>-macos-universal.tar.gz` or `-linux-x86_64` / `-linux-aarch64` from [Releases](https://github.com/muhittincamdali/sizeledger/releases), check it against `SHA256SUMS`, put `sizeledger` on your `PATH` |
| From source | `git clone https://github.com/muhittincamdali/sizeledger.git && cd sizeledger && swift build -c release` (the binary is `.build/release/sizeledger`) |
| Swift package | `.package(url: "https://github.com/muhittincamdali/sizeledger", from: "0.1.2")`, product `SizeLedgerKit` |

Building needs Swift 6.2 or later (Xcode 26 or later on a Mac). The Linux release binaries carry
the Swift runtime and need glibc 2.35 or later (Ubuntu 22.04, Debian 12 or newer).

## Usage

```text
sizeledger analyze <input> [--format tty|markdown|json] [--out <file>] [--top <n>] [--color auto|always|never] [--quiet]
```

| Option | What it does |
| --- | --- |
| `<input>` | An `.app` folder, an `.ipa` file or an `.xcarchive` folder |
| `-f, --format` | What to print: `tty` (default, a table), `markdown` or `json` |
| `-o, --out <file>` | Also write the JSON report to a file; missing folders are created |
| `--top <n>` | How many items, languages and binaries to list (default 10) |
| `--color` | `auto` colours only in a terminal and not when `NO_COLOR` is set |
| `-q, --quiet` | Print nothing (with `--out`) |

Exit status: `0` when the report was made, `2` when the input could not be read or the report
could not be written (one line on standard error says why), `64` for invalid options. `1` is kept
for the planned `budget` command.

```sh
# Keep the report for later
sizeledger analyze build/MyApp.ipa --out size/main.json

# Markdown in a GitHub Actions job summary
sizeledger analyze build/MyApp.xcarchive --format markdown >> "$GITHUB_STEP_SUMMARY"

# The ten biggest files anywhere in the bundle (bytes and file name)
jq -r '[.tree | .. | objects | select(has("children") | not)] | sort_by(-.bytes) | .[:10][] | "\(.bytes)\t\(.name)"' size/main.json
```

The JSON layout is described in the [DocC article](https://muhittincamdali.github.io/sizeledger/documentation/sizeledgerkit/jsonlayout);
[Fixtures/snapshots](Fixtures/snapshots) has complete reports.

## The three sizes

| Size | Meaning | For SampleShop 2.0 |
| --- | --- | --- |
| Total (`bytes`) | The files added up, what a file manager shows | 8.75 MB |
| Install size, estimate (`installBytes`) | Every file rounded up to whole 4 KiB blocks, as APFS stores them | 8.80 MB |
| Compressed in the `.ipa` (`compressedBytes`) | What the bundle's files take inside the archive; `.ipa` input only | 2.72 MB |

None of them is the App Store's download or install size: the App Store thins the app per
device, encrypts the binaries and compresses the download. Xcode's App Thinning Size Report and
App Store Connect give those numbers. sizeledger gives the ones you can get from the files
alone, on any machine, for every build.
[Why the install size is an estimate](docs/guides/why-install-size-is-an-estimate.md) has the
details, and [App Clip size limits](docs/guides/app-clip-size.md) applies them to App Clips.

## How it is tested

- **Against `du`**, the v0.1 acceptance check, on the two SampleShop versions unpacked from the
  `.ipa`. On a Mac (Apple silicon, macOS 27.0.1, APFS) the install estimate equals `du -sk`
  exactly and the total is within 0.16% of `du -A`; in the Linux container (swift:6.4.1-noble,
  aarch64) the total equals `du -b --apparent-size` and the install estimate is within 0.65% of
  `du -sk`, which also counts 4 KiB per folder there. The tests fail above 1% on both.
- **Snapshots**: the JSON, text and Markdown reports of both versions are committed; the same
  snapshots pass on macOS and Linux.
- **A real app**: SampleShop is built with `swiftc`, `actool` and `codesign` by
  [a script](Fixtures/scripts/build-sample-app.sh) and runs in the iOS 27.0 simulator:

  <picture><source media="(prefers-color-scheme: dark)" srcset="docs/media/sampleshop-ios27-simulator-dark.png"><source media="(prefers-color-scheme: light)" srcset="docs/media/sampleshop-ios27-simulator-light.png"><img src="docs/media/sampleshop-ios27-simulator-light.png" alt="SampleShop 2.0 in the iOS 27 Simulator: a banner and a list of products with images and prices" width="240"></picture>

- **Readers checked against references**: the DEFLATE decoder against zlib's output for stored,
  fixed and dynamic blocks; the Mach-O parser on thin, 32-bit, fat and fat64 files; ZIP64,
  damaged archives and file names that carry terminal escape sequences.

100 tests in total, run by CI on macOS and on Linux (x86_64 and arm64). Measuring SampleShop 2.0
takes a median of 10.5 ms over 21 runs on a Mac (Apple silicon) with the release build, process
start included; [scripts/bench.sh](scripts/bench.sh) repeats the measurement.

## Limits

- Sizes are local measurements. App Store download and install sizes depend on thinning,
  encryption and compression that happen at Apple, so sizeledger reports an estimate and says
  so.
- Asset catalogs (`Assets.car`) are counted as files; the renditions inside them are not listed
  yet (planned for 0.8, through `assetutil` on macOS).
- Swift metadata is the size of the `__swift5_*` sections, a lower bound: some metadata lives in
  `__const`.
- iOS-style bundles (iOS, iPadOS, tvOS, watchOS, visionOS) are classified. A macOS `.app` with a
  `Contents/` folder is measured, but its files land under "Other resources".
- An `.ipa` with more than one app, encrypted entries, compression other than stored and
  DEFLATE, or an entry path with a `..` component is refused with a message, not guessed at.
- To reach a Mach-O header far into a compressed `.ipa` entry, sizeledger decompresses everything
  before it and keeps only a 32 KiB window, so a crafted entry costs time, not memory: about 1 s per
  decompressed GB on a Mac (Apple silicon).

## Documentation

- [Guides](docs/guides/): read your first breakdown, the install size estimate, App Clip size
  limits, size checks in CI.
- [API documentation](https://muhittincamdali.github.io/sizeledger/) (DocC) for SizeLedgerKit,
  with getting started and the JSON layout.
- [Examples](Examples/): a Swift program on SizeLedgerKit and a GitHub Actions workflow.
- [Changelog](CHANGELOG.md).

## Contributing

Bug reports with a small app that shows the problem help most. See
[CONTRIBUTING.md](CONTRIBUTING.md) for building, tests and snapshots, and
[SECURITY.md](SECURITY.md) for reporting a vulnerability privately.

## License

[MIT](LICENSE)
