# Why the install size is an estimate

sizeledger reports three sizes and calls one of them an estimate. This guide says what each one
measures and why no tool that only has your files can give the App Store's numbers.

## What sizeledger measures

| Size                                         | How it is computed                                                                             | Agrees with                                        |
| -------------------------------------------- | ---------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| Total (`bytes`)                              | The sizes of all files in the bundle added up; a symbolic link counts the length of its target | `du -A` on macOS, `du -b --apparent-size` on Linux |
| Install size, estimate (`installBytes`)      | Each file rounded up to whole 4 KiB blocks; empty files and links count as zero                | `du -sk` on APFS                                   |
| Compressed in the `.ipa` (`compressedBytes`) | The compressed sizes from the `.ipa`'s ZIP directory, for the files in the app bundle          | `unzip -v`                                         |

On the two SampleShop fixtures, unpacked from their `.ipa` files, the install estimate equals
`du -sk` exactly on a Mac (Apple silicon, APFS), and is within 0.65% in a Linux container, where
`du` also counts a 4 KiB block for each folder. The total is within 0.16% of `du -A` on the Mac
(which rounds each entry to 512 bytes) and equal to `du -b --apparent-size` on Linux. The tests
check both on every run and fail above 1%.

## Why the App Store's numbers differ

The app a device installs is not the file you upload:

1. **App thinning.** The App Store builds one variant per device model: one architecture slice of
   every binary, only the asset catalog images for that device's scale and idiom, and only the
   on-demand resources it needs. A universal binary and a full asset catalog in your upload are
   counted in full by sizeledger.
2. **Encryption.** App Store binaries are encrypted (FairPlay), which changes how well they
   compress.
3. **Compression.** The download is compressed by the App Store. How much it shrinks depends on
   the content: text and binaries shrink a lot, PNG and asset catalogs little.

So the download size is smaller than the install size, and both are usually smaller than a
universal, unthinned upload.

## Where Apple's numbers come from

- **Xcode**: archive the app, open the Organizer, choose **Distribute App**, export with **App
  Thinning** set to all compatible device variants. The export folder has `App Thinning Size
Report.txt` with the compressed and uncompressed size of every variant.
- **App Store Connect**: after upload, the build's details list download and install sizes per
  device.

Both need Apple's build pipeline and a signed build. sizeledger works from the files alone, on
any machine, including Linux CI runners, for every build.

## How to use the numbers

- **Track change, not the absolute value.** The same app measured the same way from build to
  build shows what grew, even though the numbers are not Apple's.
- **Measure what you ship.** An `.ipa` exported for distribution is closer to what users get than
  a debug or simulator build.
- **Read the notes.** sizeledger says when the input is a simulator build or has universal
  binaries, the two most common reasons its numbers differ from a device.

The DocC article [Why the install size is an estimate](https://muhittincamdali.github.io/sizeledger/documentation/sizeledgerkit/installsizeestimate)
says the same for library users.
