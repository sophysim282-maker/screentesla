import UIKit
import GoogleMaps

/// Build 103: shows the map on an "Orbit Cube" (ESP32-S3 display with its own Wi-Fi hotspot).
/// The iPhone joins the cube's Wi-Fi "Orbit-Clip"; this sends one small picture after another to
/// http://192.168.9.1/frame: 80 x 80 pixels, RGB565 little-endian, top row first, 12800 bytes.
/// One picture at a time (wait for the answer), about 6 a second, and the last picture is sent
/// again while the map cannot be drawn, because the cube leaves the map after 2 s of silence.
final class CubeLink: ObservableObject {
    static let shared = CubeLink()
    static let side = 80

    @Published var status = "Off"
    @Published var on: Bool {
        didSet {
            UserDefaults.standard.set(on, forKey: "cubeOn")
            if on { start() } else { stop() }
        }
    }

    private let url = URL(string: "http://192.168.9.1/frame")!
    private let session: URLSession
    private var timer: Timer?
    private var busy = false
    private var last = Data()
    private var shown = 0
    private var waitUntil = Date.distantPast

    private init() {
        let c = URLSessionConfiguration.ephemeral
        c.allowsCellularAccess = false          // the cube has no internet: Wi-Fi only
        c.waitsForConnectivity = false
        c.timeoutIntervalForRequest = 2
        c.httpMaximumConnectionsPerHost = 1
        session = URLSession(configuration: c)
        on = UserDefaults.standard.bool(forKey: "cubeOn")
    }

    /// Called when the map screen opens: continue if the switch was left on.
    func resume() { if on { start() } }

    private func start() {
        guard timer == nil else { return }
        status = "Looking for the cube…"
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in self?.step() }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        status = "Off"
    }

    private func step() {
        guard on, !busy, Date() >= waitUntil else { return }
        if let fresh = Self.capture() { last = fresh }
        guard last.count == Self.side * Self.side * 2 else {
            status = "Open the map screen so there is a map to send"
            return
        }
        busy = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        session.uploadTask(with: request, from: last) { [weak self] data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let text = String(data: (data ?? Data()).prefix(80), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            DispatchQueue.main.async { self?.finished(code, text) }
        }.resume()
    }

    private func finished(_ code: Int, _ text: String) {
        busy = false
        guard on else { return }
        switch code {
        case 200:
            shown += 1
            status = "Map is on the cube ✓ (\(shown) pictures)"
        case 500:
            break                                   // cube was busy: just send the next picture
        case 409:
            status = "Cube refuses pictures: " + (text.isEmpty ? "car moving or no speed data yet" : text)
            waitUntil = Date().addingTimeInterval(1)
        case 403:
            status = "Join the Wi-Fi \"Orbit-Clip\" on this iPhone (Settings → Wi-Fi)"
            waitUntil = Date().addingTimeInterval(1)
        case 400:
            status = "Cube did not accept the picture size"
            waitUntil = Date().addingTimeInterval(1)
        case 0:
            status = "Cube not found. Join the Wi-Fi \"Orbit-Clip\" (Settings → Wi-Fi)"
            waitUntil = Date().addingTimeInterval(1)
        default:
            status = "Cube answered \(code)"
            waitUntil = Date().addingTimeInterval(1)
        }
    }

    /// Centre square of the live map, scaled to 80 x 80, as RGB565 little-endian. Nil when the map
    /// is not on screen (app in the background) or the iPhone returns a black picture for it.
    private static func capture() -> Data? {
        guard UIApplication.shared.applicationState == .active else { return nil }
        for view in [MapController.shared.carMap, MapController.shared.phoneMap] {
            guard view.window != nil, view.bounds.width > 0, view.bounds.height > 0 else { continue }
            if let data = rgb565(of: view) { return data }
        }
        return nil
    }

    private static func rgb565(of view: UIView) -> Data? {
        let n = side
        let scale = CGFloat(n) / min(view.bounds.width, view.bounds.height)
        let w = view.bounds.width * scale, h = view.bounds.height * scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: n, height: n), format: format).image { _ in
            view.drawHierarchy(in: CGRect(x: (CGFloat(n) - w) / 2, y: (CGFloat(n) - h) / 2, width: w, height: h),
                               afterScreenUpdates: false)
        }
        guard let cg = image.cgImage else { return nil }
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(data: &pixels, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        var out = Data(count: n * n * 2)
        var brightest: UInt8 = 0
        out.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            for i in 0..<(n * n) {
                let r = pixels[i * 4], g = pixels[i * 4 + 1], b = pixels[i * 4 + 2]
                brightest = max(brightest, r, g, b)
                let color = (UInt16(r & 0xF8) << 8) | (UInt16(g & 0xFC) << 3) | UInt16(b >> 3)
                raw[i * 2] = UInt8(color & 0xFF)        // low byte first
                raw[i * 2 + 1] = UInt8(color >> 8)
            }
        }
        return brightest < 12 ? nil : out               // all black: this view could not be copied
    }
}
