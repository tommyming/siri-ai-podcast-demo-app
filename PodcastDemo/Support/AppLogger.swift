import Foundation
import os

/// Centralized logging for app state changes, backed by Apple's `os.Logger`
/// (unified logging system — viewable in Console.app or with `log`).
///
/// Categories map to the app's functional areas so log entries can be
/// filtered per subsystem, e.g.:
///
///     log stream --predicate 'subsystem == "com.example.PodcastDemo"'
///
/// Use `notice` (default) for state changes, `info` for lifecycle/discovery,
/// `debug` for detail, `error`/`fault` for failures.
nonisolated enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.example.PodcastDemo"

    /// General app lifecycle and navigation.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// iTunes Search API requests and responses.
    static let network = Logger(subsystem: subsystem, category: "network")

    /// Audio playback state changes.
    static let playback = Logger(subsystem: subsystem, category: "playback")

    /// Favorites additions and removals.
    static let favorites = Logger(subsystem: subsystem, category: "favorites")

    /// App Intents invocations and results.
    static let intents = Logger(subsystem: subsystem, category: "intents")
}
