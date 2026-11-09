import Foundation
import NetworkExtension

// Build 87: Car Maps inside ScreenLink. ScreenLink already owns the 240.3.3.3 VPN, and iOS
// runs only one VPN at a time, so this keeps Car Maps' screens unchanged but only reports
// ScreenLink's VPN status. Turning it on or off is done by ScreenLink (Start / Disconnect).
final class CarVPN: ObservableObject {
    static let address = "240.3.3.3"
    @Published var status: NEVPNStatus = .invalid
    @Published var error: String?
    private var observer: NSObjectProtocol?

    var isOn: Bool { status == .connected }
    var statusText: String {
        switch status {
        case .connected: return "On (ScreenLink VPN)"
        case .connecting, .reasserting: return "Turning on…"
        case .disconnecting: return "Turning off…"
        default: return "Off — tap Start in ScreenLink"
        }
    }

    init() {
        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] n in
            if let c = n.object as? NEVPNConnection { self?.status = c.status }
        }
        refresh()
    }

    private func refresh() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] list, _ in
            DispatchQueue.main.async {
                self?.status = list?.first(where: { $0.connection.status == .connected })?.connection.status
                    ?? list?.first?.connection.status ?? .invalid
            }
        }
    }

    /// ScreenLink's Start button connects its VPN; here we only refresh the status.
    func turnOn() { error = nil; refresh() }
    /// Use ScreenLink's Disconnect All to turn the VPN off.
    func turnOff() { refresh() }
}
