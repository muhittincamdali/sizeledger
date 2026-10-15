import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// Standard output or standard error as a `TextOutputStream`.
struct StandardStream: TextOutputStream {
    let handle: FileHandle

    static var output: StandardStream { StandardStream(handle: .standardOutput) }
    static var error: StandardStream { StandardStream(handle: .standardError) }

    static var outputIsTerminal: Bool { isatty(STDOUT_FILENO) == 1 }

    mutating func write(_ string: String) {
        handle.write(Data(string.utf8))
    }
}
