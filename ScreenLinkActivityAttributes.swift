import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct ScreenLinkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var screenVisible: Bool
        var streaming: Bool
    }
    let startedAt: Date
}
