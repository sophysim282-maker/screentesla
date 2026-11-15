import SwiftUI
import WidgetKit

// Build 147: map widget, in the style of Apple Maps widgets. Google map picture of where you are (made by
// the ScreenLink app from the same map squares as the car), your route in blue, a big next-turn card and
// your arrival time. iOS decides how often a widget may refresh (about once a minute at most while driving).

private let mapsURL = URL(string: "screenlink://maps")!

struct MapWidgetInfo: Decodable {
    var navigating: Bool
    var distance: String
    var instruction: String
    var maneuver: String
    var arrival: String
    var eta: String
    var remaining: String
    var playing: Bool
    var position: Double
    var image: String?
}

struct MapWidgetEntry: TimelineEntry {
    let date: Date
    let info: MapWidgetInfo?
    let picture: UIImage?
}

private enum MapWidgetConnection {
    static func load() async -> (MapWidgetInfo?, UIImage?) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 8
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8080/local/widget/map")!, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("app", forHTTPHeaderField: "X-ScreenLink-Control")
        guard let (body, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let info = try? JSONDecoder().decode(MapWidgetInfo.self, from: body) else { return (nil, nil) }
        let picture = info.image.flatMap { Data(base64Encoded: $0) }.flatMap { UIImage(data: $0) }
        return (info, picture)
    }
}

struct MapWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> MapWidgetEntry {
        MapWidgetEntry(date: Date(), info: MapWidgetInfo(navigating: true, distance: "200 m", instruction: "Turn right onto Norodom Blvd",
                                                         maneuver: "turn-right", arrival: "14:32", eta: "12 min", remaining: "4.3 km",
                                                         playing: true, position: 760, image: nil), picture: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (MapWidgetEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        Task { let (info, picture) = await MapWidgetConnection.load(); completion(MapWidgetEntry(date: Date(), info: info, picture: picture)) }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MapWidgetEntry>) -> Void) {
        Task {
            let (info, picture) = await MapWidgetConnection.load()
            let next = Date().addingTimeInterval(info?.navigating == true ? 60 : (info == nil ? 900 : 300))
            completion(Timeline(entries: [MapWidgetEntry(date: Date(), info: info, picture: picture)], policy: .after(next)))
        }
    }
}

struct MapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ScreenLink.Map", provider: MapWidgetProvider()) { entry in
            MapWidgetView(entry: entry)
        }
        .configurationDisplayName("ScreenLink Map")
        .description("Where you are, your route and the next turn.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

/// Google's turn names → SF Symbols.
private func turnSymbol(_ maneuver: String) -> String {
    let m = maneuver.lowercased()
    if m.contains("uturn") || m.contains("u-turn") { return "arrow.uturn.down" }
    if m.contains("roundabout") { return "arrow.triangle.turn.up.right.circle" }
    if m.contains("sharp") && m.contains("left") { return "arrow.turn.left.down" }
    if m.contains("sharp") && m.contains("right") { return "arrow.turn.right.down" }
    if m.contains("slight") && m.contains("left") || m.contains("keep-left") || m.contains("fork-left") { return "arrow.up.left" }
    if m.contains("slight") && m.contains("right") || m.contains("keep-right") || m.contains("fork-right") { return "arrow.up.right" }
    if m.contains("left") { return "arrow.turn.up.left" }
    if m.contains("right") { return "arrow.turn.up.right" }
    if m.contains("destination") || m.contains("arrive") { return "mappin.circle.fill" }
    return "arrow.up"
}

private func clock(_ seconds: Double) -> String {
    let total = max(0, Int(seconds)); let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

private struct Chip: View {
    let text: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.system(size: 11, weight: .bold)) }
            Text(text).font(.system(size: 14, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
    }
}

struct MapWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MapWidgetEntry

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 0) {
                topCard
                Spacer(minLength: 0)
                bottomRow
            }
            .padding(10)
        }
        .containerBackground(for: .widget) { Color(white: 0.93) }
        .widgetURL(mapsURL)
    }

    @ViewBuilder private var background: some View {
        if let picture = entry.picture {
            Image(uiImage: picture).resizable().scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        } else {
            LinearGradient(colors: [Color(red: 0.86, green: 0.92, blue: 0.86), Color(red: 0.93, green: 0.92, blue: 0.88)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(Image(systemName: "map").font(.system(size: 54, weight: .light)).foregroundStyle(.black.opacity(0.12)))
        }
    }

    @ViewBuilder private var topCard: some View {
        let info = entry.info
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(info?.navigating == true ? Color(red: 0.04, green: 0.52, blue: 1) : Color(white: 0.55))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: info?.navigating == true ? turnSymbol(info?.maneuver ?? "") : (info == nil ? "power" : "location.fill"))
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 22, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(Color(white: 0.25)).lineLimit(family == .systemLarge ? 2 : 1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.black)
        .padding(10)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }

    private var title: String {
        guard let info = entry.info else { return "ScreenLink" }
        if info.navigating { return info.distance.isEmpty ? "Go" : info.distance }
        return "Where you are"
    }
    private var subtitle: String {
        guard let info = entry.info else { return "Open ScreenLink to see the map" }
        if info.navigating { return info.instruction.isEmpty ? "Follow the route" : info.instruction }
        return "Tap to plan a route"
    }

    @ViewBuilder private var bottomRow: some View {
        if let info = entry.info {
            HStack(spacing: 6) {
                if family == .systemLarge && info.playing { Chip(text: "Car " + clock(info.position), symbol: "play.fill") }
                Spacer(minLength: 0)
                if info.navigating {
                    if family == .systemLarge, !info.arrival.isEmpty { Chip(text: "Arrive " + info.arrival) }
                    else { Chip(text: [info.eta, info.remaining].filter { !$0.isEmpty }.joined(separator: " · ")) }
                }
            }
        }
    }
}
