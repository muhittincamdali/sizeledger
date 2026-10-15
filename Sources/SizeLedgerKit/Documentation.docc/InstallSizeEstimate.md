# Why the install size is an estimate

What `installBytes` measures, and why no local tool can give the App Store's numbers.

## Overview

`installBytes` adds up every file in the bundle rounded up to whole 4 KiB blocks, the block size
of APFS on iOS devices. Empty files and symbolic links count as zero. On the SampleShop fixtures
it agrees with `du -sk` on the unpacked app within 1% on macOS (APFS) and Linux (ext4); the
tests check this on every run.

The App Store shows other numbers, because the app a device downloads is not the app you
uploaded:

- **App thinning.** The App Store builds a variant per device: one architecture slice of each
  binary, the asset catalog renditions for that device's scale and idiom, and only the resources
  the device needs. A universal binary in your upload counts every slice in sizeledger.
- **Encryption.** App Store binaries are encrypted, which changes how well they compress.
- **Compression.** The download is compressed by Apple, so the download size is smaller than the
  install size, by an amount that depends on the content.

That is why sizeledger keeps three numbers apart instead of producing one "App Store size":
`bytes` (what is in the bundle), `installBytes` (what those files take on an APFS volume) and,
for an `.ipa`, `compressedBytes` (what they take in the archive). Watching how these change from
build to build shows growth reliably, even though none of them is Apple's figure.

## Getting Apple's numbers

Xcode can produce per-device sizes: archive the app, choose **Distribute App**, export with
**App Thinning** set to all compatible device variants, and read `App Thinning Size Report.txt`
in the export folder. After upload, App Store Connect lists download and install sizes per device
for each build. Both need an Apple build pipeline; sizeledger works from the files alone, on any
machine.

## Simulator builds

A simulator build is never thinned or encrypted, and its binaries target the simulator (on
Apple silicon, often with an x86_64 slice as well), so its sizes differ from a device build of the
same app. sizeledger says so in the report's notes when `DTPlatformName` ends in `simulator`.
