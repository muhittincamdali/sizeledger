# App Clip size limits

App Clips have a hard size limit. This guide gives Apple's limits, shows how to measure an App
Clip with sizeledger, and says where sizeledger's numbers stop and Apple's start.

## Apple's limits

From Apple's
[Choosing the right functionality for your App Clip](https://developer.apple.com/documentation/appclip/choosing-the-right-functionality-for-your-app-clip)
(read on 15 October 2026), for the uncompressed App Clip binary:

| iOS version        | Maximum size of the uncompressed App Clip                                                                                                                                                                                                                            |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| iOS 15 and earlier | 10 MB                                                                                                                                                                                                                                                                |
| iOS 16 and earlier | 15 MB                                                                                                                                                                                                                                                                |
| iOS 17 and later   | 100 MB, if the App Clip only supports digital invocations (such as your website or Spotlight), supports no physical invocations (App Clip Codes, QR codes, NFC tags), is used where a reliable internet connection is likely, and does not support iOS 16 or earlier |

Apple measures the thinned variants: in
[Creating an App Clip with Xcode](https://developer.apple.com/documentation/appclip/creating-an-app-clip-with-xcode)
it asks you to export the App Clip with App Thinning and read the uncompressed size of each
variant in `App Thinning Size Report.txt`. An App Clip that supports iOS 16 therefore has to stay
under 15 MB in every variant.

## Measure the App Clip with sizeledger

An App Clip ships inside its full app, at `AppClips/<name>.app`. sizeledger shows it as one line
in the "App Clips" category when you measure the full app:

```sh
sizeledger analyze build/MyApp.xcarchive
```

To see what is inside the App Clip, measure its bundle directly. From an archive:

```sh
sizeledger analyze build/MyApp.xcarchive/Products/Applications/MyApp.app/AppClips/MyClip.app
```

From an `.ipa`, unpack it first:

```sh
unzip -q MyApp.ipa -d unpacked
sizeledger analyze unpacked/Payload/MyApp.app/AppClips/MyClip.app
```

When the bundle's Info.plist has an `NSAppClip` dictionary, sizeledger shows "App Clip" in the
header and adds a note that App Store Connect checks the thinned, uncompressed size.

## Which number to compare

- **Install size (estimate)** is the closest local number to "uncompressed size": it counts every
  file, rounded up to disk blocks.
- It is **higher** than Apple's per-variant size when your build has universal binaries or an
  asset catalog with images for several scales, because thinning removes those. Measure a device
  build (arm64 only) exported for distribution to come close.
- It does **not** know which invocations your App Clip supports; pick the limit from the table
  yourself.

If the estimate is under the limit with room to spare, you are fine. If it is close, check with
the App Thinning Size Report before you rely on it.

## Keep it under the limit in CI

`budget` with an `appClip` rule is planned for sizeledger 0.5. Until then, a step like this fails
the build when the App Clip's install estimate passes 15 MB:

```sh
sizeledger analyze "$APP_CLIP" --out size/clip.json --quiet
install_bytes="$(jq '.totals.installBytes' size/clip.json)"
if [ "$install_bytes" -gt 15000000 ]; then
  echo "App Clip install size estimate is $install_bytes bytes, over 15 MB"
  exit 1
fi
```

[Size checks in CI](size-checks-in-ci.md) shows the whole workflow.

## Where the space usually goes

Run `sizeledger analyze` on the App Clip bundle and look at "Largest items" and "Binaries":

- Frameworks the App Clip links but barely uses, often analytics or networking SDKs shared with
  the full app.
- Asset catalog images that only the full app needs; give the App Clip its own catalog.
- Languages: frameworks can ship many `.lproj` folders; "Languages" lists them across the whole
  bundle.
