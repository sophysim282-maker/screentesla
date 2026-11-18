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
    // Build 155: offline store. The last good picture for each map square is kept here and is NEVER thrown away
    // by the 4-minute traffic refresh, so when the internet is slow or gone the car keeps showing the map it
    // already loaded (the pointer still moves from GPS). Cleared only when the Google key itself changes.
    // Build 156: each copy also carries the time Google allows it to be kept (Cache-Control max-age), and is
    // saved on the phone's disk too, so the map you already drove still shows after the app restarts.
    private static var offline: [String: (data: Data, until: Date)] = [:]
    private static var offlineOrder: [String] = []
    private static var offlineKey = ""
    private static var failures = 0

    /// Why the squares cannot be fetched (empty = fine). Shown on the phone with a Fix button.
    private(set) static var problem = ""
    /// Changes when the look changes (day/night, satellite, language) so the car reloads its squares.
    private(set) static var version = 0
    /// Build 156: also ready with no internet when squares for this look are saved on the phone.
    static var ready: Bool { lock.lock(); defer { lock.unlock() }; return !session.isEmpty || diskHas }

    /// Called often from the main thread; only talks to Google when a session is missing or stale.
    static func prepare(key: String, night: Bool, satellite: Bool, language: String) {
        guard !key.isEmpty else { return }
        let want = "\(key)|\(night)|\(satellite)|\(language)"
        lock.lock()
        if wanted != want {
            wanted = want; diskFolder = Self.folder(for: want); memoryFromOtherLook()
            diskHas = !((try? FileManager.default.contentsOfDirectory(atPath: diskFolder?.path ?? ""))?.isEmpty ?? true)
            if diskHas { version += 1 }
        }
        let fresh = !session.isEmpty && style == want && Date().timeIntervalSince(made) < 12 * 3600
        let wait = creating || Date().timeIntervalSince(lastTry) < 20
        if !fresh && !wait { creating = true; lastTry = Date() }
        let go = !fresh && !wait
        lock.unlock()
        guard go else { return }

        var body: [String: Any] = ["mapType": satellite ? "satellite" : "roadmap", "language": language,
                                   "region": Locale.current.regionCode ?? "US",
                                   "scale": "scaleFactor2x", "highDpi": false]   // Build 141: names and icons twice as big (like the phone), squares 4x lighter (tested on Phnom Penh)
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
                if offlineKey != key { offline = [:]; offlineOrder = []; offlineKey = key }   // build 155: keep offline tiles unless the key changed
                if !pruned { pruned = true; DispatchQueue.global(qos: .utility).async { Self.pruneDisk() } }
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
    @objc static func tile(_ path: String) -> Data { load(path, car: true) }

    private static func load(_ path: String, car: Bool) -> Data {
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
        if car { lock.lock(); lastZoom = parts[0]; lock.unlock() }
        guard !token.isEmpty, let url = URL(string: "https://tile.googleapis.com/v1/2dtiles/\(name)?session=\(token)&key=\(key)") else { return kept(name) }
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
            // Build 155/156: keep an offline copy for as long as Google allows (bounded, oldest dropped first),
            // in memory and on disk.
            if seconds > 0 {
                let until = Date().addingTimeInterval(seconds)
                if offline[name] == nil { offlineOrder.append(name) }
                offline[name] = (result, until)
                if offlineOrder.count > 2000 { offline[offlineOrder.removeFirst()] = nil }
                Self.save(result, name: name, until: until)
            }
        } else if result.isEmpty, code == 400 || code == 401 || code == 403 {
            // The session is no longer accepted: make a new one on the next prepare().
            failures += 1
            if failures >= 4 { session = ""; problem = "Google answered \(code) for the map squares"; GoogleNav.line("MAP SQUARES FOR THE CAR: " + problem) }
        }
        lock.unlock()
        return result.isEmpty ? kept(name) : result   // build 155: internet could not fetch a fresh square; show the one we already have
    }

    // MARK: Build 156 - offline copies on disk, and squares just ahead of the car

    private static var wanted = ""
    private static var diskFolder: URL?
    private static var pruned = false
    private static var diskHas = false
    private static var lastZoom = 0
    private static var aheadCell = ""
    private static var aheadBusy = false
    private static let diskQueue = DispatchQueue(label: "screenlink.maptiles.disk", qos: .utility)
    private static let diskLimit = 150 * 1024 * 1024

    private static var root: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("MapSquares", isDirectory: true)
    }

    /// One folder per look (key, day/night, satellite, language), so a night square never shows by day.
    private static func folder(for look: String) -> URL? {
        var hash: UInt64 = 1469598103934665603
        for b in look.utf8 { hash = (hash ^ UInt64(b)) &* 1099511628211 }
        return root?.appendingPathComponent(String(hash, radix: 16), isDirectory: true)
    }

    /// The look changed: drop memory copies of the old look (the disk keeps them in their own folder).
    private static func memoryFromOtherLook() { offline = [:]; offlineOrder = [] }

    private static func file(_ name: String) -> URL? {
        diskFolder?.appendingPathComponent(name.replacingOccurrences(of: "/", with: "_") + ".tile")
    }

    /// Saved square that Google still allows us to keep; empty when none.
    private static func kept(_ name: String) -> Data {
        lock.lock()
        let now = Date()
        if let o = offline[name], o.until > now { lock.unlock(); return o.data }
        offline[name] = nil
        let url = file(name)
        lock.unlock()
        guard let url,
              let until = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date else { return Data() }
        guard until > now else { try? FileManager.default.removeItem(at: url); return Data() }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return Data() }
        lock.lock()
        if offline[name] == nil { offlineOrder.append(name) }
        offline[name] = (data, until)
        if offlineOrder.count > 2000 { offline[offlineOrder.removeFirst()] = nil }
        lock.unlock()
        return data
    }

    /// Writes the square to disk; its "modified" time is set to the moment Google says it must be dropped.
    private static func save(_ data: Data, name: String, until: Date) {
        guard let url = file(name) else { return }
        diskQueue.async {
            let fm = FileManager.default
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard (try? data.write(to: url, options: .atomic)) != nil else { return }
            try? fm.setAttributes([.modificationDate: until], ofItemAtPath: url.path)
            lock.lock(); diskHas = true; lock.unlock()
        }
    }

    /// Removes squares Google no longer allows us to keep, and the oldest ones above 150 MB.
    private static func pruneDisk() {
        guard let root else { return }
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        guard let walk = fm.enumerator(at: root, includingPropertiesForKeys: keys) else { return }
        var files: [(url: URL, until: Date, size: Int)] = []
        let now = Date()
        for case let url as URL in walk where url.pathExtension == "tile" {
            let v = try? url.resourceValues(forKeys: Set(keys))
            let until = v?.contentModificationDate ?? .distantPast
            if until <= now { try? fm.removeItem(at: url); continue }
            files.append((url, until, v?.fileSize ?? 0))
        }
        var total = files.reduce(0) { $0 + $1.size }
        for f in files.sorted(by: { $0.until < $1.until }) where total > diskLimit {
            try? fm.removeItem(at: f.url); total -= f.size
        }
        GoogleNav.line("MAP SQUARES SAVED ON PHONE: \(files.count) (\(total / 1_048_576) MB)")
    }

    /// Called from the car timer with the car's position: while the internet works, quietly loads the
    /// squares around the car (at the zoom the car uses, and one step out) so a short signal drop does not
    /// leave a blank map. Only runs when the car moves into a new square, one download at a time.
    static func ahead(lat: Double, lng: Double) {
        guard lat != 0 || lng != 0, abs(lat) < 85 else { return }
        lock.lock()
        let z = lastZoom
        let go = !session.isEmpty && z >= 10 && !aheadBusy
        let cx = Int((lng + 180) / 360 * Double(1 << z))
        let r = lat * .pi / 180
        let cy = Int((1 - log(tan(r) + 1 / cos(r)) / .pi) / 2 * Double(1 << z))
        let cell = "\(z)/\(cx)/\(cy)"
        guard go, cell != aheadCell else { lock.unlock(); return }
        aheadCell = cell; aheadBusy = true
        lock.unlock()
        DispatchQueue.global(qos: .utility).async {
            var names: [String] = []
            for zoom in [z, z - 1] {
                let shift = z - zoom, x0 = cx >> shift, y0 = cy >> shift, n = 1 << zoom
                for dy in -1...1 { for dx in -1...1 {
                    let x = x0 + dx, y = y0 + dy
                    if x >= 0, y >= 0, x < n, y < n { names.append("\(zoom)/\(x)/\(y)") }
                } }
            }
            for name in names {
                lock.lock(); let have = (offline[name]?.until ?? .distantPast) > Date(); lock.unlock()
                if !have && kept(name).isEmpty { _ = load(name, car: false) }
            }
            lock.lock(); aheadBusy = false; lock.unlock()
        }
    }
}
