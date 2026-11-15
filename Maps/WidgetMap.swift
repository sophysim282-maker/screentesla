import UIKit
import WidgetKit

/// Build 147: the map widget on the Home Screen. The widget asks the app over the phone's own loopback
/// address (/local/widget/map, like the Car Player widget) and gets the next turn, the arrival time and a
/// map picture made here from the same Google map squares the car uses, with the route and "you are here".
@objc(SLWidgetMap)
final class SLWidgetMap: NSObject {
    private static let lock = NSLock()
    private static var picture = Data()
    private static var pictureAt = Date.distantPast
    private static var lastReload = Date.distantPast
    private static var lastTurn = ""
    private static var lastNavigating = false

    /// Called each time the car map state changes. Asks iOS to refresh the widget when the next turn
    /// changes or navigation starts/stops, at most about once a minute (iOS limits widget refreshes).
    static func note(_ state: [String: Any]) {
        let navigating = state["navigating"] as? Bool ?? false
        let turn = (state["instruction"] as? String ?? "") + "|" + (state["maneuver"] as? String ?? "")
        lock.lock()
        let changed = navigating != lastNavigating || (navigating && turn != lastTurn)
        let due = changed && Date().timeIntervalSince(lastReload) > (navigating == lastNavigating ? 45 : 5)
        if due { lastReload = Date(); lastTurn = turn; lastNavigating = navigating }
        lock.unlock()
        if due { DispatchQueue.main.async { WidgetCenter.shared.reloadTimelines(ofKind: "ScreenLink.Map") } }
    }

    /// JSON for the widget. `media` is the car player state from Receiver.m. Runs on a web server thread.
    @objc static func widgetData(_ media: NSDictionary) -> Data {
        let s = SLMapFeed.peekState()
        var out: [String: Any] = [
            "navigating": s["navigating"] as? Bool ?? false,
            "distance": s["distance"] as? String ?? "",
            "instruction": s["instruction"] as? String ?? "",
            "maneuver": s["maneuver"] as? String ?? "",
            "arrival": s["arrival"] as? String ?? "",
            "eta": s["eta"] as? String ?? "",
            "remaining": s["remaining"] as? String ?? "",
            "playing": (media["active"] as? Bool ?? false) && !(media["paused"] as? Bool ?? false),
            "position": media["position"] as? Double ?? 0,
        ]
        if let image = image(s) { out["image"] = image.base64EncodedString() }
        return (try? JSONSerialization.data(withJSONObject: out)) ?? Data("{}".utf8)
    }

    private static func image(_ s: [String: Any]) -> Data? {
        lock.lock()
        if Date().timeIntervalSince(pictureAt) < 20, !picture.isEmpty { let held = picture; lock.unlock(); return held }
        lock.unlock()
        let lat = s["lat"] as? Double ?? 0, lng = s["lng"] as? Double ?? 0
        guard lat != 0 || lng != 0 else { return nil }
        guard SLMapTiles.ready else { let bg = SLMapFeed.backgroundData(); return bg.isEmpty ? nil : bg }
        let navigating = s["navigating"] as? Bool ?? false
        let zoom = navigating ? 16 : 15
        let world = 256.0 * pow(2.0, Double(zoom))
        func point(_ la: Double, _ ln: Double) -> CGPoint {
            let x = (ln + 180) / 360 * world
            let r = la * .pi / 180
            let y = (1 - log(tan(r) + 1 / cos(r)) / .pi) / 2 * world
            return CGPoint(x: x, y: y)
        }
        let me = point(lat, lng)
        let side = 640.0
        let origin = CGPoint(x: me.x - side / 2, y: me.y - side / 2)
        let tx0 = Int(floor(origin.x / 256)), ty0 = Int(floor(origin.y / 256))
        let tx1 = Int(floor((origin.x + side) / 256)), ty1 = Int(floor((origin.y + side) / 256))
        var jobs: [(Int, Int)] = []
        for tx in tx0...tx1 { for ty in ty0...ty1 { jobs.append((tx, ty)) } }
        final class Box: @unchecked Sendable { var items: [Data]; init(_ n: Int) { items = [Data](repeating: Data(), count: n) } }
        let box = Box(jobs.count)
        let across = Int(pow(2.0, Double(zoom)))
        DispatchQueue.concurrentPerform(iterations: jobs.count) { i in
            let (tx, ty) = jobs[i]
            guard ty >= 0, ty < across else { return }
            let wrapped = ((tx % across) + across) % across
            let data = SLMapTiles.tile("\(zoom)/\(wrapped)/\(ty)")
            lock.lock(); box.items[i] = data; lock.unlock()
        }
        let squares = box.items
        guard squares.contains(where: { !$0.isEmpty }) else { return nil }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let made = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            UIColor(white: 0.93, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            for (i, job) in jobs.enumerated() {
                guard let square = UIImage(data: squares[i]) else { continue }
                square.draw(in: CGRect(x: Double(job.0) * 256 - origin.x, y: Double(job.1) * 256 - origin.y, width: 256, height: 256))
            }
            let line = decode(s["routeLine"] as? String ?? "")
            if navigating, line.count > 1 {
                let path = UIBezierPath()
                for (i, c) in line.enumerated() {
                    let p = point(c.0, c.1); let q = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
                    if i == 0 { path.move(to: q) } else { path.addLine(to: q) }
                }
                path.lineCapStyle = .round; path.lineJoinStyle = .round
                UIColor.white.setStroke(); path.lineWidth = 14; path.stroke()
                UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1).setStroke(); path.lineWidth = 9; path.stroke()
            }
            let dot = CGRect(x: side / 2 - 11, y: side / 2 - 11, width: 22, height: 22)
            ctx.cgContext.setShadow(offset: .zero, blur: 6, color: UIColor(white: 0, alpha: 0.35).cgColor)
            UIColor.white.setFill(); UIBezierPath(ovalIn: dot.insetBy(dx: -4, dy: -4)).fill()
            ctx.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1).setFill(); UIBezierPath(ovalIn: dot).fill()
        }
        guard let jpeg = made.jpegData(compressionQuality: 0.78) else { return nil }
        lock.lock(); picture = jpeg; pictureAt = Date(); lock.unlock()
        return jpeg
    }

    /// Google encoded polyline → (lat, lng) points.
    private static func decode(_ text: String) -> [(Double, Double)] {
        var points: [(Double, Double)] = []
        let bytes = Array(text.utf8)
        var i = 0, lat = 0, lng = 0
        func next() -> Int? {
            var result = 0, shift = 0
            while i < bytes.count {
                let b = Int(bytes[i]) - 63; i += 1
                result |= (b & 0x1f) << shift; shift += 5
                if b < 0x20 { return (result & 1) != 0 ? ~(result >> 1) : (result >> 1) }
            }
            return nil
        }
        while i < bytes.count {
            guard let dlat = next(), let dlng = next() else { break }
            lat += dlat; lng += dlng
            points.append((Double(lat) / 1e5, Double(lng) / 1e5))
        }
        return points
    }
}
