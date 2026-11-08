import SwiftUI
import WidgetKit

// Build 84: live Car Player widget. Shows On/Off, car connection, playing state,
// time, quality and volume; buttons control the car player through the phone's
// loopback endpoint (CarPlayerIntent). Start/Stop open ScreenLink (iOS requires the
// app for PiP and the VPN). Video playback code is unchanged.

private let startURL = URL(string: "screenlink://start-youtube")!
private let stopURL = URL(string: "screenlink://disconnect-all")!
private let openURL = URL(string: "screenlink://open")!

struct CarPlayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScreenLink.CarPlayer", provider: CarPlayerProvider()) { entry in
            CarPlayerWidgetView(entry: entry)
        }
        .configurationDisplayName("ScreenLink Car Player")
        .description("See and control the car video: play, pause, skip, volume, quality and sound.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CarPlayerEntry: TimelineEntry {
    let date: Date
    let state: CarPlayerState?
}

struct CarPlayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarPlayerEntry {
        CarPlayerEntry(date: Date(), state: CarPlayerState(running: true, active: true, paused: false, position: 83,
                                                           duration: 296, quality: "auto", volume: 0.8, eq: "normal", car: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (CarPlayerEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { completion(CarPlayerEntry(date: Date(), state: await CarPlayerConnection.state())) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarPlayerEntry>) -> Void) {
        Task {
            let state = await CarPlayerConnection.state()
            // Buttons refresh the widget right after each tap; otherwise check every few minutes.
            let next = Date().addingTimeInterval(state?.running == true ? 120 : 900)
            completion(Timeline(entries: [CarPlayerEntry(date: Date(), state: state)], policy: .after(next)))
        }
    }
}

private func clock(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
}

private let accent = Color(red: 0.32, green: 0.86, blue: 0.72)

private struct StatusPill: View {
    let state: CarPlayerState?
    var body: some View {
        let (text, color): (String, Color) = {
            guard let state, state.running else { return ("Off", .gray) }
            if !state.active { return ("Waiting for YouTube", .orange) }
            if !state.car { return ("Waiting for car", .orange) }
            return (state.paused ? "Paused" : "Playing", state.paused ? .yellow : accent)
        }()
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2.weight(.semibold)).lineLimit(1)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(.white.opacity(0.12), in: Capsule())
    }
}

private struct ControlButton: View {
    let action: CarPlayerAction
    let symbol: String?
    let title: String
    var selected = false
    var big = false
    var body: some View {
        Button(intent: CarPlayerIntent(action)) {
            Group {
                if let symbol { Image(systemName: symbol).font(big ? .title2.weight(.bold) : .subheadline.weight(.semibold)) }
                else { Text(title).font(.caption.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7) }
            }
            .frame(maxWidth: .infinity, minHeight: big ? 44 : 30)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(selected ? accent : Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: big ? 14 : 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

private struct OffView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            Text("ScreenLink is off").font(.headline)
            Text("Start YouTube + PiP to control the car video here.").font(.caption).foregroundStyle(.white.opacity(0.7))
            Link(destination: startURL) {
                Label("Start", systemImage: "power").font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .foregroundStyle(.black).background(accent, in: Capsule())
            }
        }
    }
}

struct CarPlayerWidgetView: View {
    let entry: CarPlayerEntry
    @Environment(\.widgetFamily) private var family

    private var state: CarPlayerState? { entry.state }
    private var playSymbol: String { (state?.paused ?? true) ? "play.fill" : "pause.fill" }
    private var muted: Bool { (state?.volume ?? 1) <= 0.001 }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "airplayvideo").foregroundStyle(accent)
            Text(family == .systemSmall ? "Car" : "ScreenLink Car").font(.subheadline.weight(.bold)).lineLimit(1)
            Spacer(minLength: 4)
            StatusPill(state: state)
        }
    }

    private var info: some View {
        HStack(spacing: 8) {
            Text("\(clock(state?.position ?? 0)) / \(clock(state?.duration ?? 0))").font(.caption.monospacedDigit())
            Spacer(minLength: 0)
            Text((state?.quality ?? "auto") == "auto" ? "Auto" : "\(state?.quality ?? "")p").font(.caption2.weight(.bold))
                .padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.14), in: Capsule())
            Label(muted ? "Muted" : "\(Int(((state?.volume ?? 1) * 100).rounded()))%",
                  systemImage: muted ? "speaker.slash.fill" : "speaker.wave.2.fill").font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    private var progress: some View {
        let fraction = (state?.duration ?? 0) > 0 ? min(1, max(0, (state?.position ?? 0) / (state?.duration ?? 1))) : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(accent).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 5)
    }

    private var transport: some View {
        HStack(spacing: 6) {
            ControlButton(action: .back, symbol: "gobackward.10", title: "Back 10 seconds")
            ControlButton(action: .playPause, symbol: playSymbol, title: "Play or pause", selected: true)
            ControlButton(action: .forward, symbol: "goforward.10", title: "Forward 10 seconds")
        }
    }

    private var volume: some View {
        HStack(spacing: 6) {
            ControlButton(action: .volumeDown, symbol: "speaker.minus.fill", title: "Volume down")
            ControlButton(action: .toggleMute, symbol: muted ? "speaker.slash.fill" : "speaker.fill", title: "Mute or unmute", selected: muted)
            ControlButton(action: .volumeUp, symbol: "speaker.plus.fill", title: "Volume up")
        }
    }

    private var quality: some View {
        HStack(spacing: 6) {
            ControlButton(action: .auto, symbol: nil, title: "Auto", selected: (state?.quality ?? "auto") == "auto")
            ControlButton(action: .hd720, symbol: nil, title: "720p", selected: state?.quality == "720")
            ControlButton(action: .hd1080, symbol: nil, title: "1080p", selected: state?.quality == "1080")
        }
    }

    private var sound: some View {
        HStack(spacing: 6) {
            ControlButton(action: .normalSound, symbol: nil, title: "Normal", selected: (state?.eq ?? "normal") != "music")
            ControlButton(action: .music, symbol: nil, title: "Music", selected: state?.eq == "music")
        }
    }

    private var sessionRow: some View {
        HStack(spacing: 6) {
            Link(destination: openURL) {
                Label("Open", systemImage: "iphone").font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28).background(.white.opacity(0.14), in: Capsule())
            }
            Link(destination: stopURL) {
                Label("Stop", systemImage: "power").font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 28).foregroundStyle(.white)
                    .background(Color.red.opacity(0.55), in: Capsule())
            }
        }
    }

    var body: some View {
        Group {
            if state?.running != true {
                VStack(alignment: .leading, spacing: 6) { header; OffView() }
            } else {
                switch family {
                case .systemSmall:
                    VStack(spacing: 8) {
                        header
                        Text("\(clock(state?.position ?? 0)) / \(clock(state?.duration ?? 0))").font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8)).frame(maxWidth: .infinity, alignment: .leading)
                        ControlButton(action: .playPause, symbol: playSymbol, title: "Play or pause", selected: true, big: true)
                        HStack(spacing: 6) {
                            ControlButton(action: .volumeDown, symbol: "speaker.minus.fill", title: "Volume down")
                            ControlButton(action: .volumeUp, symbol: "speaker.plus.fill", title: "Volume up")
                        }
                    }
                case .systemLarge:
                    VStack(alignment: .leading, spacing: 9) {
                        header; info; progress; transport; volume
                        Text("Quality").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                        quality
                        Text("Sound").font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                        sound
                        Spacer(minLength: 0)
                        sessionRow
                    }
                default:
                    VStack(alignment: .leading, spacing: 7) {
                        header; info
                        HStack(spacing: 6) {
                            ControlButton(action: .back, symbol: "gobackward.10", title: "Back 10 seconds")
                            ControlButton(action: .playPause, symbol: playSymbol, title: "Play or pause", selected: true)
                            ControlButton(action: .forward, symbol: "goforward.10", title: "Forward 10 seconds")
                            ControlButton(action: .volumeDown, symbol: "speaker.minus.fill", title: "Volume down")
                            ControlButton(action: .toggleMute, symbol: muted ? "speaker.slash.fill" : "speaker.fill", title: "Mute or unmute", selected: muted)
                            ControlButton(action: .volumeUp, symbol: "speaker.plus.fill", title: "Volume up")
                        }
                        quality
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.03, green: 0.06, blue: 0.10), Color(red: 0.05, green: 0.22, blue: 0.20)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(openURL)
    }
}
