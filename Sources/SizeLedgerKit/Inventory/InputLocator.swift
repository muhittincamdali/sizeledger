import Foundation

/// Why an input could not be measured.
public enum InputError: Error, Equatable, Sendable {
    /// Nothing exists at the path.
    case notFound(String)
    /// The path is not an `.app` folder, an `.ipa` (ZIP) file or an `.xcarchive` folder.
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

/// Finds the app bundle behind a path the user gave.
enum InputLocator {
    static func open(_ url: URL) throws -> any BundleSource {
        let path = url.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw InputError.notFound(path)
        }
        let name = url.lastPathComponent
        let suffix = url.pathExtension.lowercased()

        if isDirectory.boolValue {
            switch suffix {
            case "app":
                return try readDirectory(url, kind: .app)
            case "xcarchive":
                let applications = url.appendingPathComponent("Products/Applications")
                let apps = ((try? FileManager.default.contentsOfDirectory(atPath: applications.path)) ?? [])
                    .filter { $0.hasSuffix(".app") }
                    .sorted()
                guard let app = apps.first else { throw InputError.noApp(name) }
                guard apps.count == 1 else { throw InputError.severalApps(name, apps) }
                return try readDirectory(applications.appendingPathComponent(app), kind: .xcarchive)
            default:
                throw InputError.unsupported(path)
            }
        }

        do {
            return try IPASource(url: url)
        } catch ZipError.notAZipArchive {
            throw InputError.unsupported(path)
        } catch let error as ZipError {
            throw InputError.unreadable(path, error.description)
        }
    }

    private static func readDirectory(_ url: URL, kind: InputKind) throws -> DirectorySource {
        do {
            return try DirectorySource(root: url, kind: kind)
        } catch {
            throw InputError.unreadable(url.path, error.localizedDescription)
        }
    }
}
