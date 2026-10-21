/// Paths inside a bundle, split and compared on their bytes.
///
/// `String` compares canonically equivalent text as equal and works in `Character`s (grapheme
/// clusters). A file system and an unzip tool do neither: NFC "café.bin" and NFD "café.bin" are
/// two files, and a "/" followed by a combining mark is still a separator, although the mark
/// joins the slash into one `Character`. So every decision about which files exist, which folder
/// they sit in and how deep they are is made on the bytes, never on `String` equality,
/// `split(separator:)`, `hasPrefix(_:)` or a `String`-keyed dictionary.
///
/// A name in a ZIP archive or on a Linux file system need not be UTF-8 at all. Such a name is
/// shown decoded as Latin-1 (see ``decode(_:)``), and that text can equal the UTF-8 spelling of
/// another name: `caf\xE9.bin` reads as "café.bin". Identity therefore comes from the bytes as
/// stored (``PathKey``), never from the decoded text.
enum BundlePath {
    static let separator = UInt8(ascii: "/")

    /// The text shown for a stored name: each `/`-separated component reads as UTF-8 when it is
    /// valid UTF-8 and as Latin-1 when it is not. Decoding component by component keeps every
    /// `/` where the bytes have it, so the decoded path has the same components as the stored
    /// one, and a valid component reads the same whatever its neighbours hold.
    static func decode(_ bytes: some Collection<UInt8>) -> String {
        bytes.split(separator: separator, omittingEmptySubsequences: false)
            .map(decodeComponent)
            .joined(separator: "/")
    }

    /// Whether `bytes` are valid UTF-8. Decoding repairs each invalid sequence with U+FFFD, so
    /// the bytes survive the round trip only when there was nothing to repair.
    static func isUTF8(_ bytes: some Collection<UInt8>) -> Bool {
        String(decoding: bytes, as: UTF8.self).utf8.elementsEqual(bytes)
    }

    private static func decodeComponent(_ bytes: some Collection<UInt8>) -> String {
        isUTF8(bytes) ? String(decoding: bytes, as: UTF8.self) : String(decoding: bytes.map { UInt16($0) }, as: UTF16.self)
    }

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
/// `String` keys, which merge NFC and NFD spellings of a name into one. A key made from stored
/// name bytes with ``init(bytes:)`` also keeps a name that is not UTF-8 apart from the UTF-8
/// name its Latin-1 reading spells.
struct PathKey: Hashable, Sendable {
    let bytes: [UInt8]

    init(_ path: some StringProtocol) {
        bytes = Array(path.utf8)
    }

    init(bytes: some Sequence<UInt8>) {
        self.bytes = Array(bytes)
    }

    /// The non-empty `/`-separated components of the stored path, in the order of
    /// ``BundlePath/components(of:)`` applied to its decoded text.
    var components: [ArraySlice<UInt8>] {
        bytes.split(separator: BundlePath.separator)
    }

    /// The key of the first `count` components joined by `/`.
    func leading(_ count: Int) -> PathKey {
        PathKey(bytes: Array(components.prefix(count).joined(separator: [BundlePath.separator])))
    }

    /// The key of the component at `index`.
    func component(at index: Int) -> PathKey {
        PathKey(bytes: components[index])
    }
}
