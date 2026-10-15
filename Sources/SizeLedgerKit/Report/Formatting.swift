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
        let tenths = (part * 1_000 + whole / 2) / whole
        return "\(tenths / 10).\(tenths % 10)%"
    }

    /// `bytes / unit`, rounded half up to `places` decimal places.
    static func decimal(_ bytes: UInt64, unit: UInt64, places: Int) -> String {
        var scale: UInt64 = 1
        for _ in 0..<places { scale *= 10 }
        let scaled = (bytes * scale + unit / 2) / unit
        let whole = scaled / scale
        let fraction = String(scaled % scale)
        return "\(whole)." + String(repeating: "0", count: places - fraction.count) + fraction
    }
}

/// Makes text that comes from the measured app (file names, Info.plist values) safe to print.
enum Sanitize {
    /// Replaces control characters, including the escape character that starts terminal
    /// sequences, with U+FFFD, so a file name cannot move the output around or change colours.
    static func text(_ value: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x00...0x1F, 0x7F...0x9F: result.append("\u{FFFD}")
            default: result.append(scalar)
            }
        }
        return String(result)
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
