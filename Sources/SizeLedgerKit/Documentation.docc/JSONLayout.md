# The JSON layout

What `sizeledger analyze --out` and ``SizeReport/jsonData()`` write, field by field.

## Overview

The output is one JSON object with sorted keys. Sizes are integers in bytes. Fields that do not
apply are left out, never written as `null`: `compressedBytes` and `archiveBytes` only appear for
`.ipa` input, `category` only on files in the tree and `children` only on folders.

`schemaVersion` is `0` while the layout may still change. Version 1.0 of sizeledger will freeze
it as `1`; a file with a higher version than the reader knows is refused with
``ReportError/newerSchema(_:)``.

| Key             | Contents                                                                                                                                            |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `schemaVersion` | Layout version, `0` for now                                                                                                                         |
| `tool`          | `name` and `version` of the sizeledger that wrote it                                                                                                |
| `input`         | `name` (file name only), `kind` (`app`, `ipa`, `xcarchive`), `bundle` (the `.app` measured) and `archiveBytes` (the `.ipa` file's size)             |
| `app`           | From Info.plist: `name`, `bundleIdentifier`, `version`, `build`, `executable`, `minimumOSVersion`, `platform` (`DTPlatformName`) and `isAppClip`    |
| `totals`        | `files`, `bytes`, `installBytes`, `compressedBytes`                                                                                                 |
| `categories`    | One entry per non-empty ``SizeCategory``, largest first, with the same four numbers                                                                   |
| `components`    | Top-level items, with `Frameworks/`, `PlugIns/`, `Extensions/`, `AppClips/` and `Watch/` split one level deeper: `path`, `category` and the numbers |
| `languages`     | `.lproj` folders anywhere in the bundle, grouped by `language`                                                                                      |
| `binaries`      | Every Mach-O file: `path`, `bytes` and `slices` (``MachOSlice``)                                                                                      |
| `outsideBundle` | `.ipa` files outside `Payload/<name>.app`, such as `SwiftSupport/`; not in the totals                                                               |
| `notes`         | Sentences that change how to read the numbers                                                                                                       |
| `tree`          | The bundle as ``SizeNode`` values: `name`, `files`, the sizes, and `category` or `children`                                                           |

Categories, components and the tree each add up to `totals`; languages do not, because files
outside `.lproj` folders have no language.

## Example

Part of the output for the SampleShop 2.0 fixture (`Fixtures/snapshots/SampleShop-2.0.json` in
the repository has all of it):

```json
{
    "input": {
        "archiveBytes": 2723152,
        "bundle": "SampleShop.app",
        "kind": "ipa",
        "name": "SampleShop-2.0.ipa"
    },
    "schemaVersion": 0,
    "totals": {
        "bytes": 8747129,
        "compressedBytes": 2717180,
        "files": 21,
        "installBytes": 8802304
    }
}
```

## Reading it with jq

```sh
jq '.totals.installBytes' size/main.json
jq -r '.components[] | "\(.bytes)\t\(.path)"' size/main.json | head
jq -r '.binaries[] | .path + ": " + ([.slices[].architecture] | join(", "))' size/main.json
```

Names come from the app and can hold any character. The file escapes control characters and
bidirectional overrides as `\u` sequences (`\u202e`), so printing it with `cat` is safe, but
`jq -r` decodes them back into raw characters. To print names from an app you do not trust, leave
out `-r` or pass the output through `cat -v`.
