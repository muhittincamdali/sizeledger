# Examples

| Example                                                    | What it shows                                                                                                                                                 | Checked by                                          |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [LibraryUsage](LibraryUsage)                               | A Swift program that uses SizeLedgerKit: totals, the five largest items, the notes, and exit code 1 when the install estimate is over a limit                 | the Linux workflow builds and runs it on SampleShop |
| [github-actions/app-size.yml](github-actions/app-size.yml) | A pull request workflow: install the release binary, measure the app, write the Markdown breakdown to the job summary, keep the JSON, fail on a limit with jq | actionlint                                          |

## LibraryUsage

```sh
cd Examples/LibraryUsage
swift run SizeCheck ../../Fixtures/apps/SampleShop-2.0.ipa 15
```

Output on a Mac (Apple silicon), SampleShop 2.0 from this repository (a simulator build):

```text
Sample Shop: 21 files
  bytes:                   8.75 MB
  install size (estimate): 8.80 MB
  compressed in the .ipa:  2.72 MB
Largest items:
  catalog.json: 6.19 MB (70.8%)
  Assets.car: 1.58 MB (18.1%)
  SampleShop: 245.3 kB (2.8%)
  Frameworks/ShopCore.framework: 163.3 kB (1.9%)
  Frameworks/Analytics.framework: 130.0 kB (1.5%)
note: Simulator build (iphonesimulator): it has no App Store thinning or encryption, and its binaries are built for the simulator, so a device build of the same app differs in size.
note: 3 binaries contain more than one architecture. Sizes count every slice; a device keeps one, so after App Store thinning these binaries are smaller.
within the limit of 15.00 MB
```

With a limit of `5` it prints `over the limit: 8.80 MB > 5.00 MB` and exits with 1.

The package depends on sizeledger through a local path so it builds against this checkout. In
your own package use the URL:

```swift
.package(url: "https://github.com/muhittincamdali/sizeledger", from: "0.1.1"),
```

## GitHub Actions

Copy [github-actions/app-size.yml](github-actions/app-size.yml) to `.github/workflows/` in your
app's repository and replace the build step. It downloads the release binary, checks it against
the release's `SHA256SUMS`, and appends the report to the job summary. Comparing two builds and
size budgets are planned for sizeledger 0.2 and 0.3; the last step shows a limit check with `jq`
until then. The [Size checks in CI](../docs/guides/size-checks-in-ci.md) guide explains each step.
