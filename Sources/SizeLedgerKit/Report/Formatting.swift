/// Human-readable numbers for the text and Markdown reports.
///
/// Sizes use decimal units (1 MB = 1,000,000 bytes), the units Finder, App Store Connect and the
/// App Store use. Formatting is done with integers so the output is the same in every locale.
public enum ByteFormat {
    /// `512 B`, `12.3 kB`, `5.84 MB`, `1.23 GB`.
    public static func string(_ bytes: UInt64) -> String {
        // The limits sit where rounding would reach 1,000 of the smaller unit, so 999,999 bytes
        // is "1.00 MB", not "1000.0 kB".
        switch bytes {
        case ..<1_000: return "\(bytes) B"
        case ..<999_950: return decimal(bytes, unit: 1_000, places: 1) + " kB"
        case ..<999_995_000: return decimal(bytes, unit: 1_000_000, places: 2) + " MB"
        default: return decimal(bytes, unit: 1_000_000_000, places: 2) + " GB"
        }
    }

    /// `part` as a share of `whole` with one decimal place: `36.0%`.
    public static func share(_ part: UInt64, of whole: UInt64) -> String {
        guard whole > 0 else { return "0.0%" }
        let (scaled, overflow) = part.multipliedReportingOverflow(by: 1_000)
        let (rounded, overflowAgain) = scaled.addingReportingOverflow(whole / 2)
        // Only sizes near 2^64, from a crafted input, take the floating-point path.
        let tenths = overflow || overflowAgain
            ? UInt64(Swift.min((Double(part) * 1_000 / Double(whole)).rounded(), 1e15))
            : rounded / whole
        return "\(tenths / 10).\(tenths % 10)%"
    }

    /// `bytes / unit`, rounded half up to `places` decimal places.
    static func decimal(_ bytes: UInt64, unit: UInt64, places: Int) -> String {
        var scale: UInt64 = 1
        for _ in 0..<places { scale *= 10 }
        // Whole units and the remainder are scaled apart, so sizes up to UInt64.max cannot overflow.
        var whole = bytes / unit
        var tail = (bytes % unit * scale + unit / 2) / unit
        if tail == scale {
            whole += 1
            tail = 0
        }
        let fraction = String(tail)
        return "\(whole)." + String(repeating: "0", count: places - fraction.count) + fraction
    }
}

/// Makes text that comes from the measured app (file names, Info.plist values) safe to print.
enum Sanitize {
    /// Replaces control characters, including the escape character that starts terminal
    /// sequences, with U+FFFD, so a file name cannot move the output around or change colours.
    /// The bidirectional embeddings, overrides and isolates (U+202A to U+202E, U+2066 to U+2069)
    /// go too: an override can make `gpj.exe` display as `exe.jpg` and reorder the rest of a
    /// table row. The marks U+200E, U+200F and U+061C go as well: they are invisible and still
    /// move neutral characters such as `.` and `/` to the other side of a name. So do the
    /// invisible U+200B, U+2060 and U+FEFF, which make two names that look the same differ, and
    /// the line and paragraph separators U+2028 and U+2029, which some terminals break lines on.
    /// Letters of right-to-left scripts and the joiners U+200C and U+200D, which those scripts
    /// and emoji need, are kept.
    static func text(_ value: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x00...0x1F, 0x7F...0x9F, 0x202A...0x202E, 0x2066...0x2069: result.append("\u{FFFD}")
            case 0x061C, 0x200B, 0x200E, 0x200F, 0x2028, 0x2029, 0x2060, 0xFEFF: result.append("\u{FFFD}")
            default: result.append(scalar)
            }
        }
        return String(result)
    }

    /// Escapes DEL and the C1 controls in already-encoded JSON as `\u00XX`, so a control character
    /// in a file name cannot act on a terminal that prints the report while the JSON keeps the
    /// exact codepoint. `JSONEncoder` already escapes the C0 controls. These bytes only ever sit
    /// inside a JSON string, so the escape keeps the document valid.
    static func jsonEscapingControlCharacters(_ json: String) -> String {
        guard json.unicodeScalars.contains(where: { $0.value == 0x7F || (0x80...0x9F).contains($0.value) }) else {
            return json
        }
        var result = ""
        result.reserveCapacity(json.count)
        for scalar in json.unicodeScalars {
            if scalar.value == 0x7F || (0x80...0x9F).contains(scalar.value) {
                let hex = String(scalar.value, radix: 16)
                result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    /// Shortens a label to `width` characters. Paths lose their leading folders first
    /// (`…/ShopCore.framework/ShopCore`), since the end names the file; a single name that is
    /// still too long loses its middle. Leading spaces (indentation) are kept.
    static func shortened(_ value: String, width: Int) -> String {
        guard value.count > width else { return value }
        let indent = String(value.prefix { $0 == " " })
        let body = String(value.dropFirst(indent.count))
        let room = width - indent.count
        var parts = body.split(separator: "/", omittingEmptySubsequences: false)
        while parts.count > 1 {
            parts.removeFirst()
            let candidate = "…/" + parts.joined(separator: "/")
            if candidate.count <= room { return indent + candidate }
        }
        return indent + middleTruncated(String(parts.last ?? Substring(body)), width: room)
    }

    /// Shortens `value` to `width` characters by cutting out the middle.
    static func middleTruncated(_ value: String, width: Int) -> String {
        guard value.count > width, width > 1 else { return value }
        let head = (width - 1) / 2
        let tail = width - 1 - head
        return String(value.prefix(head)) + "…" + String(value.suffix(tail))
    }
}
