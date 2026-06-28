import Foundation
import os

/// Structured logging via os.Logger. Quiet in normal operation (the system does
/// not persist debug/info), but `.error`/`.notice` are captured in the unified
/// log and visible in Console.app for diagnosing failures in the field.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.humanlayer.paperweight"

    static let engine = Logger(subsystem: subsystem, category: "engine")
    static let overlay = Logger(subsystem: subsystem, category: "overlay")
    static let settings = Logger(subsystem: subsystem, category: "settings")
    static let schedule = Logger(subsystem: subsystem, category: "schedule")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
