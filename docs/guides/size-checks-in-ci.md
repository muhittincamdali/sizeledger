# Size checks in CI

How to measure the app on every pull request with sizeledger 0.1: show the breakdown in the job
summary, keep the JSON report, and fail on a limit.

The `diff` command (compare two reports, planned for 0.2) and `budget` rules with a GitHub
Action (planned for 0.3) will make this shorter. Everything below works today.

## 1. Build what you want to measure

sizeledger takes an `.app`, an `.xcarchive` or an `.ipa`, so use the output your pipeline
already makes. An archive is enough:

```sh
xcodebuild archive -scheme MyApp -destination 'generic/platform=iOS' \
  -archivePath build/MyApp.xcarchive CODE_SIGNING_ALLOWED=NO
```

An `.ipa` exported for distribution is closer to what users install. A simulator build works,
but the report notes that its numbers differ from a device build.

## 2. Install sizeledger

On a macOS runner, the release binary needs no toolchain:

```sh
version=0.1.1
base="https://github.com/muhittincamdali/sizeledger/releases/download/v$version"
curl -fsSLO "$base/sizeledger-$version-macos-universal.tar.gz"
curl -fsSLO "$base/SHA256SUMS"
grep macos-universal SHA256SUMS | shasum -a 256 -c -
mkdir -p "$RUNNER_TEMP/bin"
tar -xzf "sizeledger-$version-macos-universal.tar.gz" -C "$RUNNER_TEMP/bin" sizeledger
echo "$RUNNER_TEMP/bin" >> "$GITHUB_PATH"
```

On a Linux runner use `sizeledger-$version-linux-x86_64.tar.gz` (or `-linux-aarch64`) and
`sha256sum -c`. sizeledger only reads files, so the build can run on macOS and the measurement on
Linux: pass the `.ipa` between jobs as an artifact.

## 3. Measure and report

```sh
sizeledger analyze build/MyApp.xcarchive --out size/app.json --format markdown >> "$GITHUB_STEP_SUMMARY"
```

One run writes both: the Markdown tables go to the job summary, the JSON report to
`size/app.json`. Upload the JSON as an artifact to keep a history; the key order is fixed, so
two reports can be compared with `diff` or `jq` until the `diff` command exists.

## 4. Fail on a limit

```sh
limit=80000000   # 80 MB, decimal, like App Store Connect
install_bytes="$(jq '.totals.installBytes' size/app.json)"
if [ "$install_bytes" -gt "$limit" ]; then
  echo "::error::Install size estimate $install_bytes bytes is over $limit"
  exit 1
fi
```

A limit for one part of the app works the same way, for example all frameworks:

```sh
jq '[.categories[] | select(.category == "frameworks") | .bytes] | add // 0' size/app.json
```

or the growth of one framework against a report from `main` that you kept as an artifact:

```sh
before="$(jq '[.components[] | select(.path == "Frameworks/Kit.framework") | .bytes] | add // 0' size/main.json)"
after="$(jq '[.components[] | select(.path == "Frameworks/Kit.framework") | .bytes] | add // 0' size/app.json)"
echo "Kit.framework grew by $((after - before)) bytes"
```

## The whole workflow

[Examples/github-actions/app-size.yml](../../Examples/github-actions/app-size.yml) puts these steps
together for a pull request workflow on `macos-26`. Exit status `2` from sizeledger means the
input could not be read (the message says why), so a broken build path fails the job instead of
passing with an empty report.
