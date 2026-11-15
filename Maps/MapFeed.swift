import Foundation

// Build 87: Car Maps inside ScreenLink. Car Maps used its own web server on port 8080
// and its own 3.3.3.3 VPN, which collide with ScreenLink. This keeps Car Maps' code
// unchanged by giving it a `CarServer` with the same interface that only stores the
// latest map picture and directions. ScreenLink's own server (Receiver.m) serves them to
// the car at /map/frame.jpg, /map/bg.jpg, /map/state and /map/cmd over the one VPN.

/// Shared, thread-safe store read by Receiver.m (Objective-C) through these class methods.
@objc(SLMapFeed)
final class SLMapFeed: NSObject {
    private static let lock = NSLock()
    private static var frame = Data()
    private static var background = Data()
    private static var state = Data("{}".utf8)
    private static var lastFrameAt = Date.distantPast
    private static var lastCarRequest = Date.distantPast
    static var onCommand: ((String, [String: String]) -> Void)?

    static func store(frame jpeg: Data) { lock.lock(); frame = jpeg; lastFrameAt = Date(); lock.unlock() }
    static func store(background jpeg: Data) { lock.lock(); background = jpeg; lock.unlock() }
    static func store(state json: Data) { lock.lock(); state = json; lock.unlock() }

    /// True while the car page has asked for map data in the last few seconds.
    static var carWatching: Bool { lock.lock(); defer { lock.unlock() }; return Date().timeIntervalSince(lastCarRequest) < 4 }

    @objc static func frameData() -> Data {
        lock.lock(); defer { lock.unlock() }; lastCarRequest = Date(); return frame
    }
    @objc static func backgroundData() -> Data { lock.lock(); defer { lock.unlock() }; return background }
    @objc static func stateData() -> Data {
        lock.lock(); defer { lock.unlock() }
        lastCarRequest = Date()
        // Tell the car whether the phone is currently producing map pictures.
        guard var dict = (try? JSONSerialization.jsonObject(with: state)) as? [String: Any] else { return state }
        dict["mapLive"] = Date().timeIntervalSince(lastFrameAt) < 3
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? state
    }
    @objc static func command(_ action: String, params: [String: String]) {
        DispatchQueue.main.async { onCommand?(action, params) }
    }
}

/// Same interface Car Maps' CarLink expects; data goes to SLMapFeed instead of a socket.
final class CarServer {
    var onCommand: ((String, [String: String]) -> Void)? {
        didSet { SLMapFeed.onCommand = onCommand }
    }
    var hasClients: Bool { SLMapFeed.carWatching }

    init(port: UInt16) {}
    func start() {}

    func setState(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict) { SLMapFeed.store(state: data) }
    }
    func setBackgroundMap(_ jpeg: Data) { SLMapFeed.store(background: jpeg) }
    func broadcast(_ jpeg: Data) { SLMapFeed.store(frame: jpeg) }
}
