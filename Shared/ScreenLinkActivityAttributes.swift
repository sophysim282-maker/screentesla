import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct ScreenLinkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var running: Bool
        var started: Date
        var phase: Int
    }
    var title: String
}
