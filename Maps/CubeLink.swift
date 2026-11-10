import Foundation
import CoreBluetooth

/// Build 103: sends the next turn of the ScreenLink Maps route to an "Orbit Cube" display over
/// Bluetooth Low Energy. The cube is the peripheral, this app is the central. One packet
/// (little-endian) is written with response to the navigation characteristic:
///   byte 0 version (1) · byte 1 maneuver code · bytes 2-5 metres to the turn (uint32)
///   bytes 6-7 minutes left (uint16, 0xFFFF unknown) · bytes 8… next road name, UTF-8, 0-32 bytes
/// Sent when something changes and at least every 2 s while guiding; code 0 once when it stops.
final class CubeLink: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = CubeLink()
    private static let service = CBUUID(string: "1AD64E14-72BE-418D-8C36-08B4F2100F10")
    private static let navigation = CBUUID(string: "1AD64E14-72BE-418D-8C36-08B4F2100F13")
    private static let cubeName = "Orbit Cube"

    @Published var status = "Off"
    @Published var on: Bool {
        didSet {
            UserDefaults.standard.set(on, forKey: "cubeBluetoothOn")
            if on { start() } else { stop() }
        }
    }

    weak var nav: NavModel?
    private var central: CBCentralManager?
    private var cube: CBPeripheral?
    private var target: CBCharacteristic?
    private var timer: Timer?
    private var lastPacket = Data()
    private var lastSent = Date.distantPast
    private var writingSince: Date?

    private override init() {
        on = UserDefaults.standard.bool(forKey: "cubeBluetoothOn")
        super.init()
    }

    /// Called when the map screen opens: continue if the switch was left on.
    func resume(nav: NavModel) {
        self.nav = nav
        if on { start() }
    }

    private func start() {
        if central == nil {
            status = "Starting Bluetooth…"
            central = CBCentralManager(delegate: self, queue: .main)   // iOS asks for Bluetooth permission here
        } else {
            find()
        }
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        // Clear the turn on the cube before leaving it.
        if let cube, let target, cube.state == .connected {
            cube.writeValue(Self.packet(code: 0, metres: 0, minutes: 0xFFFF, road: ""), for: target, type: .withResponse)
        }
        central?.stopScan()
        if let cube { central?.cancelPeripheralConnection(cube) }
        cube = nil
        target = nil
        lastPacket = Data()
        writingSince = nil
        status = "Off"
    }

    private func find() {
        guard on, let central, central.state == .poweredOn, cube == nil else { return }
        if let known = central.retrieveConnectedPeripherals(withServices: [Self.service]).first {
            connect(known)
            return
        }
        status = "Looking for the cube…"
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func connect(_ peripheral: CBPeripheral) {
        central?.stopScan()
        cube = peripheral
        peripheral.delegate = self
        status = "Connecting to the cube…"
        central?.connect(peripheral, options: nil)      // does not time out: also reconnects later
    }

    // MARK: - Bluetooth events

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: find()
        case .poweredOff: status = "Turn Bluetooth on (iPhone Settings → Bluetooth)"
        case .unauthorized: status = "Allow Bluetooth for ScreenLink (iPhone Settings → ScreenLink)"
        case .unsupported: status = "This iPhone cannot use Bluetooth LE"
        default: break
        }
        if central.state != .poweredOn { cube = nil; target = nil }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard cube == nil else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        if name == Self.cubeName || services.contains(Self.service) { connect(peripheral) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Cube found. Reading it…"
        peripheral.discoverServices([Self.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lost(peripheral, "Could not connect to the cube. Trying again…")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        lost(peripheral, "Cube disconnected. Reconnecting…")
    }

    private func lost(_ peripheral: CBPeripheral, _ text: String) {
        target = nil
        writingSince = nil
        lastPacket = Data()
        guard on else { return }
        status = text
        central?.connect(peripheral, options: nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let found = peripheral.services?.first(where: { $0.uuid == Self.service }) else {
            status = "This device is not an Orbit Cube (service missing)"
            return
        }
        peripheral.discoverCharacteristics([Self.navigation], for: found)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let found = service.characteristics?.first(where: { $0.uuid == Self.navigation }) else {
            status = "Orbit Cube has no navigation channel"
            return
        }
        target = found
        lastPacket = Data()
        status = "Cube connected ✓"
        tick()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        writingSince = nil
        guard on else { return }
        if let error {
            lastPacket = Data()   // send it again
            let code = (error as NSError).code
            let pairing = [CBATTError.insufficientAuthentication.rawValue, CBATTError.insufficientEncryption.rawValue,
                           CBATTError.insufficientAuthorization.rawValue].contains(code)
            status = pairing ? "Type the 6-digit PIN shown on the cube" : "Cube refused the turn: \(error.localizedDescription)"
        } else {
            status = nav?.guiding == true ? "Sending turns to the cube ✓" : "Cube connected ✓ Start a route to show turns"
        }
    }

    // MARK: - Packets

    private func tick() {
        guard on, let cube, let target, cube.state == .connected else { return }
        if let since = writingSince, Date().timeIntervalSince(since) < 5 { return }   // one write at a time
        let guiding = nav?.guiding == true
        let data = currentPacket()
        let changed = data != lastPacket
        // While guiding: on every change and at least every 2 s. Stopped: code 0 once.
        guard changed || (guiding && Date().timeIntervalSince(lastSent) >= 2) else { return }
        lastPacket = data
        lastSent = Date()
        writingSince = Date()
        cube.writeValue(data, for: target, type: .withResponse)
    }

    private func currentPacket() -> Data {
        guard let nav, nav.guiding, !nav.steps.isEmpty else {
            return Self.packet(code: 0, metres: 0, minutes: 0xFFFF, road: "")
        }
        let maneuver = nav.nextManeuver
        let road = maneuver == "ARRIVE" ? (nav.selected?.name ?? "") : Self.roadName(nav.nextInstruction)
        let minutes = nav.remainingSeconds > 0 ? UInt16(min(65534, (nav.remainingSeconds / 60).rounded(.up))) : 0xFFFF
        return Self.packet(code: Self.code(maneuver), metres: UInt32(max(0, min(4_000_000, nav.distanceToNext.rounded()))),
                           minutes: minutes, road: road)
    }

    static func packet(code: UInt8, metres: UInt32, minutes: UInt16, road: String) -> Data {
        var d = Data([1, code])
        for shift in [0, 8, 16, 24] { d.append(UInt8((metres >> UInt32(shift)) & 0xFF)) }
        d.append(UInt8(minutes & 0xFF))
        d.append(UInt8(minutes >> 8))
        // At most 32 bytes of UTF-8, never cutting a letter in half.
        var name = road
        while name.utf8.count > 32 { name.removeLast() }
        d.append(contentsOf: Array(name.utf8))
        return d
    }

    /// Google Routes maneuver names → the cube's codes.
    static func code(_ m: String) -> UInt8 {
        switch m {
        case "TURN_SLIGHT_LEFT": return 2
        case "TURN_LEFT": return 3
        case "TURN_SHARP_LEFT": return 4
        case "TURN_SLIGHT_RIGHT": return 5
        case "TURN_RIGHT": return 6
        case "TURN_SHARP_RIGHT": return 7
        case "UTURN_LEFT", "UTURN_RIGHT": return 8
        case "ROUNDABOUT_LEFT", "ROUNDABOUT_RIGHT", "ROUNDABOUT_CLOCKWISE", "ROUNDABOUT_COUNTERCLOCKWISE": return 9
        case "RAMP_LEFT", "FORK_LEFT": return 10
        case "RAMP_RIGHT", "FORK_RIGHT": return 11
        case "MERGE": return 12
        case "ARRIVE": return 13
        default: return 1          // STRAIGHT, DEPART, NAME_CHANGE, FERRY… → continue
        }
    }

    /// Google gives one sentence ("Turn left onto Norodom Blvd"). Take the road after "onto" / "on" /
    /// "toward" when the sentence is English; otherwise send the sentence itself (cut to 32 bytes).
    static func roadName(_ instruction: String) -> String {
        for word in [" onto ", " on to ", " toward ", " towards ", " on "] {
            if let r = instruction.range(of: word, options: [.caseInsensitive, .backwards]) {
                let name = instruction[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        return instruction
    }
}
