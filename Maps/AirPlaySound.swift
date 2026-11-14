import Foundation
import AVFoundation

/// Build 128: "Phone sound". ScreenLink speaks the old AirPlay (version 1), so iOS treats it as the
/// speaker for the whole phone and sends the sound of every app to it (Messenger, Telegram …), not only
/// YouTube. ScreenLink used to throw that sound away, so those apps were silent. This class unpacks the
/// sound and plays it on the phone's own speaker, which gives the result modern AirPlay gives.
///
/// The car video and its sound do not pass through here (the car fetches them itself).
/// Silence is ignored, so ScreenLink's own silent keep-awake sound does not start anything.
@objc(SLAirPlaySound)
final class SLAirPlaySound: NSObject {
    private static let queue = DispatchQueue(label: "screenlink.airplay.sound")
    private static var log: ((String) -> Void)?
    @objc static func setLog(_ block: @escaping (String) -> Void) { queue.async { log = block } }

    private static let outFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    private static var inFormat: AVAudioFormat?
    private static var converter: AVAudioConverter?
    private static var engine: AVAudioEngine?
    private static var node: AVAudioPlayerNode?
    private static var key = ""
    private static var packets = 0, unpacked = 0, failed = 0, loud = 0, played = 0
    private static var lastReport = Date.distantPast
    private static var lastLoud = Date.distantPast
    private static var active = false
    /// True while another app's sound is being played on the phone (KeepAwake must not change the sound mode).
    @objc static var playing: Bool { active }
    private static var blockedNote = ""
    private static var idleTimer: DispatchSourceTimer?

    /// One sound packet from the AirPlay library. `ct` = kind (2 Apple Lossless, 4 AAC, 8 AAC-ELD), `spf` = samples in it.
    @objc(packet:ct:spf:) static func packet(_ data: Data, ct: Int, spf: Int) {
        queue.async { handle(data, ct, spf) }
    }

    private static var firstSeen = false
    private static var badInRow = 0
    // Build 133: an unlocked Apple Lossless piece starts with 3 bits that say "stereo" (001) or "mono" (000).
    // Count how many pieces look like that with the key in use; switch keys when most do not.
    private static var looked = 0, headerGood = 0, keyRounds = 0
    private static var cookieForm = 0, cookieTries = 0, readyLogged = -1
    private static func checkKey(_ data: Data) {
        looked += 1
        let tag = data[data.startIndex] >> 5
        if tag <= 1 { headerGood += 1 }
        guard looked >= 100 else { return }
        let keys = NSClassFromString("SLAudioKey") as? NSObject.Type
        let raw = (keys?.perform(NSSelectorFromString("raw"))?.takeUnretainedValue() as? NSNumber)?.boolValue ?? false
        let first = data.prefix(8).map { String(format: "%02x", $0) }.joined(separator: " ")
        if keyRounds < 6 {
            keyRounds += 1
            log?("AIRPLAY SOUND: with the \(raw ? "plain" : "mixed") key, \(headerGood)% of pieces look like real sound (first bytes \(first), \(data.count) bytes).")
        }
        if headerGood < 70, let keys {
            _ = keys.perform(NSSelectorFromString("setRaw:"), with: NSNumber(value: !raw))
            keySwitches += 1
            key = ""
        }
        looked = 0; headerGood = 0
    }
    private static var keySwitches = 0
    private static var unlockedLogged = false
    private static func handle(_ data: Data, _ ct: Int, _ spf: Int) {
        packets += 1
        if !firstSeen { firstSeen = true; lastReport = .distantPast }   // report the very first packet at once
        let on = UserDefaults.standard.bool(forKey: "soundToPhone")
        if Date().timeIntervalSince(lastReport) > 20 {
            lastReport = Date()
            let kind = ct == 2 ? "Apple Lossless" : ct == 4 ? "AAC" : ct == 8 ? "AAC-ELD" : "unknown (\(ct))"
            let route = AVAudioSession.sharedInstance().currentRoute.outputs.map { $0.portType.rawValue }.joined(separator: ",")
            log?("AIRPLAY SOUND: \(packets) packets arrived (kind \(kind), \(spf) samples each); unpacked \(unpacked), failed \(failed), with real sound \(loud), played on the phone \(played). Phone sound switch: \(on ? "On" : "Off"). ScreenLink's sound exit now: \(route.isEmpty ? "none" : route).\(blockedNote)\(on && ct == 2 ? sl_lockNote() : "")")
            packets = 0; unpacked = 0; failed = 0; loud = 0; played = 0
        }
        guard on, data.count > 4 else { return }
        // Build 145: Apple Lossless is unpacked by Apple's open-source decoder (ThirdParty/ALAC), not by the
        // iPhone's own unpacker, which refused every AirPlay packet ("!dat").
        if ct == 2 {
            checkKey(data)
            guard let pcm = decodeALAC(data, spf) else {
                failed += 1
                if failed == 1 || failed % 500 == 0 { log?("AIRPLAY SOUND: Apple Lossless packet could not be unpacked (\(data.count) bytes, first bytes \(data.prefix(6).map { String(format: "%02x", $0) }.joined(separator: " ")))\(sl_lockNote())).") }
                return
            }
            play(pcm)
            return
        }
        let wanted = "\(ct)/\(spf)"
        if wanted != key { key = wanted; prepare(ct, spf) }
        guard let converter, let inFormat else { failed += 1; return }

        let packet = AVAudioCompressedBuffer(format: inFormat, packetCapacity: 1, maximumPacketSize: max(data.count, 8192))
        data.withUnsafeBytes { raw in if let base = raw.baseAddress { memcpy(packet.data, base, data.count) } }
        packet.byteLength = UInt32(data.count)
        packet.packetCount = 1
        packet.packetDescriptions?.pointee = AudioStreamPacketDescription(mStartOffset: 0, mVariableFramesInPacket: 0, mDataByteSize: UInt32(data.count))
        guard let pcm = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: 4096) else { return }
        var given = false
        var problem: NSError?
        let result = converter.convert(to: pcm, error: &problem) { _, status in
            if given { status.pointee = .noDataNow; return nil }
            given = true
            status.pointee = .haveData
            return packet
        }
        guard result != .error, pcm.frameLength > 0, let channels = pcm.floatChannelData else {
            failed += 1
            if failed == 1 || failed % 500 == 0 { log?("AIRPLAY SOUND: a packet could not be unpacked (\(data.count) bytes, error \(problem?.code ?? 0)).") }
            // Build 133: the key is chosen by looking at the pieces (below). If the pieces look right but still
            // cannot be unpacked, the settings block is the problem: try the next form of it.
            badInRow += 1
            if badInRow >= 60, ct == 2, headerGood >= 70 {
                badInRow = 0
                cookieForm = (cookieForm + 1) % 3
                key = ""
                if cookieTries < 6 { cookieTries += 1; log?("AIRPLAY SOUND: pieces look right but do not unpack; trying settings block form \(cookieForm) now.") }
            }
            return
        }
        play(pcm)
    }

    /// Build 145: one Apple Lossless packet → phone-speaker sound (16-bit stereo, 44.1 kHz).
    private static func decodeALAC(_ data: Data, _ spf: Int) -> AVAudioPCMBuffer? {
        guard let alac = NSClassFromString("SLALAC") as? NSObject.Type,
              let out = alac.perform(NSSelectorFromString("decode:frames:"), with: data, with: NSNumber(value: spf > 0 ? spf : 352))?.takeUnretainedValue() as? Data,
              out.count >= 4 else { return nil }
        let frames = out.count / 4
        guard let pcm = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: AVAudioFrameCount(frames)), let channels = pcm.floatChannelData else { return nil }
        pcm.frameLength = AVAudioFrameCount(frames)
        out.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in 0..<frames {
                channels[0][i] = Float(Int16(littleEndian: samples[2 * i])) / 32768
                channels[1][i] = Float(Int16(littleEndian: samples[2 * i + 1])) / 32768
            }
        }
        return pcm
    }

    /// Which lock the iPhone used for this sound (for the log).
    private static func sl_lockNote() -> String {
        guard let keys = NSClassFromString("SLAudioKey") as? NSObject.Type,
              let note = keys.perform(NSSelectorFromString("lockNote"))?.takeUnretainedValue() as? String, !note.isEmpty else { return "" }
        return "; " + note
    }

    private static func play(_ pcm: AVAudioPCMBuffer) {
        guard let channels = pcm.floatChannelData else { return }
        unpacked += 1
        if badInRow > 0 || !unlockedLogged {
            if !unlockedLogged { unlockedLogged = true; log?("AIRPLAY SOUND: unlocked and unpacked ✓ (\(keySwitches) key switch(es)).") }
            badInRow = 0
        }

        // Is there anything to hear? (ScreenLink's own keep-awake sound is pure silence.)
        var peak: Float = 0
        let left = channels[0]
        var i = 0
        while i < Int(pcm.frameLength) { peak = max(peak, abs(left[i])); i += 8 }
        if peak > 0.002 { loud += 1; lastLoud = Date() }
        guard Date().timeIntervalSince(lastLoud) < 1.5 else { return }
        guard start() else { return }
        node?.scheduleBuffer(pcm, completionHandler: nil)
        played += 1
    }

    private static func prepare(_ ct: Int, _ spf: Int) {
        var d = AudioStreamBasicDescription()
        d.mSampleRate = 44100
        d.mChannelsPerFrame = 2
        var cookie: Data?
        switch ct {
        case 2:
            let frames = UInt32(spf > 0 ? spf : 352)
            d.mFormatID = kAudioFormatAppleLossless
            d.mFramesPerPacket = frames
            d.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData
            // The Apple Lossless settings block (24 bytes, big-endian).
            var c = Data()
            func put32(_ v: UInt32) { withUnsafeBytes(of: v.bigEndian) { c.append(contentsOf: $0) } }
            func put16(_ v: UInt16) { withUnsafeBytes(of: v.bigEndian) { c.append(contentsOf: $0) } }
            put32(frames); c.append(contentsOf: [0, 16, 40, 10, 14, 2]); put16(255); put32(0); put32(0); put32(44100)
            // Build 133: three forms of the same settings: bare, inside an 'alac' box, inside 'frma' + 'alac'.
            var alacBox = Data(); func box32(_ v: UInt32) { withUnsafeBytes(of: v.bigEndian) { alacBox.append(contentsOf: $0) } }
            box32(36); alacBox.append(contentsOf: Array("alac".utf8)); box32(0); alacBox.append(c)
            var frma = Data([0, 0, 0, 12]); frma.append(contentsOf: Array("frma".utf8)); frma.append(contentsOf: Array("alac".utf8)); frma.append(alacBox)
            cookie = cookieForm == 1 ? alacBox : cookieForm == 2 ? frma : c
        case 4:
            d.mFormatID = kAudioFormatMPEG4AAC
            d.mFramesPerPacket = UInt32(spf > 0 ? spf : 1024)
            cookie = Data([0x12, 0x10])               // AAC-LC, 44.1 kHz, stereo
        default:
            d.mFormatID = kAudioFormatMPEG4AAC_ELD
            d.mFramesPerPacket = UInt32(spf > 0 ? spf : 480)
            // Build 129: AAC-ELD cannot be unpacked without its settings block (44.1 kHz, stereo, 480 samples).
            // Build 128 had none, so nothing could be unpacked.
            cookie = Data([0xF8, 0xE8, 0x50, 0x00])
        }
        inFormat = AVAudioFormat(streamDescription: &d)
        converter = inFormat.flatMap { AVAudioConverter(from: $0, to: outFormat) }
        if let cookie { converter?.magicCookie = cookie }
        if converter == nil || readyLogged != cookieForm { readyLogged = cookieForm; log?(converter == nil ? "AIRPLAY SOUND: this iPhone could not make an unpacker for kind \(ct) with \(spf) samples." : "AIRPLAY SOUND: unpacker ready for kind \(ct) with \(spf) samples (settings form \(cookieForm)).") }
    }

    /// Makes ScreenLink's own sound come out of the phone speaker (not back into AirPlay) and starts the player.
    private static func start() -> Bool {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            // With this mode iOS does not send ScreenLink's own sound to AirPlay, so there is no circle.
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
                try session.setActive(true)
            } catch {
                blockedNote = " iOS refused the phone-speaker mode: \(error.localizedDescription)."
                return false
            }
        }
        if session.currentRoute.outputs.contains(where: { $0.portType == .airPlay }) {
            blockedNote = " iOS still sends ScreenLink's own sound to AirPlay, so it is NOT played (it would make an echo circle)."
            return false
        }
        blockedNote = ""
        if engine?.isRunning != true {
            let made = AVAudioEngine(), player = AVAudioPlayerNode()
            made.attach(player)
            made.connect(player, to: made.mainMixerNode, format: outFormat)
            do { try made.start() } catch {
                blockedNote = " The phone player did not start: \(error.localizedDescription)."
                return false
            }
            player.play()
            engine = made
            node = player
        }
        if !active {
            active = true
            log?("AIRPLAY SOUND: another app is playing. Its sound now comes out of the phone speaker.")
            watchIdle()
        }
        return true
    }

    /// When the other app has been quiet for a while, give the normal sound mode back (PiP and the video use it).
    private static func watchIdle() {
        idleTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler {
            guard active, Date().timeIntervalSince(lastLoud) > 8 else { return }
            active = false
            node?.stop()
            engine?.stop()
            engine = nil
            node = nil
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try? session.setActive(true)
            log?("AIRPLAY SOUND: the other app is quiet again. Normal sound mode is back.")
            idleTimer?.cancel()
            idleTimer = nil
        }
        timer.resume()
        idleTimer = timer
    }
}
