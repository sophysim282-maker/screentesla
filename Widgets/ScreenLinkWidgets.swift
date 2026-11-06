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

private func launcherConfiguration(_ mascot: Mascot) -> some WidgetConfiguration {
    StaticConfiguration(kind: "ScreenLink.Launch.\(mascot.rawValue)", provider: LauncherProvider()) { _ in LauncherView(mascot: mascot) }
        .configurationDisplayName("ScreenLink · \(mascot.title)")
        .description("Tap to open ScreenLink and start YouTube only. Personal Hotspot must already be enabled.")
        .supportedFamilies([.systemSmall, .systemMedium])
}
// WidgetKit constructs each widget with init(); use distinct zero-argument types.
private struct DogLauncherWidget: Widget {
    var body: some WidgetConfiguration { launcherConfiguration(.dog) }
}
private struct CatLauncherWidget: Widget {
    var body: some WidgetConfiguration { launcherConfiguration(.cat) }
}
private struct RoadsterLauncherWidget: Widget {
    var body: some WidgetConfiguration { launcherConfiguration(.roadster) }
}

private struct ControlsView: View {
    @Environment(\.widgetFamily) var family
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "airplayvideo").foregroundStyle(.mint)
                Text("ScreenLink").font(.headline)
                Spacer(minLength: 0)
            }
            Text("A bigger view").font(.title3.bold())
            Text("Open the app to control sharing").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if family == .systemMedium {
                HStack(spacing: 12) {
                    Link(destination: startURL) { Label("Start + PiP", systemImage: "play.fill").font(.subheadline.bold()).padding(10).frame(maxWidth: .infinity).background(Color(red: 0.02, green: 0.38, blue: 0.4), in: RoundedRectangle(cornerRadius: 12)) }
                    Link(destination: URL(string: "screenlink://disconnect-all")!) { Label("Disconnect All", systemImage: "power").font(.subheadline.bold()).padding(10).frame(maxWidth: .infinity).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)) }
                }.foregroundStyle(.white)
            } else {
                Label("Open controls", systemImage: "arrow.up.forward.app").font(.subheadline.bold()).foregroundStyle(.mint)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { LinearGradient(colors: [Color(red: 0.025, green: 0.065, blue: 0.13), Color(red: 0.03, green: 0.24, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing) }
        .widgetURL(resumeURL)
    }
}
private struct ScreenLinkControlsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScreenLink.Controls", provider: LauncherProvider()) { _ in ControlsView() }
            .configurationDisplayName("ScreenLink Controls")
            .description("Start YouTube + PiP or disconnect all ScreenLink sharing. Controls open the app; iOS consent may be required.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct MotionBadge: View {
    let phase: Int
    var body: some View {
        HStack(spacing: 6) {
            Text("🐕").offset(y: phase.isMultiple(of: 2) ? 0 : -3)
            Text("🐈").offset(y: phase.isMultiple(of: 2) ? -3 : 0)
            Text("🏎️").rotationEffect(.degrees(phase.isMultiple(of: 2) ? -5 : 5))
        }
        .animation(.easeInOut(duration: 0.8), value: phase)
        .accessibilityLabel("Dog, cat and Roadster")
    }
}

private struct ScreenLinkLiveActivity: Widget {
    private func label(_ context: ActivityViewContext<ScreenLinkActivityAttributes>) -> String {
        context.isStale ? "Open ScreenLink" : context.state.status
    }
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenLinkActivityAttributes.self) { context in
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
                    HStack {
                        Image(systemName: context.state.running && !context.isStale ? "airplayvideo" : "pause.circle")
                        Text(label(context)).font(.caption.bold())
                        Spacer()
                        if context.state.running && !context.isStale { Text(context.state.started, style: .timer).font(.caption.monospacedDigit()) }
                    }
                }
            } compactLeading: {
                Text("🏎️").accessibilityLabel("ScreenLink Roadster")
            } compactTrailing: {
                Text(context.isStale ? "!" : (context.state.running ? "YT" : "Ⅱ")).font(.caption2.bold()).foregroundStyle(.mint)
            } minimal: {
                Text(context.state.phase.isMultiple(of: 2) ? "🐕" : "🐈")
            }
            .widgetURL(resumeURL)
            .keylineTint(.mint)
        }
    }
}

@main
struct ScreenLinkWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScreenLinkControlsWidget()
        DogLauncherWidget()
        CatLauncherWidget()
        RoadsterLauncherWidget()
        ScreenLinkLiveActivity()
    }
}
