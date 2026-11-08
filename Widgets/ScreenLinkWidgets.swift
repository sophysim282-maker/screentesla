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

private struct MotionBadge: View {
    let phase: Int
    var body: some View {
        Image(systemName: "car.side.fill")
            .foregroundStyle(.mint)
            .accessibilityLabel("ScreenLink Roadster")
    }
}

private struct ScreenLinkLiveActivity: Widget {
    private func label(_ context: ActivityViewContext<ScreenLinkActivityAttributes>) -> String {
        context.isStale ? "Open ScreenLink" : context.state.status
    }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenLinkActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ScreenLink · YouTube").font(.headline)
                    Text(label(context)).font(.subheadline).foregroundStyle(context.isStale ? .orange : .mint)
                    Text("Local hotspot · no recording").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 5) {
                    MotionBadge(phase: context.state.phase).font(.title2)
                    if context.state.running && !context.isStale { Text(context.state.started, style: .timer).font(.caption.monospacedDigit()) }
                }
                }
                QuickActions()
            }.padding(16)
            .activityBackgroundTint(Color(red: 0.04, green: 0.07, blue: 0.13))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .widgetURL(resumeURL)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("ScreenLink").font(.headline)
                        Text("YouTube only").font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MotionBadge(phase: context.state.phase).font(.title3)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                    HStack {
                        Image(systemName: context.state.running && !context.isStale ? "airplayvideo" : "pause.circle")
                        Text(label(context)).font(.caption.bold())
                        Spacer()
                        if context.state.running && !context.isStale { Text(context.state.started, style: .timer).font(.caption.monospacedDigit()) }
                    }
                    QuickActions()
                    }
                }
            } compactLeading: {
                Text("🏎️").accessibilityLabel("ScreenLink Roadster")
            } compactTrailing: {
                Text(context.isStale ? "!" : (context.state.running ? "YT" : "Ⅱ")).font(.caption2.bold()).foregroundStyle(.mint)
            } minimal: {
                Image(systemName: "car.side.fill").accessibilityLabel("ScreenLink")
            }
            .widgetURL(resumeURL)
            .keylineTint(.mint)
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

