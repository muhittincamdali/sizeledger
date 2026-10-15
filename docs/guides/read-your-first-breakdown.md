# Read your first breakdown

This guide runs sizeledger on SampleShop 2.0, the sample app in this repository, and explains
each part of the output. Your app's numbers will differ; the parts are the same.

```sh
git clone https://github.com/muhittincamdali/sizeledger.git
cd sizeledger
swift build -c release
.build/release/sizeledger analyze Fixtures/apps/SampleShop-2.0.ipa
```

The output below is from a Mac (Apple silicon); the Linux build prints the same.

## 1. Which app, which build

```text
Sample Shop 2.0 (2)
com.example.sampleshop · iphonesimulator · minimum OS 17.0
SampleShop-2.0.ipa → SampleShop.app
```

Name, version and build number, bundle identifier, the SDK it was built with (`DTPlatformName`)
and the minimum OS come from the app's Info.plist. `iphonesimulator` matters: a simulator build
is never thinned by the App Store, so its numbers differ from a device build. The last line is
the file you passed and the app bundle inside it.

## 2. Three totals

```text
Total                                8.75 MB   21 files
Install size (estimate)              8.80 MB   files rounded up to 4 KiB blocks
Compressed in the .ipa               2.72 MB   bundle files only; the .ipa file is 2.72 MB
```

- **Total** adds up the files: 8.75 MB in 21 files.
- **Install size (estimate)** rounds every file up to whole 4 KiB blocks, the way APFS stores it.
  Many small files make this number grow faster than the total.
- **Compressed in the .ipa** is what the files take inside the archive. `catalog.json` is text and
  shrinks from 6.19 MB to under 1 MB; `Assets.car` is already compressed and barely shrinks.

Units are decimal (1 MB = 1,000,000 bytes), like App Store Connect. None of the three is the App
Store's number; [Why the install size is an estimate](why-install-size-is-an-estimate.md) says
why.

## 3. By category

```text
By category                             Size   Share  Files
  Other resources                    6.22 MB   71.2%      5
  Asset catalogs                     1.58 MB   18.1%      1
  Localizations                     396.4 kB    4.5%      7
  Frameworks                        293.3 kB    3.4%      6
  Main executable                   245.3 kB    2.8%      1
  Code signature                      6.9 kB    0.1%      1
```

Every file is in exactly one category, so the shares add up to the whole app. The category comes
from the top-level folder first: an asset catalog inside a framework counts as part of that
framework. The categories are main executable, frameworks (everything under `Frameworks/`), app
extensions (`PlugIns/`, `Extensions/`), App Clips (`AppClips/`), watch app (`Watch/`),
localizations (top-level `.lproj` folders), asset catalogs (top-level `.car` files), code
signature (`_CodeSignature/`, `embedded.mobileprovision`, `SC_Info/`) and other resources.

Here "Other resources" is 71%: one data file dominates the app.

## 4. Largest items

```text
Largest items                           Size   Share  Files
  catalog.json                       6.19 MB   70.8%      1
  Assets.car                         1.58 MB   18.1%      1
  SampleShop                        245.3 kB    2.8%      1
  Frameworks/ShopCore.framework     163.3 kB    1.9%      3
  Frameworks/Analytics.framework    130.0 kB    1.5%      3
  tr.lproj                           83.1 kB    0.9%      1
  …
```

The top-level files and folders of the bundle, with `Frameworks/`, `PlugIns/` and the other
containers split one level deeper so each framework and extension has its own line. This is
usually where to start: the first two lines here are 89% of the app. `--top 30` lists more; the
JSON report (`--out`) has all of them and the full file tree.

## 5. Languages

```text
Languages (7 .lproj languages)          Size   Share  Files
  tr                                 83.1 kB    0.9%      1
  ja                                 82.0 kB    0.9%      1
  …
```

Every `.lproj` folder in the bundle, including those inside frameworks and resource bundles,
grouped by language. A language you no longer support, or a framework that ships 40 languages
your app does not, shows up here.

## 6. Binaries

```text
Binaries                                Size   Architectures
  SampleShop                        245.3 kB   x86_64 97.7 kB, arm64 130.7 kB
  …/ShopCore.framework/ShopCore     161.1 kB   x86_64 54.7 kB, arm64 79.2 kB
  …/Analytics.framework/Analytics   127.9 kB   x86_64 33.6 kB, arm64 62.4 kB
```

Every Mach-O file and its architecture slices. A simulator build on Apple silicon often carries
an x86_64 slice next to arm64; a device build normally has arm64 only. A device keeps one slice
after App Store thinning, so a universal binary in an `.ipa` costs less on the device than it
does here. The JSON report adds segment sizes, the code signature and the Swift metadata
sections of each slice.

## 7. Notes

```text
Notes
  - Simulator build (iphonesimulator): it has no App Store thinning or
    encryption, and its binaries are built for the simulator, so a device build
    of the same app differs in size.
  - 3 binaries contain more than one architecture. …
```

Notes appear when a number needs context: a simulator build, universal binaries, files in the
`.ipa` outside the app bundle (such as `SwiftSupport/`), an App Clip, a missing Info.plist or a
binary whose headers could not be read. Keep them next to the numbers when you share a report.

## Next

- Save the report: `sizeledger analyze MyApp.ipa --out size/main.json`.
- Put it in a pull request: [Size checks in CI](size-checks-in-ci.md).
- Measure an App Clip: [App Clip size limits](app-clip-size.md).
