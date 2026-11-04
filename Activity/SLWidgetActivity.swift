import ActivityKit
import Foundation
import UIKit

// The launcher opens the main app. No shared container, push service or recording
// is needed. ActivityKit is presentation only; it never grants background time.
@objc(SLWidgetActivity)
final class SLWidgetActivity: NSObject {
    @objc(updateStatus:running:)
    static func updateStatus(_ status: String, running: Bool) {
        DispatchQueue.main.async {
            if #available(iOS 16.2, *) { LiveStatus.shared.update(status, running: running) }
        }
    }
    @objc static func finish() {
        DispatchQueue.main.async {
            if #available(iOS 16.2, *) { LiveStatus.shared.finish() }
        }
    }
}

@available(iOS 16.2, *)
private final class LiveStatus {
    static let shared = LiveStatus()
    private var activity: Activity<ScreenLinkActivityAttributes>?
    private var lastStatus = ""
    private var lastRunning = false
    private var lastUpdate = Date.distantPast
    private var phase = 0
    private var generation = 0

    func update(_ status: String, running: Bool) {
        if activity == nil {
            activity = Activity<ScreenLinkActivityAttributes>.activities.first {
                $0.activityState == .active || $0.activityState == .stale
            }
        }
        if let current = activity, current.activityState == .dismissed || current.activityState == .ended {
            activity = nil
        }
        // A heartbeat makes a suspended/killed app show stale status honestly.
        // Pet transitions happen only on real state changes, not every heartbeat.
        let changed = status != lastStatus || running != lastRunning
        guard changed || Date().timeIntervalSince(lastUpdate) >= 60 || activity == nil else { return }
        if changed { phase += 1 }
        let started = activity?.content.state.started ?? Date()
        let state = ScreenLinkActivityAttributes.ContentState(status: status, running: running, started: started, phase: phase)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(90))
        if let current = activity {
            let token = generation
            Task { @MainActor in
                guard token == generation else { return }
                await current.update(content)
            }
        } else {
            guard running, UIApplication.shared.applicationState == .active,
                  ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                activity = try Activity.request(attributes: ScreenLinkActivityAttributes(title: "YouTube"), content: content, pushType: nil)
            } catch {
                NSLog("ScreenLink Live Activity unavailable: %@", error.localizedDescription)
                return
            }
        }
        lastStatus = status; lastRunning = running; lastUpdate = Date()
    }

    func finish() {
        generation += 1
        let ours = Activity<ScreenLinkActivityAttributes>.activities
        activity = nil; lastStatus = ""; lastUpdate = .distantPast
        Task {
            for item in ours { await item.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
