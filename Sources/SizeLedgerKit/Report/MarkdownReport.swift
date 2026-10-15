/// The report as GitHub-flavoured Markdown, for a pull request comment or a job summary
/// (`>> $GITHUB_STEP_SUMMARY`).
public enum MarkdownReport {
    /// What to include.
    public struct Options: Sendable {
        /// How many of the largest items to list.
        public var top: Int

        /// Options with the given list length.
        public init(top: Int = 10) {
            self.top = top
        }
    }

    /// The report as Markdown, ending with a newline.
    public static func render(_ report: SizeReport, options: Options = Options()) -> String {
        var lines: [String] = []
        let app = report.app
        var title = app.name ?? report.input.bundle
        if let version = app.version { title += " " + version }
        if let build = app.build { title += " (\(build))" }
        lines.append("### \(text(title)): app size")
        lines.append("")
        var details = [report.input.name == report.input.bundle ? code(report.input.name) : "\(code(report.input.name)) → \(code(report.input.bundle))"]
        details += [app.bundleIdentifier, app.platform, app.minimumOSVersion.map { "minimum OS \($0)" }].compactMap { $0.map(text) }
        if app.isAppClip { details.append("App Clip") }
        lines.append(details.joined(separator: " · "))
        lines.append("")

        let totals = report.totals
        lines.append("| | Size |")
        lines.append("| --- | ---: |")
        lines.append("| **Total** (\(totals.files) \(totals.files == 1 ? "file" : "files")) | **\(ByteFormat.string(totals.bytes))** |")
        lines.append("| Install size (estimate) | \(ByteFormat.string(totals.installBytes)) |")
        if let compressed = totals.compressedBytes {
            lines.append("| Compressed in the .ipa | \(ByteFormat.string(compressed)) |")
        }
        if let archive = report.input.archiveBytes {
            lines.append("| .ipa file | \(ByteFormat.string(archive)) |")
        }

        table(&lines, title: "By category", header: "Category", rows: report.categories.map {
            (text($0.category.title), $0.bytes, $0.files)
        }, total: totals.bytes, hidden: 0)
        table(&lines, title: "Largest items", header: "Item", rows: report.components.prefix(options.top).map {
            (code($0.path), $0.bytes, $0.files)
        }, total: totals.bytes, hidden: report.components.count - options.top)
        if !report.languages.isEmpty {
            table(&lines, title: "Languages", header: "Language", rows: report.languages.prefix(options.top).map {
                (code($0.language), $0.bytes, $0.files)
            }, total: totals.bytes, hidden: report.languages.count - options.top)
        }
        if !report.binaries.isEmpty {
            lines += ["", "#### Binaries", "", "| Binary | Size | Architectures |", "| --- | ---: | --- |"]
            for binary in report.binaries.prefix(options.top) {
                let slices = binary.slices.map { "\($0.architecture) \(ByteFormat.string($0.bytes))" }.joined(separator: ", ")
                lines.append("| \(code(binary.path)) | \(ByteFormat.string(binary.bytes)) | \(slices) |")
            }
            if report.binaries.count > options.top {
                lines += ["", "\(report.binaries.count - options.top) more in the JSON report."]
            }
        }
        if !report.notes.isEmpty {
            lines += ["", "#### Notes", ""]
            lines += report.notes.map { "- " + text($0) }
        }
        lines.append("")
        lines.append("<sub>sizeledger \(text(report.tool.version)). Sizes in decimal units (1 MB = 1,000,000 bytes). The install size rounds every file up to 4 KiB blocks; it is an estimate, not the App Store's number.</sub>")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func table(
        _ lines: inout [String], title: String, header: String,
        rows: [(label: String, bytes: UInt64, files: Int)], total: UInt64, hidden: Int
    ) {
        lines += ["", "#### \(title)", "", "| \(header) | Size | Share | Files |", "| --- | ---: | ---: | ---: |"]
        for row in rows {
            lines.append("| \(row.label) | \(ByteFormat.string(row.bytes)) | \(ByteFormat.share(row.bytes, of: total)) | \(row.files) |")
        }
        if hidden > 0 { lines += ["", "\(hidden) more in the JSON report."] }
    }

    /// Plain text safe in a table cell, a heading or a list item. Line breaks become spaces, so the
    /// value stays on its line; Markdown and HTML syntax is backslash-escaped; and a word GitHub
    /// would turn into a link, an @mention, an issue reference or math goes in a code span, the
    /// one place where none of those apply (backslashes and entities do not stop them: GitHub
    /// renders `\$x\$` as math too).
    ///
    /// Everything works on Unicode scalars, not `Character`s: a combining mark after `|` or a
    /// backtick makes one `Character` that compares unequal to it, while GitHub still sees the
    /// pipe or backtick byte.
    static func text(_ value: String) -> String {
        var result = ""
        var first = true
        for token in oneLine(value).split(separator: " ", omittingEmptySubsequences: false) {
            if !first { result.append(" ") }
            first = false
            let word = String(token)
            result += needsCodeSpan(word) ? code(word) : escaped(word)
        }
        return result
    }

    /// Characters GitHub can read as Markdown or HTML syntax.
    private static let syntax: Set<Unicode.Scalar> = [
        "\\", "&", "`", "*", "_", "[", "]", "(", ")", "<", ">", "|", "#", "!", "~",
    ]

    /// Control characters replaced and every line break (LF, CR, VT, FF, NEL, U+2028, U+2029)
    /// turned into a space.
    static func oneLine(_ value: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x0A, 0x0B, 0x0C, 0x0D, 0x85, 0x2028, 0x2029: scalars.append(" ")
            default: scalars.append(scalar)
            }
        }
        return Sanitize.text(String(scalars))
    }

    /// Each syntax scalar preceded by a backslash.
    private static func escaped(_ value: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in value.unicodeScalars {
            if syntax.contains(scalar) { scalars.append("\\") }
            scalars.append(scalar)
        }
        return String(scalars)
    }

    /// Whether GitHub would link or typeset this word: a URL, a `www.` host, an email address or
    /// @mention (any `@`), an issue or pull request reference (`#` before a digit), something that
    /// looks like a commit hash, or a `$` that could open or close inline math (`$x$`, `$$x$$`
    /// and `` $`x`$ ``), where a LaTeX command such as `\color` or `\huge` would change the text.
    private static func needsCodeSpan(_ word: String) -> Bool {
        if word.unicodeScalars.contains("$") { return true }
        let lower = word.lowercased()
        if lower.contains("://") || lower.contains("www.") || lower.contains("mailto:") || lower.contains("xmpp:") { return true }
        if word.unicodeScalars.contains("@") { return true }
        let scalars = Array(word.unicodeScalars)
        for (index, scalar) in scalars.enumerated() where scalar == "#" && index + 1 < scalars.count {
            if ("0"..."9").contains(scalars[index + 1]) { return true }
        }
        let hex = scalars.filter { ("0"..."9").contains($0) || ("a"..."f").contains($0) || ("A"..."F").contains($0) }
        return scalars.count >= 7 && hex.count == scalars.count && scalars.contains(where: { ("0"..."9").contains($0) })
    }

    /// A code span that holds any text on one line: the fence is longer than the longest run of
    /// backticks inside, a space pads text that starts or ends with a backtick, and `|` is escaped
    /// because GitHub splits table cells on it even in code.
    static func code(_ value: String) -> String {
        var clean = String.UnicodeScalarView()
        var longest = 0, run = 0
        for scalar in oneLine(value).unicodeScalars {
            run = scalar == "`" ? run + 1 : 0
            longest = max(longest, run)
            if scalar == "|" { clean.append("\\") }
            clean.append(scalar)
        }
        let fence = String(repeating: "`", count: longest + 1)
        let padding = clean.first == "`" || clean.last == "`" ? " " : ""
        return fence + padding + String(clean) + padding + fence
    }
}
