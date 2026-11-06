import ActivityKit
import Foundation
import UIKit
import WidgetKit

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
    @objc static func widgetDiagnostics() -> String {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let urls = try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil) else {
            return "WIDGET MISSING: signed installation has no PlugIns folder. Preserve the widget extension when signing. Shortcut fallback: screenlink://start-youtube"
        }
        let widgets = urls.compactMap { Bundle(url: $0) }.filter {
            ($0.infoDictionary?["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.widgetkit-extension"
        }
        guard let widget = widgets.first else {
            return "WIDGET MISSING AFTER SIGNING: ScreenLinkWidgets.appex was not found. Re-sign while preserving extensions. Shortcut fallback: screenlink://start-youtube"
        }
        let parent = Bundle.main.bundleIdentifier ?? ""
        guard (widget.bundleIdentifier ?? "").hasPrefix(parent + ".") else {
            return "WIDGET BUNDLE-ID MISMATCH AFTER SIGNING: extension must use the signed app bundle ID as its prefix. Receiver settings are unchanged."
        }
        if #available(iOS 17.0, *) { WidgetCenter.shared.reloadAllTimelines() }
        return "WIDGET BUNDLE PRESENT: \(widget.bundleIdentifier ?? "unknown"). Reload requested. This does not verify its signing profile or iOS registration. If still absent, share this diagnostic and the signed IPA (not your signing certificate/password). Shortcut fallback: screenlink://start-youtube"
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
