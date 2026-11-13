import Foundation

/// Build 105: map squares ("tiles") for the car. The car asks THIS iPhone at /map/tile/z/x/y and the
/// iPhone gets them from Google's Map Tiles API, so the car browser never contacts Google
/// (China-version cars block it). Needs "Map Tiles API" enabled for the user's Google key.
@objc(SLMapTiles)
final class SLMapTiles: NSObject {
    private static let lock = NSLock()
    private static var session = ""
    private static var style = ""
    private static var creating = false
    private static var lastTry = Date.distantPast
    private static var made = Date.distantPast
    private static var apiKey = ""
    // Squares are kept only for as long as Google's own answer allows (its Cache-Control header).
    private static var cache: [String: (data: Data, until: Date, header: String)] = [:]
    private static var order: [String] = []
    private static var failures = 0

    /// Why the squares cannot be fetched (empty = fine). Shown on the phone with a Fix button.
    private(set) static var problem = ""
    /// Changes when the look changes (day/night, satellite, language) so the car reloads its squares.
    private(set) static var version = 0
    static var ready: Bool { lock.lock(); defer { lock.unlock() }; return !session.isEmpty }

    /// Called often from the main thread; only talks to Google when a session is missing or stale.
    static func prepare(key: String, night: Bool, satellite: Bool, language: String) {
        guard !key.isEmpty else { return }
        let want = "\(key)|\(night)|\(satellite)|\(language)"
        lock.lock()
        let fresh = !session.isEmpty && style == want && Date().timeIntervalSince(made) < 12 * 3600
        let wait = creating || Date().timeIntervalSince(lastTry) < 20
        if !fresh && !wait { creating = true; lastTry = Date() }
        let go = !fresh && !wait
        lock.unlock()
        guard go else { return }

        var body: [String: Any] = ["mapType": satellite ? "satellite" : "roadmap", "language": language,
                                   "region": Locale.current.regionCode ?? "US",
                                   "scale": "scaleFactor2x", "highDpi": true]
        // Build 137: live traffic on the car map (green / orange / red roads), like Google Maps.
        body["layerTypes"] = satellite ? ["layerRoadmap", "layerTraffic"] : ["layerTraffic"]
        if night && !satellite {
            body["styles"] = [
                ["elementType": "geometry", "stylers": [["color": "#242f3e"]]],
                ["elementType": "labels.text.stroke", "stylers": [["color": "#242f3e"]]],
                ["elementType": "labels.text.fill", "stylers": [["color": "#9ca5b3"]]],
                ["featureType": "road", "elementType": "geometry", "stylers": [["color": "#38414e"]]],
                ["featureType": "road.highway", "elementType": "geometry", "stylers": [["color": "#746855"]]],
                ["featureType": "water", "elementType": "geometry", "stylers": [["color": "#17263c"]]],
            ]
        }
        guard let url = URL(string: "https://tile.googleapis.com/v1/createSession?key=\(key)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 12
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            lock.lock()
            creating = false
            if code == 200, let token = json?["session"] as? String, !token.isEmpty {
                session = token; style = want; apiKey = key; made = Date()
                cache = [:]; order = []; failures = 0
                version += 1
                problem = ""
            } else {
                session = ""
                let message = (json?["error"] as? [String: Any])?["message"] as? String ?? ""
                problem = code == 0 ? "no internet on the phone" : "Google answered \(code) \(message)"
                GoogleNav.line("MAP SQUARES FOR THE CAR: " + problem)
            }
            lock.unlock()
        }.resume()
    }

    /// Seconds Google allows a square to be kept; 0 when it says no-store / no-cache or says nothing.
    private static func maxAge(_ header: String) -> TimeInterval {
        let h = header.lowercased()
        guard !h.contains("no-store"), !h.contains("no-cache"), let r = h.range(of: "max-age=") else { return 0 }
        let digits = h[r.upperBound...].prefix { $0.isNumber }
        return min(86_400, TimeInterval(digits) ?? 0)
    }

    /// What the car may do with a square it just got: the same permission Google gave the phone.
    @objc static func tileCache(_ path: String) -> String {
        lock.lock(); defer { lock.unlock() }
        guard let held = cache[path], held.until > Date() else { return "no-store" }
        return "private, max-age=\(max(0, Int(held.until.timeIntervalSinceNow)))"
    }

    /// One square, asked for by the phone's web server on its own connection thread (never the main
    /// thread). `path` is "z/x/y". Empty data = not available.
    // Build 137: traffic changes, so every 4 minutes the squares are fetched fresh (the car swaps them in
    // without a blank map: see tileMap.update in CanvasShell.js).
    private static var trafficAt = Date()
    @objc static func tile(_ path: String) -> Data {
        lock.lock()
        if Date().timeIntervalSince(trafficAt) > 240 { trafficAt = Date(); cache = [:]; order = []; version += 1 }
        lock.unlock()
        let parts = path.split(separator: "/").compactMap { Int($0) }
        guard parts.count == 3, (0...22).contains(parts[0]), parts[1] >= 0, parts[2] >= 0 else { return Data() }
        let name = "\(parts[0])/\(parts[1])/\(parts[2])"
        lock.lock()
        let token = session, key = apiKey, held = cache[name]
        lock.unlock()
        if let held, held.until > Date() { return held.data }
        guard !token.isEmpty, let url = URL(string: "https://tile.googleapis.com/v1/2dtiles/\(name)?session=\(token)&key=\(key)") else { return Data() }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2   // build 107: never hold a car connection long; the video needs them
        req.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        let done = DispatchSemaphore(value: 0)
        var result = Data()
        var code = 0
        var allowed = ""
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let data { result = data }
            allowed = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Cache-Control") ?? ""
            done.signal()
        }.resume()
        _ = done.wait(timeout: .now() + 2.5)
        lock.lock()
        if !result.isEmpty, token == session {
            failures = 0
            let seconds = Self.maxAge(allowed)
            if seconds > 0 {
                if cache[name] == nil { order.append(name) }
                cache[name] = (result, Date().addingTimeInterval(seconds), "private, max-age=\(Int(seconds))")
                if order.count > 300 { cache[order.removeFirst()] = nil }
            } else {
                cache[name] = nil
            }
        } else if result.isEmpty, code == 400 || code == 401 || code == 403 {
            // The session is no longer accepted: make a new one on the next prepare().
            failures += 1
            if failures >= 4 { session = ""; problem = "Google answered \(code) for the map squares"; GoogleNav.line("MAP SQUARES FOR THE CAR: " + problem) }
        }
        lock.unlock()
        return result
    }
}
