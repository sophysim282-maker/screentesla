import AppIntents
import SwiftUI
import WidgetKit

// Build 84: Control Center controls (iOS 18+), like the Wi-Fi button.
// - ScreenLink On/Off toggle: On opens ScreenLink and starts YouTube + PiP (iOS only
//   allows PiP and the VPN from the app); Off opens ScreenLink and disconnects all.
// - Car Play/Pause and Car Mute run directly, without opening the app.

@available(iOS 18.0, *)
struct ScreenLinkSessionValue: ControlValueProvider {
    var previewValue: Bool { false }
    func currentValue() async throws -> Bool {
        await CarPlayerConnection.state()?.running ?? false
    }
}

@available(iOS 18.0, *)
struct ScreenLinkSessionIntent: SetValueIntent {
    static var title: LocalizedStringResource = "Turn ScreenLink on or off"
    static var description = IntentDescription("Start YouTube + PiP, or disconnect ScreenLink.")

    @Parameter(title: "ScreenLink on")
    var value: Bool

    init() {}

    func perform() async throws -> some IntentResult & OpensIntent {
        let url = URL(string: value ? "screenlink://start-youtube" : "screenlink://disconnect-all")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

@available(iOS 18.0, *)
struct ScreenLinkSessionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScreenLink.Control.Session", provider: ScreenLinkSessionValue()) { isOn in
            ControlWidgetToggle("ScreenLink", isOn: isOn, action: ScreenLinkSessionIntent()) { on in
                Label(on ? "On" : "Off", systemImage: on ? "airplayvideo" : "airplayvideo.badge.exclamationmark")
            }
            .tint(.mint)
        }
        .displayName("ScreenLink")
        .description("Turn the ScreenLink car session on or off.")
    }
}

@available(iOS 18.0, *)
struct CarPlayPauseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScreenLink.Control.PlayPause") {
            ControlWidgetButton(action: CarPlayerIntent(.playPause)) {
                Label("Car Play/Pause", systemImage: "playpause.fill")
            }
        }
        .displayName("Car Play/Pause")
        .description("Play or pause the video in the car.")
    }
}

@available(iOS 18.0, *)
struct CarMuteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScreenLink.Control.Mute") {
            ControlWidgetButton(action: CarPlayerIntent(.toggleMute)) {
                Label("Car Mute", systemImage: "speaker.slash.fill")
            }
        }
        .displayName("Car Mute")
        .description("Mute or unmute the car video.")
    }
}
