import Foundation
import CoreLocation
import UIKit
import GoogleMaps
#if canImport(GoogleNavigation)
import GoogleNavigation
#endif

/// Build 127: Google's own navigation engine (Navigation SDK), the same one the Google Maps app uses.
/// It follows the car on the road, knows the next turn and the lanes, and makes a new route by itself
/// when the driver leaves the route. ScreenLink's screens, the car and the cube keep reading NavModel;
/// this class only fills NavModel with Google's answers. If Google cannot start (the key has no
/// Navigation SDK, the terms were refused, no route), ScreenLink's own turn logic runs as before.
struct GoogleLane {
    let shapes: [String]     // one lane can allow several directions
    let main: String         // the direction to show: the recommended one, else the first
    let recommended: Bool
}

struct GoogleStep {
    let instruction: String
    let maneuver: String
    let then: String?
    let lanes: [GoogleLane]
    let road: String
}

#if canImport(GoogleNavigation)
@objc(SLGoogleNav)
final class GoogleNav: NSObject, GMSNavigatorListener, GMSRoadSnappedLocationProviderListener {
    static let shared = GoogleNav()
    private static var log: ((String) -> Void)?
    @objc static func setLog(_ block: @escaping (String) -> Void) { log = block; captureGoogleMessages() }
    static func note(_ text: String) { log?("GOOGLE NAVIGATION: " + text) }
    /// Build 130: any map line for the log (map picture, map squares, Google's own messages).
    static func line(_ text: String) { DispatchQueue.main.async { log?(text) } }

    /// Build 130: Google's map kit writes its reasons (for example "API key not authorized") only to the
    /// developer console. This copies those lines into ScreenLink's log. Everything else is passed on unchanged.
    private static var captured = false
    private static var googleLines = 0
    static func captureGoogleMessages() {
        guard !captured else { return }
        captured = true
        var ends: [Int32] = [0, 0]
        guard pipe(&ends) == 0 else { return }
        let original = dup(STDERR_FILENO)
        guard original >= 0, dup2(ends[1], STDERR_FILENO) >= 0 else { return }
        let reader = FileHandle(fileDescriptor: ends[0], closeOnDealloc: false)
        var pending = ""
        reader.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            data.withUnsafeBytes { raw in if let base = raw.baseAddress { _ = write(original, base, data.count) } }
            pending += String(decoding: data, as: UTF8.self)
            while let cut = pending.firstIndex(of: "\n") {
                let text = String(pending[..<cut]); pending = String(pending[pending.index(after: cut)...])
                let low = text.lowercased()
                guard low.contains("google") || low.contains("gms") || low.contains("api key") || low.contains("maps sdk") || low.contains("navigation sdk") else { continue }
                googleLines += 1
                guard googleLines <= 40 else { continue }
                line("GOOGLE SAYS: " + String(text.suffix(300)))
            }
        }
    }

    private weak var model: NavModel?
    private var key = ""
    private var lastStepText = ""
    private var loggedInfo = false

    /// Starts (or restarts) Google guidance for the model's destination. Safe to call again when the route changes.
    func start(model: NavModel) {
        self.model = model
        guard let place = model.selected else { return }
        var points: [(CLLocationCoordinate2D, String)] = []
        if let stop = model.stop { points.append((CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng), stop.name)) }
        points.append((CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng), place.name))
        let wanted = points.map { String(format: "%.5f,%.5f", $0.0.latitude, $0.0.longitude) }.joined(separator: ";") + "|" + model.mode
        if wanted == key, model.googleActive { return }
        key = wanted
        guard model.mode == "DRIVE" || model.mode == "TWO_WHEELER" else {
            model.googleActive = false
            Self.note("only used for driving; this trip uses ScreenLink's own guidance.")
            return
        }
        GMSNavigationServices.showTermsAndConditionsDialogIfNeeded(withCompanyName: "ScreenLink") { [weak self] accepted in
            guard let self else { return }
            guard accepted else {
                self.model?.googleActive = false
                Self.note("Google's navigation terms were not accepted, so ScreenLink's own guidance is used.")
                return
            }
            self.begin(points, wanted: wanted)
        }
    }

    // Build 134: Google's own navigation screen. The phone map itself becomes Google's navigation map:
    // Google's turn banner, lanes, speed, voice, camera and re-centre button, exactly as in the Google Maps app.
    private var listening = false
    private func begin(_ points: [(CLLocationCoordinate2D, String)], wanted: String) {
        let map = MapController.shared.phoneMap
        map.isNavigationEnabled = true
        guard let navigator = map.navigator else {
            model?.googleActive = false
            Self.note("could not be started on this phone. ScreenLink's own guidance is used.")
            return
        }
        if !listening {
            listening = true
            navigator.add(self)
            map.roadSnappedLocationProvider?.add(self)
        }
        map.travelMode = model?.mode == "TWO_WHEELER" ? .twoWheeler : .driving
        map.settings.isNavigationHeaderEnabled = true
        map.settings.isNavigationFooterEnabled = true
        map.settings.isRecenterButtonEnabled = true
        map.shouldDisplaySpeedometer = true
        navigator.voiceGuidance = (model?.settings.voiceOn ?? true) ? .alertsAndGuidance : .silent
        navigator.sendsBackgroundNotifications = false
        let waypoints = points.compactMap { GMSNavigationWaypoint(location: $0.0, title: $0.1) }
        guard !waypoints.isEmpty else { return }
        Self.note("asking Google for the route (\(waypoints.count) stop(s)).")
        navigator.setDestinations(waypoints) { [weak self] status in
            guard let self, self.key == wanted, let model = self.model else { return }
            guard status == .OK else {
                model.googleActive = false
                Self.note("Google did not give a route (answer \(status.rawValue)). If the Navigation SDK is not enabled for your key in Google Cloud, enable it. ScreenLink's own guidance is used now.")
                return
            }
            navigator.isGuidanceActive = true
            map.cameraMode = .following
            map.roadSnappedLocationProvider?.startUpdatingLocation()
            model.googleActive = true
            self.lastStepText = ""
            self.loggedInfo = false
            self.redraw()
            Self.note("ON with Google's own navigation screen and voice. Turns, lanes, distance, arrival time and new routes come from Google.")
        }
    }

    func stop() {
        key = ""
        lastStepText = ""
        let map = MapController.shared.phoneMap
        if let navigator = map.navigator {
            navigator.isGuidanceActive = false
            navigator.clearDestinations()
        }
        map.roadSnappedLocationProvider?.stopUpdatingLocation()
        map.isNavigationEnabled = false
        if model?.googleActive == true { Self.note("stopped.") }
        model?.googleActive = false
        model?.googleStep = nil
    }

    /// Draw Google's current route line on ScreenLink's maps.
    private func redraw() {
        guard let model, let legs = session?.navigator?.routeLegs, !legs.isEmpty else { return }
        let line = GMSMutablePath()
        for leg in legs { if let path = leg.path { for i in 0..<path.count() { line.add(path.coordinate(at: i)) } } }
        guard line.count() > 1 else { return }
        let old = model.route
        model.replaceRoute(RouteOption(id: 0, path: line, steps: old?.steps ?? [], meters: old?.meters ?? 0, seconds: old?.seconds ?? 0, labels: old?.labels ?? []))
    }

    // MARK: - Google's answers

    func navigator(_ navigator: GMSNavigator, didUpdate navInfo: GMSNavigationNavInfo) {
        guard let model, model.googleActive, model.guiding else { return }
        model.remainingMeters = Double(navInfo.distanceToFinalDestinationMeters)
        model.remainingSeconds = Double(navInfo.timeToFinalDestinationSeconds)
        guard let step = navInfo.currentStep else { return }
        let distance = Double(navInfo.distanceToCurrentStepMeters)
        model.distanceToNext = distance
        var then: String?
        if let after = navInfo.remainingSteps.first, after.distanceFromPrevStepMeters < 400 { then = Self.maneuver(after) }
        let lanes: [GoogleLane] = (step.lanes ?? []).map { lane in
            GoogleLane(shapes: lane.laneDirections.map { Self.shape($0.laneShape) },
                       main: Self.shape((lane.laneDirections.first { $0.recommended } ?? lane.laneDirections.first)?.laneShape ?? .straight),
                       recommended: lane.laneDirections.contains { $0.recommended })
        }
        let text = step.fullInstructionText
        let made = GoogleStep(instruction: text, maneuver: Self.maneuver(step), then: then, lanes: lanes, road: step.fullRoadName)
        model.googleStep = made
        if !loggedInfo {
            loggedInfo = true
            Self.note("first turn from Google: \"\(text)\" in \(Int(distance)) m, arrow \(made.maneuver) (Google code \(step.maneuver.rawValue)), lanes \(lanes.count).")
        }
        // Build 134: Google's own voice speaks the turns (as in Google Maps). The mute button switches it.
        let wantVoice: GMSNavigationVoiceGuidance = model.settings.voiceOn ? .alertsAndGuidance : .silent
        if navigator.voiceGuidance != wantVoice { navigator.voiceGuidance = wantVoice }
        lastStepText = text
    }

    func navigatorDidChangeRoute(_ navigator: GMSNavigator) {
        guard model?.googleActive == true else { return }
        redraw()
        Self.note("Google made a new route (traffic, or the car left the old one).")
    }

    func navigator(_ navigator: GMSNavigator, didArriveAt waypoint: GMSNavigationWaypoint) {
        guard let model, model.googleActive else { return }
        if navigator.continueToNextDestination() != nil {
            model.stop = nil
            Self.note("arrived at the stop; continuing to the destination.")
            return
        }
        Self.note("arrived.")
        model.speak(model.settings.language == "en" ? "You have arrived" : "Arrive at \(waypoint.title)")
        model.clear()
        model.status = "Arrived ✅"
    }

    func locationProvider(_ locationProvider: GMSRoadSnappedLocationProvider, didUpdate location: CLLocation) {
        guard let model, model.googleActive, model.guiding else { return }
        model.carCoordinate = location.coordinate
        if location.course >= 0 { model.carBearing = location.course }
    }

    // MARK: - Google's codes to the names ScreenLink already uses

    static func maneuver(_ step: GMSNavigationStepInfo) -> String {
        switch step.maneuver {
        case .destination: return "ARRIVE"
        case .depart: return "DEPART"
        case .straight: return "STRAIGHT"
        case .turnLeft: return "TURN_LEFT"
        case .turnRight: return "TURN_RIGHT"
        case .turnSlightLeft: return "TURN_SLIGHT_LEFT"
        case .turnSlightRight: return "TURN_SLIGHT_RIGHT"
        case .turnSharpLeft: return "TURN_SHARP_LEFT"
        case .turnSharpRight: return "TURN_SHARP_RIGHT"
        case .turnKeepLeft: return "FORK_LEFT"
        case .turnKeepRight: return "FORK_RIGHT"
        case .turnUTurnClockwise: return "UTURN_RIGHT"
        case .turnUTurnCounterClockwise: return "UTURN_LEFT"
        case .mergeLeft: return "MERGE"
        case .mergeRight: return "MERGE"
        case .forkLeft: return "FORK_LEFT"
        case .forkRight: return "FORK_RIGHT"
        default:
            let text = step.fullInstructionText.lowercased()
            if text.contains("roundabout") { return step.drivingSide == .left ? "ROUNDABOUT_LEFT" : "ROUNDABOUT_RIGHT" }
            if text.contains("left") { return text.contains("exit") || text.contains("ramp") ? "RAMP_LEFT" : "TURN_LEFT" }
            if text.contains("right") { return text.contains("exit") || text.contains("ramp") ? "RAMP_RIGHT" : "TURN_RIGHT" }
            return "STRAIGHT"
        }
    }

    static func shape(_ shape: GMSNavigationLaneShape) -> String {
        switch shape {
        case .straight: return "straight"
        case .slightLeft: return "slight-left"
        case .slightRight: return "slight-right"
        case .normalLeft: return "left"
        case .normalRight: return "right"
        case .sharpLeft: return "sharp-left"
        case .sharpRight: return "sharp-right"
        case .uTurnLeft: return "uturn-left"
        case .uTurnRight: return "uturn-right"
        default: return "straight"
        }
    }
}
#else
/// Build 133 (test): the app is built WITHOUT Google's navigation kit, to see whether that kit is what makes
/// the map picture grey. ScreenLink's own turn logic runs. The log lines keep working.
@objc(SLGoogleNav)
final class GoogleNav: NSObject {
    static let shared = GoogleNav()
    private static var log: ((String) -> Void)?
    @objc static func setLog(_ block: @escaping (String) -> Void) { log = block; captureGoogleMessages() }
    static func note(_ text: String) { log?("GOOGLE NAVIGATION: " + text) }
    /// Build 130: any map line for the log (map picture, map squares, Google's own messages).
    static func line(_ text: String) { DispatchQueue.main.async { log?(text) } }

    /// Build 130: Google's map kit writes its reasons (for example "API key not authorized") only to the
    /// developer console. This copies those lines into ScreenLink's log. Everything else is passed on unchanged.
    private static var captured = false
    private static var googleLines = 0
    static func captureGoogleMessages() {
        guard !captured else { return }
        captured = true
        var ends: [Int32] = [0, 0]
        guard pipe(&ends) == 0 else { return }
        let original = dup(STDERR_FILENO)
        guard original >= 0, dup2(ends[1], STDERR_FILENO) >= 0 else { return }
        let reader = FileHandle(fileDescriptor: ends[0], closeOnDealloc: false)
        var pending = ""
        reader.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            data.withUnsafeBytes { raw in if let base = raw.baseAddress { _ = write(original, base, data.count) } }
            pending += String(decoding: data, as: UTF8.self)
            while let cut = pending.firstIndex(of: "\n") {
                let text = String(pending[..<cut]); pending = String(pending[pending.index(after: cut)...])
                let low = text.lowercased()
                guard low.contains("google") || low.contains("gms") || low.contains("api key") || low.contains("maps sdk") || low.contains("navigation sdk") else { continue }
                googleLines += 1
                guard googleLines <= 40 else { continue }
                line("GOOGLE SAYS: " + String(text.suffix(300)))
            }
        }
    }

    func start(model: NavModel) { model.googleActive = false }
    func stop() {}
}
#endif
