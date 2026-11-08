import ActivityKit
import SwiftUI
import WidgetKit

private let startURL = URL(string: "screenlink://start-youtube")!
private let resumeURL = URL(string: "screenlink://resume")!

private enum Mascot: String {
    case dog, cat, roadster
    var title: String { switch self { case .dog: return "Dog"; case .cat: return "Cat"; case .roadster: return "Roadster" } }
    var emoji: String { switch self { case .dog: return "🐕"; case .cat: return "🐈"; case .roadster: return "🏎️" } }
    var tint: Color { switch self { case .dog: return .orange; case .cat: return .mint; case .roadster: return .red } }
}

private struct LauncherEntry: TimelineEntry { let date: Date }
private struct LauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> LauncherEntry { LauncherEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (LauncherEntry) -> Void) { completion(LauncherEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LauncherEntry>) -> Void) {
        completion(Timeline(entries: [LauncherEntry(date: Date())], policy: .never))
    }
}

private struct LauncherView: View {
    let mascot: Mascot
    @Environment(\.widgetFamily) var family
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("ScreenLink").font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: "airplayvideo").foregroundStyle(mascot.tint)
            }
            HStack(alignment: .center) {
                Text(mascot.emoji).font(.system(size: family == .systemMedium ? 56 : 42))
                if family == .systemMedium {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mascot.title == "Roadster" ? "ROADSTER" : "YOUR CO-PILOT").font(.caption2.bold()).foregroundStyle(mascot.tint)
                        Text("YouTube only").font(.title3.bold())
                        Text("Local hotspot · no recording").font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack {
                Image(systemName: "play.fill")
                Text("Start YouTube").fontWeight(.semibold)
            }.font(.subheadline).foregroundStyle(.white)
            if family == .systemSmall { Text("No screen recording").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)) }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.14), mascot.tint.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(startURL)
        .accessibilityLabel("ScreenLink \(mascot.title). Start YouTube only, without screen recording.")
    }
}

private func launcherConfiguration(_ mascot: Mascot, displayName: LocalizedStringKey) -> some WidgetConfiguration {
    StaticConfiguration(kind: "ScreenLink.Launch.\(mascot.rawValue)", provider: LauncherProvider()) { _ in LauncherView(mascot: mascot) }
        .configurationDisplayName(displayName)
        .description("Tap to open ScreenLink and start YouTube only. Personal Hotspot must already be enabled.")
        .supportedFamilies([.systemSmall, .systemMedium])
}
// WidgetKit constructs each widget with init(); use distinct zero-argument types.
private struct DogLauncherWidget: Widget {
    var body: some WidgetConfiguration { launcherConfiguration(.dog, displayName: "ScreenLink · Dog") }
}
private struct CatLauncherWidget: Widget {
    var body: some WidgetConfiguration { launcherConfiguration(.cat, displayName: "ScreenLink · Cat") }
}
private struct RoadsterLauncherWidget: Widget {
    var body: some WidgetConfiguration { launcherConfiguration(.roadster, displayName: "ScreenLink · Roadster") }
}

private let stopURL = URL(string: "screenlink://disconnect-all")!
private let openURL = URL(string: "screenlink://open")!

private struct ActionPill: View {
    let title: String
    let symbol: String
    let url: URL
    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: symbol)
                .font(.caption.bold()).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(.white.opacity(0.12), in: Capsule())
        }.foregroundStyle(.white)
    }
}
private struct QuickActions: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                ActionPill(title: "Start", symbol: "play.fill", url: startURL)
                ActionPill(title: "Resume PiP", symbol: "pip.enter", url: resumeURL)
            }
            HStack(spacing: 7) {
                ActionPill(title: "Open app", symbol: "arrow.up.forward.app", url: openURL)
                ActionPill(title: "Disconnect", symbol: "power", url: stopURL)
            }
        }
    }
}
private struct ControlsView: View {
    @Environment(\.widgetFamily) var family
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.side").foregroundStyle(.mint)
                Text("ScreenLink").font(.headline)
                Spacer(minLength: 0)
            }
            if family == .systemSmall {
                Text("Your video.\nA bigger view.").font(.title3.bold())
                Spacer(minLength: 0)
                Label("Open controls", systemImage: "arrow.up.forward.app").font(.caption.bold()).foregroundStyle(.mint)
            } else {
                if family == .systemLarge {
                    Text("Ready when you are").font(.title2.bold())
                    Text("Hotspot → YouTube AirPlay → return for PiP").font(.caption).foregroundStyle(.white.opacity(0.7))
                    Spacer(minLength: 0)
                }
                QuickActions()
                Text("Actions open ScreenLink · no recording").font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { LinearGradient(colors: [Color(red: 0.06, green: 0.10, blue: 0.12), Color(red: 0.08, green: 0.26, blue: 0.24)], startPoint: .topLeading, endPoint: .bottomTrailing) }
        .widgetURL(openURL)
    }
}
private struct ScreenLinkControlsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScreenLink.Controls", provider: LauncherProvider()) { _ in ControlsView() }
            .configurationDisplayName("ScreenLink Controls")
            .description("Start, resume PiP, open ScreenLink or disconnect all. Actions open the app; iOS consent may be required.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
private struct ResumeView: View {
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            if family == .accessoryCircular {
                Image(systemName: "pip.enter").font(.title2)
            } else {
                VStack(alignment: .leading) {
                    Label("ScreenLink", systemImage: "pip.enter").font(.headline)
                    Text("Resume PiP").font(.caption)
                }
            }
        }.containerBackground(for: .widget) { Color.clear }
         .widgetURL(resumeURL)
         .accessibilityLabel("Open ScreenLink and resume the selected PiP session")
    }
}
private struct ResumeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScreenLink.Resume", provider: LauncherProvider()) { _ in ResumeView() }
            .configurationDisplayName("ScreenLink Resume PiP")
            .description("Open ScreenLink to resume your selected floating video session.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// Build 85 "ScreenLink Mission": original characters (no third-party characters or logos).
// iOS animates the island only on state changes and through self-running timers, so the
// stage changes slide in with transitions and the countdown / video ring run by themselves.
private struct MissionTheme {
    let cruise: String, name: String
    static let all = [MissionTheme(cruise: "🚀", name: "Rocket"), MissionTheme(cruise: "🛸", name: "UFO"),
                      MissionTheme(cruise: "🏎️", name: "Roadster"), MissionTheme(cruise: "☄️", name: "Comet")]
    static func of(_ index: Int?) -> MissionTheme { all[((index ?? 0) % all.count + all.count) % all.count] }
}

private struct Mission {
    let state: ScreenLinkActivityAttributes.ContentState
    let stale: Bool
    var stage: String { stale ? "landed" : (state.stage ?? (state.running ? "cruise" : "landed")) }
    var theme: MissionTheme { MissionTheme.of(state.theme) }
    var icon: String {
        switch stage {
        case "countdown": return theme.cruise
        case "liftoff": return "🔥"
        case "paused": return "🛰️"
        case "signal": return "📡"
        case "landed": return "🪂"
        default: return theme.cruise
        }
    }
    var title: String {
        switch stage {
        case "countdown": return "Countdown"
        case "liftoff": return "Liftoff!"
        case "paused": return "Hovering · paused"
        case "signal": return "Signal lost"
        case "landed": return stale ? "Open ScreenLink" : "Landed"
        default: return "\(theme.name) in orbit"
        }
    }
    var color: Color {
        switch stage {
        case "liftoff": return .orange
        case "signal": return .orange
        case "paused": return .yellow
        case "landed": return .gray
        case "countdown": return .cyan
        default: return .mint
        }
    }
    var playing: Bool { (stage == "cruise" || stage == "liftoff") && state.videoStart != nil && state.videoEnd != nil }
}

private struct MissionIcon: View {
    let mission: Mission
    var size: CGFloat = 20
    var body: some View {
        Text(mission.icon)
            .font(.system(size: size))
            .id("\(mission.stage)-\(mission.state.theme ?? 0)")
            .transition(.push(from: .bottom))
            .accessibilityLabel(mission.title)
    }
}

private struct MissionRing: View {
    let mission: Mission
    var body: some View {
        Group {
            if mission.playing, let start = mission.state.videoStart, let end = mission.state.videoEnd, end > start {
                ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.circular)
            } else if mission.stage == "paused" {
                ProgressView(value: mission.state.progress ?? 0).progressViewStyle(.circular)
            } else if mission.stage == "countdown", let end = mission.state.countdownEnd, end > Date() {
                Text(timerInterval: Date()...end, countsDown: true).monospacedDigit().font(.caption2.bold()).frame(width: 34)
            } else {
                Text(mission.stage == "signal" ? "!" : mission.stage == "landed" ? "■" : "•").font(.caption2.bold())
            }
        }
        .tint(mission.color)
        .foregroundStyle(mission.color)
    }
}

private struct MissionTrack: View {
    let mission: Mission
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if mission.playing, let start = mission.state.videoStart, let end = mission.state.videoEnd, end > start {
                ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(mission.color)
                HStack {
                    Text("✦ · ✧ · ✦").font(.caption2).foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text(timerInterval: Date()...end, countsDown: true).font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
                }
            } else if mission.stage == "paused" {
                ProgressView(value: mission.state.progress ?? 0).tint(mission.color)
            } else if mission.stage == "countdown", let end = mission.state.countdownEnd, end > Date() {
                HStack(spacing: 4) {
                    Text("T-").font(.caption.bold())
                    Text(timerInterval: Date()...end, countsDown: true).font(.caption.bold().monospacedDigit())
                    Spacer()
                    Text("Waiting for YouTube").font(.caption2).foregroundStyle(.white.opacity(0.7))
                }.foregroundStyle(mission.color)
            } else {
                Text(mission.stage == "signal" ? "Car not reachable · retrying" : mission.state.status).font(.caption2).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
            }
        }
    }
}

private struct ScreenLinkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenLinkActivityAttributes.self) { context in
            let mission = Mission(state: context.state, stale: context.isStale)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    MissionIcon(mission: mission, size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ScreenLink Mission").font(.caption.bold()).foregroundStyle(.white.opacity(0.7))
                        Text(mission.title).font(.headline).foregroundStyle(mission.color)
                            .contentTransition(.opacity)
                    }
                    Spacer()
                    MissionRing(mission: mission).frame(width: 30, height: 30)
                }
                MissionTrack(mission: mission)
                QuickActions()
            }
            .padding(16)
            .animation(.spring(duration: 0.8), value: mission.stage)
            .activityBackgroundTint(Color(red: 0.03, green: 0.05, blue: 0.12))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .widgetURL(resumeURL)
        } dynamicIsland: { context in
            let mission = Mission(state: context.state, stale: context.isStale)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MissionIcon(mission: mission, size: 38).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MissionRing(mission: mission).frame(width: 34, height: 34).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text("ScreenLink Mission").font(.caption2).foregroundStyle(.white.opacity(0.6))
                        Text(mission.title).font(.headline).foregroundStyle(mission.color).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        MissionTrack(mission: mission)
                        QuickActions()
                    }
                }
            } compactLeading: {
                MissionIcon(mission: mission, size: 16)
            } compactTrailing: {
                MissionRing(mission: mission).frame(width: 18, height: 18)
            } minimal: {
                MissionIcon(mission: mission, size: 15)
            }
            .widgetURL(resumeURL)
            .keylineTint(mission.color)
        }
    }
}

@main
struct ScreenLinkWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarPlayerWidget()
        ScreenLinkControlsWidget()
        ResumeWidget()
        DogLauncherWidget()
        CatLauncherWidget()
        RoadsterLauncherWidget()
        ScreenLinkLiveActivity()
        if #available(iOS 18.0, *) {
            ScreenLinkSessionControl()
            CarPlayPauseControl()
            CarMuteControl()
        }
    }
}

