import ActivityKit
import SwiftUI
import WidgetKit

private let cyan = Color(red: 0.20, green: 0.88, blue: 0.98)

@main
struct ScreenLinkIslandBundle: WidgetBundle {
    var body: some Widget { ScreenLinkIsland() }
}

struct ScreenLinkIsland: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScreenLinkActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "display")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Text("ScreenLink").font(.headline).foregroundStyle(.white)
                    Text(context.isStale ? "Open ScreenLink to refresh" : context.state.status)
                        .font(.subheadline).foregroundStyle(cyan)
                    privacy(context)
                }
                Spacer(minLength: 8)
                timer(context).font(.system(.title3, design: .rounded))
            }
            .padding(18)
            .activityBackgroundTint(Color(red: 0.035, green: 0.055, blue: 0.08))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("ScreenLink", systemImage: "display")
                        .font(.headline).foregroundStyle(cyan)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context).font(.system(.headline, design: .rounded))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label(
                            context.isStale ? "Refresh needed" : context.state.status,
                            systemImage: context.isStale ? "arrow.clockwise" :
                                (context.state.streaming ? "play.circle.fill" : "circle.fill")
                        ).foregroundStyle(cyan)
                        Spacer(minLength: 8)
                        privacy(context)
                    }
                    .font(.caption.weight(.medium)).padding(.top, 8)
                }
            } compactLeading: {
                Image(systemName: context.isStale ? "arrow.clockwise" : "display")
                    .foregroundStyle(cyan)
                    .accessibilityLabel(context.isStale ? "ScreenLink needs refresh" : "ScreenLink")
            } compactTrailing: {
                timer(context)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 52).foregroundStyle(cyan)
            } minimal: {
                Image(systemName: context.isStale ? "arrow.clockwise" : "display")
                    .foregroundStyle(cyan)
            }
            .keylineTint(cyan)
        }
    }

    @ViewBuilder
    private func timer(_ context: ActivityViewContext<ScreenLinkActivityAttributes>) -> some View {
        if context.isStale {
            Text("—").foregroundStyle(.secondary)
        } else {
            Text(context.attributes.startedAt, style: .timer)
                .monospacedDigit().foregroundStyle(.white)
        }
    }

    private func privacy(_ context: ActivityViewContext<ScreenLinkActivityAttributes>) -> some View {
        Label(
            context.isStale ? "Status unconfirmed" :
                (context.state.screenVisible ? "Screen visible" : "Screen hidden"),
            systemImage: context.isStale ? "questionmark.circle" :
                (context.state.screenVisible ? "eye" : "eye.slash")
        )
        .font(.caption)
        .foregroundStyle(.white.opacity(0.75))
    }
}
