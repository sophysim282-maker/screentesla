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
    // Build 85 "ScreenLink Mission": the island follows the real car video.
    private var mission = Mission()
    private var poller: Timer?

    private struct Mission: Equatable {
        var stage = "countdown"
        var theme = 0
        var epoch = ""
        var playingSince: Date?
        var countdownEnd = Date().addingTimeInterval(10)
        var videoStart: Date?
        var videoEnd: Date?
        var progress: Double?
    }

    func update(_ status: String, running: Bool) {
        if activity == nil {
            activity = Activity<ScreenLinkActivityAttributes>.activities.first {
                $0.activityState == .active || $0.activityState == .stale
            }
        }
        if let current = activity, current.activityState == .dismissed || current.activityState == .ended {
            activity = nil
        }
        let changed = status != lastStatus || running != lastRunning
        guard changed || Date().timeIntervalSince(lastUpdate) >= 60 || activity == nil else { return }
        if changed { phase += 1 }
        lastStatus = status; lastRunning = running
        publish(force: true)
        startPolling()
    }

    private func startPolling() {
        guard poller == nil else { return }
        // Read the live car state every 4 s while the app runs; the island only changes on
        // real stage changes (plus a 30 s resync), so iOS is not asked for frequent updates.
        poller = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
    }

    @MainActor private func poll() async {
        guard activity != nil || lastRunning else { poller?.invalidate(); poller = nil; return }
        let state = await CarPlayerConnection.state()
        var next = mission
        let now = Date()
        if let state, state.running {
            if let epoch = state.epoch, !epoch.isEmpty, epoch != next.epoch {
                if !next.epoch.isEmpty { next.theme = (next.theme + 1) % 4 }
                next.epoch = epoch
                next.playingSince = nil
            }
            if !state.active {
                if next.stage != "countdown" { next.countdownEnd = now.addingTimeInterval(10) }
                next.stage = "countdown"; next.playingSince = nil
            } else if !state.car {
                next.stage = "signal"
            } else if state.paused {
                next.stage = "paused"; next.playingSince = nil
            } else {
                if next.playingSince == nil { next.playingSince = now }
                next.stage = now.timeIntervalSince(next.playingSince ?? now) < 8 ? "liftoff" : "cruise"
            }
            if state.duration > 0 {
                let start = now.addingTimeInterval(-state.position)
                next.videoStart = start
                next.videoEnd = start.addingTimeInterval(state.duration)
                next.progress = min(1, max(0, state.position / state.duration))
            } else { next.videoStart = nil; next.videoEnd = nil; next.progress = nil }
        } else {
            next.stage = "landed"; next.playingSince = nil
        }
        // Only the stage/theme decide a visible change; the timers drift a little, so resync them every 30 s.
        let stageChanged = next.stage != mission.stage || next.theme != mission.theme
        let drift = abs((next.videoStart ?? .distantPast).timeIntervalSince(mission.videoStart ?? .distantPast))
        mission = next
        if stageChanged || (next.stage == "cruise" && drift > 2 && now.timeIntervalSince(lastUpdate) >= 30) || now.timeIntervalSince(lastUpdate) >= 60 {
            publish(force: false)
        }
    }

    private func publish(force: Bool) {
        let started = activity?.content.state.started ?? Date()
        let m = mission
        let state = ScreenLinkActivityAttributes.ContentState(
            status: lastStatus, running: lastRunning, started: started, phase: phase,
            stage: m.stage, theme: m.theme, countdownEnd: m.countdownEnd,
            videoStart: m.stage == "paused" ? nil : m.videoStart, videoEnd: m.stage == "paused" ? nil : m.videoEnd,
            progress: m.progress)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(90))
        lastUpdate = Date()
        if let current = activity {
            let token = generation
            Task { @MainActor in
                guard token == self.generation else { return }
                await current.update(content)
            }
        } else {
            guard lastRunning, UIApplication.shared.applicationState == .active,
                  ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                activity = try Activity.request(attributes: ScreenLinkActivityAttributes(title: "YouTube"), content: content, pushType: nil)
            } catch {
                NSLog("ScreenLink Live Activity unavailable: %@", error.localizedDescription)
            }
        }
    }

    func finish() {
        generation += 1
        poller?.invalidate(); poller = nil
        mission = Mission()
        let ours = Activity<ScreenLinkActivityAttributes>.activities
        activity = nil; lastStatus = ""; lastUpdate = .distantPast
        Task {
            for item in ours { await item.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
