/// The report as terminal text: the app, its totals, then categories, the largest items,
/// languages and binaries, and the notes.
public enum TextReport {
    public struct Options: Sendable {
        /// How many of the largest items to list.
        public var top: Int
        /// Use ANSI bold and colour.
        public var color: Bool

        public init(top: Int = 10, color: Bool = false) {
            self.top = top
            self.color = color
        }
    }

    static let width = 80
    static let labelWidth = 34
    static let sizeWidth = 10

    public static func render(_ report: SizeReport, options: Options = Options()) -> String {
        var out = Writer(color: options.color)
        header(report, &out)
        totals(report, &out)
        categories(report, &out)
        components(report, top: options.top, &out)
        languages(report, top: options.top, &out)
        binaries(report, top: options.top, &out)
        notes(report, &out)
        return out.text
    }

    // MARK: Sections

    private static func header(_ report: SizeReport, _ out: inout Writer) {
        let app = report.app
        var title = Sanitize.text(app.name ?? report.input.bundle)
        if let version = app.version { title += " " + Sanitize.text(version) }
        if let build = app.build { title += " (\(Sanitize.text(build)))" }
        out.line(out.bold(title))
        let details = [
            app.bundleIdentifier.map(Sanitize.text),
            app.platform.map(Sanitize.text),
            app.minimumOSVersion.map { "minimum OS " + Sanitize.text($0) },
            app.isAppClip ? "App Clip" : nil,
        ].compactMap { $0 }
        if !details.isEmpty { out.line(details.joined(separator: " · ")) }
        let input = Sanitize.text(report.input.name)
        let bundle = Sanitize.text(report.input.bundle)
        out.line(input == bundle ? input : "\(input) → \(bundle)")
        out.blank()
    }

    private static func totals(_ report: SizeReport, _ out: inout Writer) {
        let totals = report.totals
        let files = totals.files == 1 ? "1 file" : "\(totals.files) files"
        out.line(row("Total", totals.bytes, files))
        out.line(row("Install size (estimate)", totals.installBytes, out.dim("files rounded up to 4 KiB blocks")))
        if let compressed = totals.compressedBytes {
            let archive = report.input.archiveBytes.map { "; the .ipa file is \(ByteFormat.string($0))" } ?? ""
            out.line(row("Compressed in the .ipa", compressed, out.dim("bundle files only" + archive)))
        }
    }

    private static func categories(_ report: SizeReport, _ out: inout Writer) {
        section("By category", columns: ["Share", "Files"], &out)
        for category in report.categories {
            out.line(row("  " + category.category.title, category.bytes, share(category.bytes, report), String(category.files)))
        }
    }

    private static func components(_ report: SizeReport, top: Int, _ out: inout Writer) {
        section("Largest items", columns: ["Share", "Files"], &out)
        for component in report.components.prefix(top) {
            out.line(row("  " + Sanitize.text(component.path), component.bytes, share(component.bytes, report), String(component.files)))
        }
        more(report.components.count - top, &out)
    }

    private static func languages(_ report: SizeReport, top: Int, _ out: inout Writer) {
        guard !report.languages.isEmpty else { return }
        let count = report.languages.count
        section("Languages (\(count) .lproj \(count == 1 ? "language" : "languages"))", columns: ["Share", "Files"], &out)
        for language in report.languages.prefix(top) {
            out.line(row("  " + Sanitize.text(language.language), language.bytes, share(language.bytes, report), String(language.files)))
        }
        more(count - top, &out)
    }

    private static func binaries(_ report: SizeReport, top: Int, _ out: inout Writer) {
        guard !report.binaries.isEmpty else { return }
        section("Binaries", columns: ["Architectures"], &out)
        for binary in report.binaries.prefix(top) {
            let slices = binary.slices
                .map { "\($0.architecture) \(ByteFormat.string($0.bytes))" }
                .joined(separator: ", ")
            out.line(row("  " + Sanitize.text(binary.path), binary.bytes, slices))
        }
        more(report.binaries.count - top, &out)
    }

    private static func notes(_ report: SizeReport, _ out: inout Writer) {
        guard !report.notes.isEmpty else { return }
        out.blank()
        out.line(out.heading("Notes"))
        for note in report.notes {
            for (index, line) in wrap(Sanitize.text(note), width: width - 4).enumerated() {
                out.line((index == 0 ? "  - " : "    ") + line)
            }
        }
    }

    // MARK: Layout

    private static func section(_ title: String, columns: [String], _ out: inout Writer) {
        out.blank()
        var line = title.rightPadded(labelWidth) + "Size".leftPadded(sizeWidth)
        if columns == ["Share", "Files"] {
            line += "Share".leftPadded(8) + "Files".leftPadded(7)
        } else {
            line += "   " + columns.joined(separator: " ")
        }
        out.line(out.heading(line))
    }

    private static func row(_ label: String, _ bytes: UInt64, _ rest: String...) -> String {
        let name = Sanitize.shortened(label, width: labelWidth - 1)
        var line = name.rightPadded(labelWidth) + ByteFormat.string(bytes).leftPadded(sizeWidth)
        if rest.count == 2 {
            line += rest[0].leftPadded(8) + rest[1].leftPadded(7)
        } else if let text = rest.first {
            line += "   " + text
        }
        return line
    }

    private static func share(_ bytes: UInt64, _ report: SizeReport) -> String {
        ByteFormat.share(bytes, of: report.totals.bytes)
    }

    private static func more(_ hidden: Int, _ out: inout Writer) {
        guard hidden > 0 else { return }
        out.line(out.dim("  … and \(hidden) more (--top shows more)"))
    }

    static func wrap(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if !current.isEmpty, current.count + 1 + word.count > width {
                lines.append(current)
                current = ""
            }
            current += current.isEmpty ? String(word) : " " + word
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}

/// Collects lines and applies ANSI styles when colour is on.
private struct Writer {
    let color: Bool
    var text = ""

    mutating func line(_ value: String) {
        text += value + "\n"
    }

    mutating func blank() {
        text += "\n"
    }

    func bold(_ value: String) -> String {
        style(value, "1")
    }

    func heading(_ value: String) -> String {
        style(value, "1;34")
    }

    func dim(_ value: String) -> String {
        style(value, "2")
    }

    private func style(_ value: String, _ code: String) -> String {
        color ? "\u{1B}[\(code)m\(value)\u{1B}[0m" : value
    }
}

extension String {
    func leftPadded(_ width: Int) -> String {
        count >= width ? self : String(repeating: " ", count: width - count) + self
    }

    func rightPadded(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
