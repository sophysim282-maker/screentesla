import AppIntents
import Foundation

@available(iOS 17.0, *)
enum CarPlayerAction: String, AppEnum {
    case auto, hd720, hd1080, volumeDown, volumeUp, toggleMute
    case playPause, back, forward, normalSound, music

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Car player action"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .auto: "Auto quality", .hd720: "720p", .hd1080: "1080p",
        .volumeDown: "Volume down", .volumeUp: "Volume up", .toggleMute: "Mute or unmute",
        .playPause: "Play or pause", .back: "Back 10 seconds", .forward: "Forward 10 seconds",
        .normalSound: "Normal sound", .music: "Music sound"
    ]
}

@available(iOS 17.0, *)
struct CarPlayerIntent: AppIntent {
    static var title: LocalizedStringResource = "Control ScreenLink car player"
    static var openAppWhenRun = false

    @Parameter(title: "Action")
    var action: CarPlayerAction

    init() {}
    init(_ action: CarPlayerAction) { self.action = action }

    func perform() async throws -> some IntentResult {
        try await CarPlayerConnection.send(action.rawValue)
        return .result()
    }
}
