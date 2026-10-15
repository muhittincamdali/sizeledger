import Foundation

/// A stand-in for an analytics SDK, the kind of dependency that grows an app between releases.
/// It keeps events in memory and never sends anything.
public final class Analytics: @unchecked Sendable {
    public struct Event: Hashable, Sendable {
        public let name: String
        public let properties: [String: String]
        public let date: Date
    }

    public static let shared = Analytics()

    private let lock = NSLock()
    private var events: [Event] = []

    public func track(_ name: String, _ properties: [String: String] = [:]) {
        lock.lock()
        defer { lock.unlock() }
        events.append(Event(name: name, properties: properties, date: Date()))
        if events.count > 500 { events.removeFirst(events.count - 500) }
    }

    public var recentEvents: [Event] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    public func summary() -> [String: Int] {
        Dictionary(grouping: recentEvents, by: \.name).mapValues(\.count)
    }
}
