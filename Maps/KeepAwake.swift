import Foundation
import CoreLocation

/// Build 105: keeps ScreenLink running in the background while sharing is on, without needing the
/// PiP window. iOS suspends an app that only serves a local website; an app with running location
/// updates (the blue mark at the top of the iPhone) is allowed to stay awake. Low accuracy is asked
/// for, so it costs little battery. Stopped by Stop / Disconnect all.
@objc(SLKeepAwake)
final class SLKeepAwake: NSObject, CLLocationManagerDelegate {
    private static let shared = SLKeepAwake()
    private let manager = CLLocationManager()
    private var wanted = false

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
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { run() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
