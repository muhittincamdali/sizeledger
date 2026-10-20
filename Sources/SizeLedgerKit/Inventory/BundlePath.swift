/// Paths inside a bundle, split and compared on their UTF-8 bytes.
///
/// `String` compares canonically equivalent text as equal and works in `Character`s (grapheme
/// clusters). A file system and an unzip tool do neither: NFC "café.bin" and NFD "café.bin" are
/// two files, and a "/" followed by a combining mark is still a separator, although the mark
/// joins the slash into one `Character`. So every decision about which files exist, which folder
/// they sit in and how deep they are is made on the bytes, never on `String` equality,
/// `split(separator:)`, `hasPrefix(_:)` or a `String`-keyed dictionary.
enum BundlePath {
    static let separator = UInt8(ascii: "/")

    /// The non-empty `/`-separated components of `path`. Splitting on an ASCII byte never cuts
    /// a multi-byte sequence, so each component decodes back to exactly its bytes.
    static func components(of path: String) -> [String] {
        path.utf8.split(separator: separator).map { String(decoding: $0, as: UTF8.self) }
    }

    /// Whether `lhs` and `rhs` have the same bytes.
    static func same(_ lhs: some StringProtocol, _ rhs: some StringProtocol) -> Bool {
        lhs.utf8.elementsEqual(rhs.utf8)
    }

    static func hasPrefix(_ value: some StringProtocol, _ prefix: some StringProtocol) -> Bool {
        value.utf8.starts(with: prefix.utf8)
    }

    static func hasSuffix(_ value: some StringProtocol, _ suffix: some StringProtocol) -> Bool {
        value.utf8.reversed().starts(with: suffix.utf8.reversed())
    }

    /// `value` without its first `prefix.utf8.count` bytes. Callers check ``hasPrefix(_:_:)``
    /// first, and their prefixes end in ASCII, so the cut falls between characters.
    static func dropping(_ prefix: some StringProtocol, from value: some StringProtocol) -> String {
        String(decoding: value.utf8.dropFirst(prefix.utf8.count), as: UTF8.self)
    }

    /// `value` without its last `suffix.utf8.count` bytes, under the same rule as
    /// ``dropping(_:from:)``.
    static func droppingSuffix(_ suffix: some StringProtocol, from value: some StringProtocol) -> String {
        String(decoding: value.utf8.dropLast(suffix.utf8.count), as: UTF8.self)
    }
}

/// A path as a dictionary or set key: two keys are equal only when their bytes are, unlike
/// `String` keys, which merge NFC and NFD spellings of a name into one.
struct PathKey: Hashable {
    let bytes: [UInt8]

    init(_ path: some StringProtocol) {
        bytes = Array(path.utf8)
    }
}
