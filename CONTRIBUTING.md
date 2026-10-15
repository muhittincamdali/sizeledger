# Contributing to sizeledger

Thanks for taking the time to improve sizeledger. The
[shared contributing guide](https://github.com/muhittincamdali/.github/blob/main/CONTRIBUTING.md)
applies (small fixes as a pull request, larger changes as an issue first, security issues through
[SECURITY.md](SECURITY.md), the
[code of conduct](https://github.com/muhittincamdali/.github/blob/main/CODE_OF_CONDUCT.md) for
everyone). This file adds what is specific to this repository.

## Set up

Swift 6.2 or later: Xcode 26 or later on a Mac, or a Swift toolchain on Linux.

```sh
git clone https://github.com/muhittincamdali/sizeledger.git
cd sizeledger
swift build
swift test
```

The tests read only files in the repository and temporary folders; they need neither the
network nor Xcode, and they run the same on Linux. CI runs them on macOS (`ci.yml`) and in the
Swift 6.2.4 and 6.4.1 images on x86_64 and arm64 (`linux.yml`).

| Command                                                               | What it does                                                                            |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `swift test`                                                          | Unit, fixture, snapshot and end-to-end tests (end-to-end ones need `swift build` first) |
| `SIZELEDGER_UPDATE_SNAPSHOTS=1 swift test`                            | Rewrites `Fixtures/snapshots/` after an intended output change                          |
| `swift build -c release && node scripts/demo.mjs`                     | Records the terminal demos in `docs/media/` (Node.js 22 or later)                       |
| `Fixtures/scripts/build-sample-app.sh 1.0` / `2.0`                    | Rebuilds a SampleShop `.ipa` (macOS with Xcode only)                                    |
| `python3 Fixtures/scripts/make-archive-fixtures.py`                   | Rewrites the DEFLATE and ZIP test data                                                  |
| `docker run --rm -v "$PWD:/src" -w /src swift:6.4.1-noble swift test --scratch-path /tmp/build` | The Linux tests on your machine (the end-to-end ones are skipped there) |

## Where things live

- `Sources/SizeLedgerKit/Inventory/`: inputs. `ZipArchive` and `Inflate` read `.ipa` files,
  `DirectorySource` walks folders, `InputLocator` decides what a path is.
- `Sources/SizeLedgerKit/Classifiers/`: `Classifier` (category, component, language rules),
  `MachO` (slices and segments), `AppInfo` (Info.plist).
- `Sources/SizeLedgerKit/Tree/`: `SizeReport`, its JSON form, the tree and the `Analyzer`.
- `Sources/SizeLedgerKit/Report/`: the terminal and Markdown renderers.
- `Sources/SizeLedgerCLI/`: the commands and exit codes; `Sources/sizeledger/` only starts them.
- `Fixtures/`: the SampleShop app and test archives; [Fixtures/README.md](Fixtures/README.md) says
  how each was made.

## Tests

- A bug fix starts with a test that fails without it. Wrong numbers are best reported with the
  smallest bundle that shows them; `TemporaryDirectory` and `ZipBuilder` in the test support
  folder build one in a few lines.
- When the output changes on purpose, rewrite the snapshots, read the diff, and record the demos
  again if the terminal output changed.
- The `du` test is the acceptance check of the install estimate. Do not widen its 1% tolerance to
  make a change pass.

## Wording

sizeledger reports what it can measure. Do not call a number the App Store size, say
"simulator" when a result comes from a simulator build, give every figure in the README with the
environment it was measured in, and keep planned features marked as planned. The hygiene check in
CI rejects unverifiable superlatives.

## Commits and pull requests

[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) (`feat:`, `fix:`, `docs:`,
`test:`, `refactor:`, `build:`, `ci:`, `chore:`), one topic per pull request, and an entry under
"Unreleased" in [CHANGELOG.md](CHANGELOG.md) for anything a user would notice.

## Translations

The language selector at the top of the README links nine translations that are written in a
separate step. Until they exist, the link check skips them and the translation check is not
strict (`"i18nStrict": false` in `.github/brand.json`); both are reverted when they land.

## Releases

Maintainers set `SizeLedger.version` in `Sources/SizeLedgerKit/SizeLedger.swift`, move the
"Unreleased" entries under the new version in `CHANGELOG.md`, and push a `v<version>` tag. The
release workflow checks, builds and publishes; see the comment at the top of
`.github/workflows/release.yml`.

## License

By contributing, you agree that your contributions are licensed under the [MIT license](LICENSE).
