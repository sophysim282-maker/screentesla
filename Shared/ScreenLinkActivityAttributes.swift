import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct ScreenLinkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var running: Bool
        var started: Date
        var phase: Int
        // Build 85 "ScreenLink Mission" Dynamic Island. Optional so older content decodes.
        var stage: String? = nil      // countdown, liftoff, cruise, paused, signal, landed
        var theme: Int? = nil         // character for this video: rocket, UFO, roadster, comet
        var countdownEnd: Date? = nil // self-running T-minus while waiting for YouTube
        var videoStart: Date? = nil   // video progress runs itself between these dates
        var videoEnd: Date? = nil
        var progress: Double? = nil   // fixed progress while paused
    }
    var title: String
}
