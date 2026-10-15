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

    /// Plain text with Markdown and HTML syntax escaped, and any word GitHub would autolink put
    /// in a code span, so a file name or Info.plist value cannot inject a clickable link.
    static func text(_ value: String) -> String {
        var result = ""
        var first = true
        for token in Sanitize.text(value).split(separator: " ", omittingEmptySubsequences: false) {
            if !first { result.append(" ") }
            first = false
            let word = String(token)
            result += autolinks(word) ? code(word) : escaped(word)
        }
        return result
    }

    /// Markdown and HTML syntax characters backslash-escaped.
    private static func escaped(_ value: String) -> String {
        var result = ""
        for character in value {
            if "\\`*_[]<>|#!~&".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }

    /// Whether GitHub-flavoured Markdown would turn this word into a link: an `http(s)`/`ftp` URL,
    /// a `www.` host or a bare email. Backslash escapes do not disable GitHub's autolink
    /// extension, so such a word goes in a code span instead, where nothing is markup.
    private static func autolinks(_ word: String) -> Bool {
        if word.contains("://") || word.lowercased().hasPrefix("www.") { return true }
        if let at = word.firstIndex(of: "@") { return word[word.index(after: at)...].contains(".") }
        return false
    }

    /// A code span that holds any text: the fence is longer than the longest run of backticks
    /// inside, and `|` is escaped because GitHub splits table cells on it even in code.
    static func code(_ value: String) -> String {
        let clean = Sanitize.text(value).replacingAll("|", with: "\\|")
        var longest = 0, run = 0
        for character in clean {
            run = character == "`" ? run + 1 : 0
            longest = max(longest, run)
        }
        let fence = String(repeating: "`", count: longest + 1)
        let padding = clean.hasPrefix("`") || clean.hasSuffix("`") ? " " : ""
        return fence + padding + clean + padding + fence
    }
}

extension String {
    func replacingAll(_ target: Character, with replacement: String) -> String {
        var result = ""
        for character in self {
            if character == target { result += replacement } else { result.append(character) }
        }
        return result
    }
}
