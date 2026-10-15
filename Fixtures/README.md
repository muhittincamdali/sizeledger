# Fixtures

Test data for sizeledger. Everything here is made by the scripts in [scripts/](scripts); nothing
comes from a real product.

| Path                                               | What it is                                                                                                                  | Made by                                                              |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| [apps/SampleShop-1.0.ipa](apps/SampleShop-1.0.ipa) | SampleShop 1.0: a SwiftUI app with one framework (ShopCore), four languages, an asset catalog and a product catalog in JSON | [scripts/build-sample-app.sh](scripts/build-sample-app.sh) `1.0`     |
| [apps/SampleShop-2.0.ipa](apps/SampleShop-2.0.ipa) | SampleShop 2.0: adds a second framework (Analytics), three languages, a banner image, more products and a product screen    | [scripts/build-sample-app.sh](scripts/build-sample-app.sh) `2.0`     |
| [SampleShop/](SampleShop)                          | The app's Swift sources                                                                                                     |                                                                      |
| [snapshots/](snapshots)                            | The JSON, text and Markdown reports for both versions; the tests compare against them                                       | `SIZELEDGER_UPDATE_SNAPSHOTS=1 swift test`                           |
| [archives/](archives)                              | DEFLATE streams from zlib (stored, fixed and dynamic blocks) and a small ZIP with every entry kind an `.ipa` has            | [scripts/make-archive-fixtures.py](scripts/make-archive-fixtures.py) |
| [markdown/escaping.json](markdown/escaping.json) | Values that tried to break the Markdown report, how sizeledger escapes each and the table row GitHub rendered from it | `SIZELEDGER_UPDATE_SNAPSHOTS=1 swift test`, then [scripts/render-markdown-fixture.py](scripts/render-markdown-fixture.py) |

## SampleShop

Both versions are built for the iOS Simulator with `swiftc`, `actool`, `lipo` and `codesign`
from Xcode, without an Xcode project, so every step is in the script. Binaries hold both
simulator architectures (arm64 and x86_64). They are ad-hoc signed, which is enough to install
and run them in a simulator:

```sh
Fixtures/scripts/build-sample-app.sh 2.0
xcrun simctl install booted Fixtures/.build/2.0/stage/Payload/SampleShop.app
xcrun simctl launch booted com.example.sampleshop
```

A simulator build has no App Store thinning or encryption, so its sizes are not what a device
downloads; sizeledger's report says so in its notes.

Images and data come from seeded generators, so a rebuild writes files of the same size. Only the
`.ipa` files are committed; the tests unpack them with sizeledger's own ZIP reader. Rebuilding
needs macOS with Xcode; the tests do not, and run the same on Linux.

The tests check that sizeledger's totals agree with `du` on the unpacked app within 1%:
`installBytes` against `du -sk`, `bytes` against `du -A` (macOS) or `du -b --apparent-size`
(Linux). `du` also counts folders, which take a 4 KiB block each on ext4 and none on APFS.
