import Foundation
import CoreLocation
import AVFoundation
import UIKit

/// Build 105: keeps ScreenLink running in the background while sharing is on, without needing the
/// PiP window. iOS suspends an app that only serves a local website; an app with running location
/// updates (the blue mark at the top of the iPhone) is allowed to stay awake. Low accuracy is asked
/// for, so it costs little battery. Stopped by Stop / Disconnect all.
@objc(SLKeepAwake)
final class SLKeepAwake: NSObject, CLLocationManagerDelegate {
    private static let shared = SLKeepAwake()
    private let manager = CLLocationManager()
    private var wanted = false

    // Build 110: proof and cure for "the car asks, the phone does not answer".
    // A heartbeat ticks once a second on two queues. If the high-priority one skips more than 3.5 s
    // while the iPhone itself was awake, iOS paused the whole app; if only the low-priority one skips,
    // iOS slowed background work. Either is logged, and a silent sound is started: an app that is
    // playing audio is kept running at full speed in the background, like it is with the PiP window.
    private static var log: ((String) -> Void)?
    @objc static func setLog(_ block: @escaping (String) -> Void) { log = block }
    private var beats: [DispatchSourceTimer] = []
    private var silent: AVAudioPlayer?
    private var inBackground = false
    private var observers: [NSObjectProtocol] = []
    private var lastReport = Date.distantPast

    private func startHeartbeat() {
        guard beats.isEmpty else { return }
        inBackground = UIApplication.shared.applicationState == .background
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.inBackground = true },
            center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in self?.inBackground = false },
        ]
        for (name, qos) in [("fast", DispatchQoS.userInteractive), ("slow", DispatchQoS.utility)] {
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "screenlink.heartbeat." + name, qos: qos))
            var lastUp = ProcessInfo.processInfo.systemUptime
            var lastWall = Date()
            timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(100))
            timer.setEventHandler { [weak self] in
                let up = ProcessInfo.processInfo.systemUptime, wall = Date()
                let gapUp = up - lastUp, gapWall = wall.timeIntervalSince(lastWall)
                lastUp = up; lastWall = wall
                guard gapWall > 3.5 else { return }
                // The uptime clock stops while the iPhone sleeps; if it also jumped, the phone was awake.
                let awake = gapUp > 3.5
                DispatchQueue.main.async { self?.skipped(name == "fast", seconds: gapWall, phoneAwake: awake) }
            }
            timer.resume()
            beats.append(timer)
        }
    }

    private func stopHeartbeat() {
        beats.forEach { $0.cancel() }
        beats = []
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        silent?.stop()
        silent = nil
    }

    private func skipped(_ wholeApp: Bool, seconds: Double, phoneAwake: Bool) {
        guard wanted else { return }
        // The slow heartbeat also skips when the whole app was paused: report that once, as a pause.
        if !wholeApp && Date().timeIntervalSince(lastReport) < 2 { return }
        lastReport = Date()
        let place = inBackground ? "in the background" : "on screen"
        let heat = ProcessInfo.processInfo.thermalState.rawValue
        if !phoneAwake {
            Self.log?(String(format: "IPHONE SLEPT for %.0f s (ScreenLink %@). The car could not be answered during that time.", seconds, place))
        } else if wholeApp {
            Self.log?(String(format: "APP PAUSED BY iOS for %.0f s (ScreenLink %@, thermal state %d). The car could not be answered during that time.", seconds, place, heat))
        } else {
            Self.log?(String(format: "BACKGROUND WORK SLOWED by iOS for %.0f s (ScreenLink %@, thermal state %d).", seconds, place, heat))
        }
        startSilentSound()
    }

    /// One second of silence, looped. Uses the same audio session settings as the rest of the app
    /// (playback, movie, mixed with other apps), so YouTube, AirPlay and PiP are not interrupted.
    private func startSilentSound() {
        if let silent, silent.isPlaying { return }
        let rate = 8000, samples = rate
        var wav = Data()
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: Array("RIFF".utf8)); put32(UInt32(36 + samples * 2)); wav.append(contentsOf: Array("WAVEfmt ".utf8))
        put32(16); put16(1); put16(1); put32(UInt32(rate)); put32(UInt32(rate * 2)); put16(2); put16(16)
        wav.append(contentsOf: Array("data".utf8)); put32(UInt32(samples * 2)); wav.append(Data(count: samples * 2))
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
        guard let player = try? AVAudioPlayer(data: wav) else {
            Self.log?("KEEP AWAKE 2 FAILED: the silent sound could not be prepared.")
            return
        }
        player.numberOfLoops = -1
        player.volume = 0
        let started = player.play()
        silent = player
        Self.log?(started ? "KEEP AWAKE 2 ON: a silent sound now plays so iOS keeps ScreenLink running at full speed without PiP. You hear nothing."
                          : "KEEP AWAKE 2 FAILED: iOS did not start the silent sound.")
    }

    @objc static func start() { DispatchQueue.main.async { shared.begin() } }
    @objc static func stop() { DispatchQueue.main.async { shared.end() } }
    /// Empty when fine; otherwise one plain sentence for the log.
    @objc static func problem() -> String {
        switch shared.manager.authorizationStatus {
        case .denied, .restricted: return "Location is not allowed for ScreenLink, so iOS can still suspend it without PiP. Allow it in iPhone Settings → ScreenLink → Location → While Using."
        default: return ""
        }
    }

    private func begin() {
        wanted = true
        startHeartbeat()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = 500
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        run()
    }

    private func run() {
        let status = manager.authorizationStatus
        guard wanted, status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }


    private func end() {
        wanted = false
        stopHeartbeat()
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { run() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
