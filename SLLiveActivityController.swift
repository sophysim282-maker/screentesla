import ActivityKit
import Foundation

@available(iOS 16.2, *)
@objc(SLLiveActivityController)
final class SLLiveActivityController: NSObject {
    @MainActor private static var pending: Task<Void, Never>?
    @MainActor private static var lastState: ScreenLinkActivityAttributes.ContentState?
    @MainActor private static var lastRefresh = Date.distantPast

    @objc(publishSnapshot:canStart:)
    static func publishSnapshot(_ snapshot: NSDictionary, canStart: Bool) {
        let running = (snapshot["running"] as? NSNumber)?.boolValue ?? false
        let state = ScreenLinkActivityAttributes.ContentState(
            status: snapshot["status"] as? String ?? "Ready for viewer",
            screenVisible: (snapshot["screenVisible"] as? NSNumber)?.boolValue ?? false,
            streaming: (snapshot["streaming"] as? NSNumber)?.boolValue ?? false
        )
        Task { @MainActor in
            let previous = pending
            pending = Task { @MainActor in
                await previous?.value
                let activities = Activity<ScreenLinkActivityAttributes>.activities
                guard running else {
                    lastState = nil
                    for activity in activities {
                        await activity.end(nil, dismissalPolicy: .immediate)
                    }
                    return
                }
                let now = Date()
                // Renew freshness without pushing a new update every timer tick.
                if !canStart, state == lastState,
                   now.timeIntervalSince(lastRefresh) < 15 { return }
                let content = ActivityContent(
                    state: state,
                    staleDate: now.addingTimeInterval(35)
                )
                if let activity = activities.first {
                    await activity.update(content)
                    for duplicate in activities.dropFirst() {
                        await duplicate.end(nil, dismissalPolicy: .immediate)
                    }
                    lastState = state
                    lastRefresh = now
                    return
                }
                #if !SCREENLINK_BROADCAST
                // Only the foreground containing app may request an activity.
                guard canStart, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
                do {
                    _ = try Activity<ScreenLinkActivityAttributes>.request(
                        attributes: .init(startedAt: now),
                        content: content,
                        pushType: nil
                    )
                    lastState = state
                    lastRefresh = now
                } catch {
                    NSLog("ScreenLink Live Activity unavailable: %@", error.localizedDescription)
                }
                #endif
            }
        }
    }
}
