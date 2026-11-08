import SwiftUI
import WidgetKit

struct CarPlayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScreenLink.CarPlayer", provider: CarPlayerProvider()) { _ in
            CarPlayerWidgetView()
        }
        .configurationDisplayName("ScreenLink Car Player")
        .description("Control an active car player directly from your Home Screen.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct CarPlayerEntry: TimelineEntry { let date: Date }

private struct CarPlayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarPlayerEntry {
        CarPlayerEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (CarPlayerEntry) -> Void) {
        completion(CarPlayerEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarPlayerEntry>) -> Void) {
        completion(Timeline(entries: [CarPlayerEntry(date: Date())], policy: .never))
    }
}

private struct CarPlayerWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private func control(_ action: CarPlayerAction, _ title: LocalizedStringKey,
                         symbol: String? = nil, iconOnly: Bool = false) -> some View {
        Button(intent: CarPlayerIntent(action)) {
            Group {
                if let symbol {
                    if iconOnly {
                        Image(systemName: symbol)
                    } else {
                        Label(title, systemImage: symbol)
                    }
                } else {
                    Text(title)
                }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(.white.opacity(0.14), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ScreenLink Car Player", systemImage: "airplayvideo")
                .font(.headline)
                .foregroundStyle(.mint)
                .lineLimit(1)
            HStack(spacing: 6) {
                control(.auto, "Auto")
                control(.hd720, "720p")
                control(.hd1080, "1080p")
            }
            HStack(spacing: 6) {
                control(.volumeDown, "Volume down", symbol: "speaker.minus", iconOnly: true)
                control(.toggleMute, "Mute or unmute", symbol: "speaker.slash", iconOnly: true)
                control(.volumeUp, "Volume up", symbol: "speaker.plus", iconOnly: true)
                control(.playPause, "Play or pause", symbol: "playpause.fill", iconOnly: true)
            }
            if family == .systemLarge {
                HStack(spacing: 6) {
                    control(.back, "Back 10s", symbol: "gobackward.10")
                    control(.forward, "Forward 10s", symbol: "goforward.10")
                }
                HStack(spacing: 6) {
                    control(.normalSound, "Normal sound")
                    control(.music, "Music sound")
                }
                Text("Controls the car player during an active ScreenLink session.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.05, green: 0.09, blue: 0.12),
                                    Color(red: 0.08, green: 0.25, blue: 0.23)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
