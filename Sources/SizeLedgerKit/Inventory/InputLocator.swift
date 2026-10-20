import Foundation

/// Why an input could not be measured.
public enum InputError: Error, Equatable, Sendable {
    /// Nothing exists at the path.
    case notFound(String)
    /// The path is not an `.app` folder, an `.ipa` (ZIP) file or an `.xcarchive` folder. A file
    /// named `.ipa` that is not a ZIP archive, or is a damaged one, is ``unreadable(_:_:)`` instead.
    case unsupported(String)
    /// The archive holds no app bundle.
    case noApp(String)
    /// The archive holds more than one app bundle; their names follow.
    case severalApps(String, [String])
    /// The input exists but cannot be read; the reason follows.
    case unreadable(String, String)
}

extension InputError: CustomStringConvertible {
    /// A sentence for the user that names the path. Paths and entry names come from the input, so
    /// control characters in them are replaced before the sentence reaches a terminal.
    public var description: String {
        Sanitize.text(message)
    }

    private var message: String {
        switch self {
        case .notFound(let path):
            "\(path) does not exist"
        case .unsupported(let path):
            "\(path) is not an .app bundle, an .ipa or an .xcarchive"
        case .noApp(let name):
            "\(name) contains no app (expected Payload/<name>.app in an .ipa or Products/Applications/<name>.app in an .xcarchive)"
        case .severalApps(let name, let apps):
            "\(name) contains more than one app: \(apps.joined(separator: ", ")); pass the .app folder you want to measure"
        case .unreadable(let path, let reason):
            "\(path) cannot be read: \(reason)"
        }
    }
}

/// Finds the app bundle behind a path the user gave. The path itself is followed if it is a
/// symbolic link, since the user named it; links inside the input are not.
enum InputLocator {
    static func open(_ url: URL, limits: AnalysisLimits = .default) throws -> any BundleSource {
        let path = url.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw InputError.notFound(path)
        }
        let suffix = url.pathExtension.lowercased()

        if isDirectory.boolValue {
            switch suffix {
            case "app":
                return try readDirectory(url, kind: .app, limits: limits)
            case "xcarchive":
                return try readArchive(url, limits: limits)
            default:
                throw InputError.unsupported(path)
            }
        }

        do {
            return try IPASource(url: url, limits: limits)
        } catch ZipError.notAZipArchive where suffix != "ipa" {
            throw InputError.unsupported(path)
        } catch let error as ZipError {
            throw InputError.unreadable(path, error.description)
        }
    }

    /// The app in `Products/Applications`. The archive is the input, so a symbolic link on the way
    /// to the app (Products, Applications or the `.app` itself) is refused rather than followed:
    /// following it would measure, and print the file names of, a folder outside the archive.
    private static func readArchive(_ url: URL, limits: AnalysisLimits) throws -> DirectorySource {
        let name = url.lastPathComponent
        var applications = url
        for component in ["Products", "Applications"] {
            applications.appendPathComponent(component)
            switch itemType(applications) {
            case nil:
                throw InputError.noApp(name)
            case .typeSymbolicLink?:
                throw symbolicLinkError(applications)
            default:
                continue
            }
        }
        let apps = ((try? FileManager.default.contentsOfDirectory(atPath: applications.path)) ?? [])
            .filter { $0.hasSuffix(".app") }
            .sorted()
        guard let app = apps.first else { throw InputError.noApp(name) }
        guard apps.count == 1 else { throw InputError.severalApps(name, apps) }
        let bundle = applications.appendingPathComponent(app)
        if itemType(bundle) == .typeSymbolicLink { throw symbolicLinkError(bundle) }
        return try readDirectory(bundle, kind: .xcarchive, limits: limits)
    }

    /// The type of the item itself, read with lstat, so a symbolic link reports as a link; `nil`
    /// when nothing is there.
    private static func itemType(_ url: URL) -> FileAttributeType? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.type] as? FileAttributeType
    }

    private static func symbolicLinkError(_ url: URL) -> InputError {
        .unreadable(url.path, "it is a symbolic link, and links inside an .xcarchive are not followed")
    }

    private static func readDirectory(_ url: URL, kind: InputKind, limits: AnalysisLimits) throws -> DirectorySource {
        do {
            return try DirectorySource(root: url, kind: kind, limits: limits)
        } catch let error as InputError {
            throw error
        } catch {
            throw InputError.unreadable(url.path, error.localizedDescription)
        }
    }
}
