import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

/// Build 115: "My waiting screen". The user picks pictures, GIFs or short videos from Photos. They are
/// kept inside ScreenLink and shown on the car while no video plays and while a video is loading, with
/// a chosen transition into and out of the YouTube picture. Files only travel phone → car on the
/// private link (/waiting/list and /waiting/item/<id>, served by Receiver.m with the viewer's token).
@objc(SLWaitingStore)
final class SLWaitingStore: NSObject {
    struct Item: Codable, Identifiable, Equatable {
        let id: String
        let kind: String     // image | gif | video
        let mime: String
        let file: String
    }

    static let transitions = [("fade", "Fade"), ("zoom", "Zoom"), ("slide", "Slide"), ("flash", "Flash"), ("dip", "Dark dip")]
    private static let lock = NSLock()
    private static let defaults = UserDefaults.standard

    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("WaitingScreen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var items: [Item] {
        get { (defaults.data(forKey: "waitingItems")).flatMap { try? JSONDecoder().decode([Item].self, from: $0) } ?? [] }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "waitingItems"); changed() }
    }
    static var transition: String {
        get { defaults.string(forKey: "waitingTransition") ?? "fade" }
        set { defaults.set(newValue, forKey: "waitingTransition"); changed() }
    }
    static var fit: String {
        get { defaults.string(forKey: "waitingFit") ?? "fill" }
        set { defaults.set(newValue, forKey: "waitingFit"); changed() }
    }
    static var hold: Int {
        get { let v = defaults.integer(forKey: "waitingHold"); return v == 0 ? 8 : v }
        set { defaults.set(max(3, min(60, newValue)), forKey: "waitingHold"); changed() }
    }
    /// Goes up on every change, so the car loads the new files and settings.
    static var version: Int { defaults.integer(forKey: "waitingVersion") }
    private static func changed() { defaults.set(version + 1, forKey: "waitingVersion") }

    static func remove(_ item: Item) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(item.file))
        items = items.filter { $0 != item }
    }

    // MARK: - Used by the Home screen (main.m)

    /// One grey line for the Home list.
    @objc static func summary() -> String {
        let count = items.count
        guard count > 0 else { return "Your pictures, GIFs and videos" }
        let name = transitions.first { $0.0 == transition }?.1 ?? "Fade"
        return "\(count) file\(count == 1 ? "" : "s") · \(name)"
    }
    @objc static func versionNumber() -> Int { version }
    /// The first chosen picture, for the big picture on Home. Empty when there is none.
    @objc static func firstPicture() -> Data {
        guard let first = items.first(where: { $0.kind == "image" }) else { return Data() }
        return (try? Data(contentsOf: folder.appendingPathComponent(first.file))) ?? Data()
    }

    // MARK: - Used by Receiver.m (any thread)

    @objc static func listData() -> Data {
        lock.lock(); defer { lock.unlock() }
        let list: [String: Any] = [
            "v": version, "transition": transition, "fit": fit, "hold": hold,
            "items": items.map { ["id": $0.id, "kind": $0.kind, "mime": $0.mime] },
        ]
        return (try? JSONSerialization.data(withJSONObject: list)) ?? Data("{}".utf8)
    }

    @objc(item:) static func item(_ id: String) -> [String: Any] {
        lock.lock(); let found = items.first { $0.id == id }; lock.unlock()
        guard let found, let data = try? Data(contentsOf: folder.appendingPathComponent(found.file), options: .mappedIfSafe) else { return [:] }
        return ["data": data, "mime": found.mime]
    }
}

@objc(SLWaitingLauncher)
final class SLWaitingLauncher: NSObject {
    @objc static func controller() -> UIViewController {
        let made = UIHostingController(rootView: WaitingScreenView())
        made.modalPresentationStyle = .formSheet
        return made
    }
}

/// A picked video arrives as a file, never as one big block of memory.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + (received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension))
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

struct WaitingScreenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items = SLWaitingStore.items
    @State private var picked: [PhotosPickerItem] = []
    @State private var transition = SLWaitingStore.transition
    @State private var fit = SLWaitingStore.fit
    @State private var hold = SLWaitingStore.hold
    @State private var working = false
    @State private var note = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Your waiting screen") {
                    if items.isEmpty {
                        Text("Nothing chosen. The car shows the normal screen while it waits.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    ForEach(items) { item in
                        HStack {
                            Image(systemName: item.kind == "video" ? "film" : item.kind == "gif" ? "sparkles.rectangle.stack" : "photo")
                            Text(item.kind == "video" ? "Video" : item.kind == "gif" ? "GIF" : "Picture")
                            Spacer()
                            Button(role: .destructive) { SLWaitingStore.remove(item); items = SLWaitingStore.items } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                    PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .any(of: [.images, .videos])) {
                        Label(working ? "Preparing…" : "Add pictures, GIFs or videos", systemImage: "plus.circle.fill")
                    }
                    .disabled(working)
                    if !note.isEmpty { Text(note).font(.footnote).foregroundColor(.orange) }
                    if !items.isEmpty {
                        Button("Use the normal screen (remove all)", role: .destructive) {
                            for item in items { SLWaitingStore.remove(item) }
                            items = []
                        }
                    }
                }
                Section("How it changes to the video") {
                    Picker("Transition", selection: $transition) {
                        ForEach(SLWaitingStore.transitions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("Picture size", selection: $fit) {
                        Text("Fill the screen").tag("fill")
                        Text("Show all of it").tag("fit")
                    }
                    Stepper("Each file shows \(hold) seconds", value: $hold, in: 3...60)
                }
                Section {
                    Text("Shown on the car while no video plays and while a video is loading. Videos are cut to 15 seconds, made 720p and play without sound. The files stay on this iPhone and go only to your car.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Waiting screen")
            .toolbar { Button("Done") { dismiss() } }
        }
        .onChange(of: transition) { SLWaitingStore.transition = $0 }
        .onChange(of: fit) { SLWaitingStore.fit = $0 }
        .onChange(of: hold) { SLWaitingStore.hold = $0 }
        .onChange(of: picked) { chosen in
            guard !chosen.isEmpty else { return }
            working = true
            note = ""
            Task {
                var problems: [String] = []
                for one in chosen {
                    if let problem = await add(one) { problems.append(problem) }
                }
                await MainActor.run {
                    items = SLWaitingStore.items
                    picked = []
                    working = false
                    note = problems.joined(separator: " ")
                }
            }
        }
    }

    /// Copies one picked file into the app in a light form. Returns a sentence when it could not.
    private func add(_ picked: PhotosPickerItem) async -> String? {
        let types = picked.supportedContentTypes
        let id = UUID().uuidString
        let folder = SLWaitingStore.folder
        do {
            if types.contains(where: { $0.conforms(to: .movie) }) {
                guard let movie = try await picked.loadTransferable(type: PickedMovie.self) else { return "A video could not be read." }
                defer { try? FileManager.default.removeItem(at: movie.url) }
                let asset = AVURLAsset(url: movie.url)
                guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { return "A video could not be prepared." }
                let target = folder.appendingPathComponent(id + ".mp4")
                export.outputURL = target
                export.outputFileType = .mp4
                export.shouldOptimizeForNetworkUse = true
                let length = try await asset.load(.duration)
                export.timeRange = CMTimeRange(start: .zero, duration: CMTimeMinimum(length, CMTime(seconds: 15, preferredTimescale: 600)))
                await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in export.exportAsynchronously { done.resume() } }
                guard export.status == .completed else { return "A video could not be prepared (\(export.error?.localizedDescription ?? "unknown"))." }
                SLWaitingStore.items = SLWaitingStore.items + [.init(id: id, kind: "video", mime: "video/mp4", file: id + ".mp4")]
                return nil
            }
            guard let data = try await picked.loadTransferable(type: Data.self) else { return "A picture could not be read." }
            if types.contains(where: { $0.conforms(to: .gif) }) || data.prefix(4) == Data("GIF8".utf8) {
                guard data.count <= 20 * 1024 * 1024 else { return "A GIF is larger than 20 MB and was skipped." }
                try data.write(to: folder.appendingPathComponent(id + ".gif"))
                SLWaitingStore.items = SLWaitingStore.items + [.init(id: id, kind: "gif", mime: "image/gif", file: id + ".gif")]
                return nil
            }
            guard let image = UIImage(data: data) else { return "A picture could not be opened." }
            let longest = max(image.size.width, image.size.height) * image.scale
            let scale = min(1, 1920 / max(1, longest))
            let size = CGSize(width: image.size.width * image.scale * scale, height: image.size.height * image.scale * scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let jpeg = small.jpegData(compressionQuality: 0.85) else { return "A picture could not be saved." }
            try jpeg.write(to: folder.appendingPathComponent(id + ".jpg"))
            SLWaitingStore.items = SLWaitingStore.items + [.init(id: id, kind: "image", mime: "image/jpeg", file: id + ".jpg")]
            return nil
        } catch {
            return "A file could not be added (\(error.localizedDescription))."
        }
    }
}
