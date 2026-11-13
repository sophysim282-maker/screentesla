import Foundation
import UIKit
import CoreLocation

/// The Tesla screen can control the app: this builds what the car shows and runs what the car taps.
extension NavModel {
    func carState() -> [String: Any] {
        let s = settings
        let screen: String
        if guiding { screen = "drive" }
        else if showingDirections && selected != nil { screen = "directions" }
        else if selected != nil { screen = "place" }
        else if !results.isEmpty { screen = "results" }
        else { screen = "home" }

        var d: [String: Any] = [
            "screen": screen,
            "navigating": guiding,
            "instruction": nextInstruction,
            "maneuver": nextManeuver,
            "then": thenManeuver ?? "",
            "lanes": (googleActive ? (googleStep?.lanes ?? []) : []).map { ["shape": $0.main, "go": $0.recommended] as [String: Any] },
            "engine": googleActive ? "google" : "screenlink",
            "delay": abs(trafficDelay) >= 60 ? (trafficDelay > 0 ? "+\(Int((trafficDelay / 60).rounded())) min traffic" : "\(Int((-trafficDelay / 60).rounded())) min faster than usual") : "",
            "distance": NavModel.distanceText(distanceToNext),
            "remaining": NavModel.distanceText(remainingMeters),
            "eta": NavModel.timeText(remainingSeconds),
            "arrival": arrivalText,
            "weather": weatherTemp ?? "",
            "night": s.isNight,
            "lang": s.language,
            "spokenText": spokenText,
            "spokenId": spokenId,
            "status": status,
            "mapType": s.mapType,
            "carIcon": s.carIcon,
            "follow": MapController.shared.carFollow,
            "home": s.home?.name ?? "",
            "work": s.work?.name ?? "",
            "favorites": s.favorites.map { ["name": $0.name] },
            "recents": s.recents.prefix(8).map { ["name": $0.name, "address": $0.address] },
            "results": results.map { ["name": $0.name, "address": $0.address] },
            "suggestions": suggestions.map { ["id": $0.id, "main": $0.main, "secondary": $0.secondary] },
            "mode": mode,
            "stop": stop?.name ?? "",
            "heading": carBearing,
            // Build 137: speed and the age of the GPS point, so the car can draw the car where it is now.
            "speed": max(0, location?.speed ?? 0),
            "fixAge": location.map { max(0, Date().timeIntervalSince($0.timestamp)) } ?? 0,
            "lat": (carCoordinate ?? location?.coordinate)?.latitude ?? 0,
            "lng": (carCoordinate ?? location?.coordinate)?.longitude ?? 0,
            "bg": !CarLink.liveMapUsable,
            // Build 98: the car draws the map itself from these (see CanvasShell.js updateCarMap).
            "mapOn": CarLink.carMapOn,
            // Build 105: the car draws the map from squares this iPhone hands over (/map/tile/…).
            "tiles": CarLink.carMapOn && !CarLink.carGoogle && SLMapTiles.ready,
            "tileV": SLMapTiles.version,
            "tileError": String(SLMapTiles.problem.prefix(90)),
            "carGoogle": CarLink.carGoogle,
            "mapKey": CarLink.carGoogle ? CarLink.carMapKey : "",   // build 104: the key stays on the phone unless the switch is on
            "routeLine": carRouteLine(),
            // Build 139: slow (1) and jammed (2) parts of the route line, as point numbers along the line.
            "routeTraffic": (route?.traffic ?? []).map { [$0.start, $0.end, $0.speed == "TRAFFIC_JAM" ? 2 : 1] },
            "routeId": routesVersion * 100 + routeIndex,
            "headingUp": MapController.shared.headingUp,
            "driveResults": driveResults.map { ["name": $0.name, "address": $0.address] },
            "modes": modeSeconds.mapValues { $0 < 0 ? "—" : NavModel.timeText($0) },
            "routes": routes.enumerated().map { i, r in
                ["time": NavModel.timeText(r.seconds), "arrive": NavModel.clock(r.seconds),
                 "dist": NavModel.distanceText(r.meters), "sel": i == routeIndex] as [String: Any]
            },
        ]
        if let p = selected {
            // Build 100: lat/lng let the car map show this place with its name.
            var pl: [String: Any] = ["name": p.name, "address": p.address, "lat": p.lat, "lng": p.lng]
            if let i = info {
                if let r = i.rating { pl["rating"] = r; pl["count"] = i.ratingCount ?? 0 }
                if let t = i.type { pl["type"] = t }
                if let o = i.openNow { pl["open"] = o }
                if let h = i.hoursText { pl["hours"] = h }
            }
            if let sec = modeSeconds["DRIVE"], sec >= 0 { pl["drive"] = NavModel.timeText(sec) }
            d["place"] = pl
        }
        return d
    }

    /// Encoded route line for the car map, cached per route (the state is built 12 times a second).
    private static var routeLineCache: (id: Int, line: String) = (-1, "")
    func carRouteLine() -> String {
        let id = routesVersion * 1000 + routeIndex * 10 + (path == nil ? 0 : 1)
        if Self.routeLineCache.id != id { Self.routeLineCache = (id, path?.encodedPath() ?? "") }
        return Self.routeLineCache.line
    }

    func handleCar(_ a: String, _ p: [String: String]) {
        let maps = MapController.shared
        let s = settings
        let i = Int(p["i"] ?? "") ?? -1
        let fx = Double(p["x"] ?? "") ?? 0
        let fy = Double(p["y"] ?? "") ?? 0
        switch a {
        case "search": search(p["q"] ?? "")
        case "type": autocomplete(p["q"] ?? "")
        case "suggest": if let sg = suggestions.first(where: { $0.id == p["id"] }) { choose(sg) }
        case "result": if results.indices.contains(i) { select(results[i]) }
        case "recent": if s.recents.indices.contains(i) { select(s.recents[i]) }
        case "fav": if s.favorites.indices.contains(i) { select(s.favorites[i]) }
        case "home": if let h = s.home { select(h) }
        case "work": if let w = s.work { select(w) }
        case "directions": openDirections()
        case "back": if showingDirections { showingDirections = false } else { clear() }
        case "close": clear(); results = []
        case "route": selectRoute(i)
        case "mode": setMode(p["m"] ?? "DRIVE")
        case "start":
            maps.follow = true
            maps.carFollow = true
            startGuidance()
        case "exit": clear()
        case "recenter": maps.recenter(self)
        case "overview": maps.overview(self)
        case "zoom": maps.zoom(Float(p["d"] ?? "") ?? 1, guiding: guiding)
        case "pan": maps.pan(fx: fx, fy: fy, guiding: guiding)
        case "pin": if !guiding { dropPin(maps.carCoordinate(fx: fx, fy: fy)) }
        case "layer": s.mapType = s.mapType == "satellite" ? "normal" : "satellite"
        case "stopsuggest": if let sg = suggestions.first(where: { $0.id == p["id"] }) { chooseStop(sg) }
        case "removestop": removeStop()
        case "compass": maps.headingUp.toggle()
        case "navsearch": searchWhileDriving(p["q"] ?? "")
        case "go": if driveResults.indices.contains(i) { goNow(driveResults[i]) }
        case "clearnear": driveResults = []; maps.recenter(self)
        // Build 100: the car map is touched directly. A tapped place name opens that place by its
        // Google id (real name, not a dropped pin); Start begins guidance as soon as the route is ready.
        case "poi":
            if let id = p["id"], !id.isEmpty, id.count < 300 { choose(Suggestion(id: id, main: p["name"] ?? "Place", secondary: "")) }
        // Build 104: tap on a map picture → the place under the finger, by its real name.
        case "tapplace":
            if !guiding {
                if let lat = Double(p["lat"] ?? ""), let lng = Double(p["lng"] ?? "") {
                    placeAt(CLLocationCoordinate2D(latitude: lat, longitude: lng))
                } else {
                    placeAt(maps.carCoordinate(fx: fx, fy: fy))
                }
            }
        case "gostart":
            maps.follow = true
            maps.carFollow = true
            startWhenReady()
        case "carmap":
            let ok = p["ok"] == "1"
            CarLink.carDrawsMapAt = ok ? Date() : .distantPast
            CarLink.carMapProblem = ok ? "" : (p["why"] ?? "The car could not draw the map")
        default: break
        }
    }
}
