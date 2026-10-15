// Writes the resources of the SampleShop fixture app for one version: an asset catalog with an
// app icon and product images, a product catalog (catalog.json) and Localizable.strings for each
// language. Every value comes from a seeded generator, so running it again writes the same files.
//
//   swift Fixtures/scripts/make-sample-resources.swift <1.0|2.0> <output folder>
//
// macOS only (CoreGraphics and ImageIO draw the images).

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func below(_ bound: Int) -> Int { Int(next() % UInt64(bound)) }

    mutating func pick<T>(_ values: [T]) -> T { values[below(values.count)] }
}

struct Version {
    let name: String
    let products: Int
    let images: [String]
    let languages: [String]
    let strings: Int
    let banner: Bool
}

let versions: [String: Version] = [
    "1.0": Version(
        name: "1.0", products: 18_000,
        images: ["Kettle", "Lamp", "Chair", "Mug"],
        languages: ["en", "de", "tr", "ja"], strings: 400, banner: false
    ),
    "2.0": Version(
        name: "2.0", products: 22_000,
        images: ["Kettle", "Lamp", "Chair", "Mug", "Desk", "Plant", "Clock"],
        languages: ["en", "de", "tr", "ja", "fr", "es", "pt-BR"], strings: 520, banner: true
    ),
]

let arguments = CommandLine.arguments
guard arguments.count == 3, let version = versions[arguments[1]] else {
    FileHandle.standardError.write(Data("usage: make-sample-resources.swift <1.0|2.0> <output folder>\n".utf8))
    exit(64)
}
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
let manager = FileManager.default
try? manager.removeItem(at: output)
try manager.createDirectory(at: output, withIntermediateDirectories: true)

// MARK: Images

/// A product "photo": a soft two-colour gradient with a few circles. `grain` adds noise, which
/// compresses badly, the way real photos do.
func drawImage(size: Int, seed: UInt64, grain: Int) -> CGImage {
    var random = SplitMix64(state: seed)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    func color() -> CGColor {
        CGColor(
            srgbRed: CGFloat(random.below(256)) / 255, green: CGFloat(random.below(256)) / 255,
            blue: CGFloat(random.below(256)) / 255, alpha: 1
        )
    }
    let gradient = CGGradient(colorsSpace: space, colors: [color(), color()] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
    for _ in 0..<6 {
        context.setFillColor(color().copy(alpha: 0.55)!)
        let radius = CGFloat(size / 10 + random.below(size / 4))
        let center = CGPoint(x: CGFloat(random.below(size)), y: CGFloat(random.below(size)))
        context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
    if grain > 0, let pixels = context.data?.assumingMemoryBound(to: UInt8.self) {
        for index in 0..<(size * size * 4) where index % 4 != 3 {
            let noise = random.below(grain * 2 + 1) - grain
            pixels[index] = UInt8(clamping: Int(pixels[index]) + noise)
        }
    }
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

func writeJSON(_ object: Any, to url: URL) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url)
}

let catalog = output.appendingPathComponent("Assets.xcassets")
try manager.createDirectory(at: catalog, withIntermediateDirectories: true)
try writeJSON(["info": ["author": "xcode", "version": 1]], to: catalog.appendingPathComponent("Contents.json"))

let icon = catalog.appendingPathComponent("AppIcon.appiconset")
try manager.createDirectory(at: icon, withIntermediateDirectories: true)
try writePNG(drawImage(size: 1_024, seed: 7, grain: 0), to: icon.appendingPathComponent("AppIcon.png"))
try writeJSON([
    "images": [["filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"]],
    "info": ["author": "xcode", "version": 1],
], to: icon.appendingPathComponent("Contents.json"))

var imageSets = version.images.enumerated().map { ($0.element, UInt64(100 + $0.offset), 0, 256) }
if version.banner { imageSets.append(("Banner", 999, 8, 512)) }
for (name, seed, grain, size) in imageSets {
    let set = catalog.appendingPathComponent("\(name).imageset")
    try manager.createDirectory(at: set, withIntermediateDirectories: true)
    try writePNG(drawImage(size: size, seed: seed, grain: grain), to: set.appendingPathComponent("\(name).png"))
    try writeJSON([
        "images": [["filename": "\(name).png", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1],
    ], to: set.appendingPathComponent("Contents.json"))
}

// MARK: Catalog

let adjectives = ["Quiet", "Bright", "Compact", "Classic", "Nordic", "Urban", "Soft", "Solid", "Slim", "Warm", "Matte", "Glazed"]
let nouns = ["Kettle", "Lamp", "Chair", "Mug", "Desk", "Plant", "Clock", "Shelf", "Rug", "Vase", "Stool", "Tray"]
let words = """
    made from recycled oak and steel with a hand finished surface that keeps its colour for years \
    easy to clean fits small kitchens and large studios ships flat and assembles in minutes \
    designed in small batches tested for daily use with a two year warranty and free returns
    """.split(separator: " ").map(String.init)
var random = SplitMix64(state: version.name == "1.0" ? 1 : 2)
let products: [[String: Any]] = (0..<version.products).map { index in
    let noun = random.pick(nouns)
    let description = (0..<(14 + random.below(16))).map { _ in random.pick(words) }.joined(separator: " ")
    return [
        "id": index + 1,
        "name": "\(random.pick(adjectives)) \(noun)",
        "description": description.prefix(1).uppercased() + description.dropFirst() + ".",
        "priceCents": 990 + random.below(40_000),
        "image": version.images.contains(noun) ? noun : version.images[index % version.images.count],
        "stock": random.below(250),
    ]
}
try writeJSON(["version": version.name, "products": products], to: output.appendingPathComponent("catalog.json"))

// MARK: Strings

let greetings = [
    "en": "Shop", "de": "Laden", "tr": "Mağaza", "ja": "ショップ", "fr": "Boutique", "es": "Tienda", "pt-BR": "Loja",
]
for language in version.languages {
    let folder = output.appendingPathComponent("\(language).lproj")
    try manager.createDirectory(at: folder, withIntermediateDirectories: true)
    var strings: [String: String] = ["catalog.title": greetings[language] ?? "Shop"]
    var languageRandom = SplitMix64(state: UInt64(language.unicodeScalars.reduce(0) { $0 &* 31 &+ $1.value }))
    for key in 0..<version.strings {
        let sentence = (0..<(6 + languageRandom.below(10))).map { _ in languageRandom.pick(words) }.joined(separator: " ")
        strings["message.\(key)"] = "\(greetings[language] ?? "Shop"): \(sentence)"
    }
    let data = try PropertyListSerialization.data(fromPropertyList: strings, format: .binary, options: 0)
    try data.write(to: folder.appendingPathComponent("Localizable.strings"))
}

print("Wrote SampleShop \(version.name) resources to \(output.path)")
