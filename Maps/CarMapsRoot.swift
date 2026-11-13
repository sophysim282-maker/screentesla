import SwiftUI
import UIKit
import GoogleMaps

// Build 87: Car Maps screens inside ScreenLink, opened from the Home "Navigation map" button.
// The controller is created once and kept, so navigation keeps running (and the rear-seat
// screen keeps its small map) after you close it and go back to ScreenLink Home.

/// The Google API key is typed into the app once (never stored in GitHub).
final class KeyStore: ObservableObject {
    @Published var ready = false
    private(set) var key = ""

    init() {
        if let saved = UserDefaults.standard.string(forKey: "googleKey"), !saved.isEmpty { use(saved) }
    }

    func use(_ k: String) {
        let k = k.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return }
        UserDefaults.standard.set(k, forKey: "googleKey")
        key = k
        GMSServices.provideAPIKey(k)
        ready = true
    }
}

struct KeySetupView: View {
    @ObservedObject var keyStore: KeyStore
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ScreenLink Maps 🗺️").font(.largeTitle.bold())
            Text("Paste your Google Maps API key. You only do this once.")
            TextField("AIza...", text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Save") { keyStore.use(text) }
                .buttonStyle(.borderedProminent)
            Text("The key needs: Maps SDK for iOS, Routes API, Places API (New).")
                .font(.footnote).foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

/// Build 131: shared between the map screen and the drive screen (Google Maps style: while driving there
/// is no top bar; the back button and the car-map switch become round buttons on the right).
final class NavUI: ObservableObject {
    static let shared = NavUI()
    @Published var guiding = false
    var close: () -> Void = {}
}

struct CarMapsRoot: View {
    @StateObject private var keyStore = KeyStore()
    @ObservedObject private var ui = NavUI.shared
    let close: () -> Void

    var body: some View {
        // Build 130: the back button and the car-map switch sit in their own bar above the map, so they
        // never cover the turn banner any more.
        VStack(spacing: 0) {
            if !ui.guiding {
            HStack(spacing: 8) {
                Button(action: close) {
                    Label("ScreenLink", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .accessibilityLabel("Back to ScreenLink. Navigation keeps running.")
                Spacer(minLength: 4)
                // Build 98: one switch for the small map on the car screen.
                CarMapSwitch()
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color.black)
            }
            if keyStore.ready {
                let _ = { NavUI.shared.close = close }()
                ContentView(apiKey: keyStore.key)
            } else {
                KeySetupView(keyStore: keyStore)
            }
        }
    }
}

struct CarMapSwitch: View {
    @State private var on = CarLink.carMapOn
    @State private var works = false
    @State private var problem = ""
    @State private var showFix = false
    @State private var google = CarLink.carGoogle
    @State private var picture = ""
    @State private var showPicture = false
    @State private var tiles = ""
    @State private var showTiles = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            Button {
                on.toggle(); CarLink.carMapOn = on
            } label: {
                Label(on ? "Car map ON" : "Car map OFF", systemImage: on ? "map.fill" : "map")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(on ? Color.green.opacity(0.85) : Color.gray.opacity(0.6), in: Capsule())
                    .foregroundColor(.white)
            }
            .accessibilityLabel(on ? "Car map is on. Tap to hide the map on the car screen." : "Car map is off. Tap to show the map on the car screen.")
            // Build 104: by default the map on the car is pictures from this iPhone (no Google on the car).
            // Say plainly when the picture for "app left / phone locked" cannot be fetched.
            if on && !google && !tiles.isEmpty {
                Button { showTiles = true } label: {
                    Text("Car map problem · Tap")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange, in: Capsule())
                        .foregroundColor(.white)
                }
            } else if on && !google && works {
                Text("Car map ✓")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.85), in: Capsule())
                    .foregroundColor(.white)
            } else if on && !google && !picture.isEmpty {
                Button { showPicture = true } label: {
                    Text("Car map problem · Tap")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange, in: Capsule())
                        .foregroundColor(.white)
                }
            } else if on && google && works {
                Text("Car map ✓")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.85), in: Capsule())
                    .foregroundColor(.white)
            } else if on && google && !problem.isEmpty {
                Button { showFix = true } label: {
                    Text("Car map problem · Tap")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange, in: Capsule())
                        .foregroundColor(.white)
                }
            }
        }
        .onReceive(tick) { _ in
            works = CarLink.carDrawsMap; problem = CarLink.carMapProblem
            google = CarLink.carGoogle; picture = CarLink.bgProblem; tiles = SLMapTiles.problem
        }
        .sheet(isPresented: $showTiles) { CarMapTilesSheet(problem: tiles) }
        .sheet(isPresented: $showFix) { CarMapKeySheet(problem: problem) }
        .sheet(isPresented: $showPicture) { CarMapPictureSheet(problem: picture) }
    }
}

/// Build 105: the fast car map needs "Map Tiles API" on the user's Google key.
struct CarMapTilesSheet: View {
    let problem: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("What is wrong") {
                    Text("For a fast map the car draws it itself from small map squares that this iPhone gets from Google. Google did not give them: \(problem)")
                    Text("Until this is fixed the car shows slow map pictures instead.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Fix (one time, on a computer)") {
                    Text("1. Open console.cloud.google.com.\n2. APIs & Services → Library → search \"Map Tiles API\" → Enable.\n3. APIs & Services → Credentials → open your key. If \"API restrictions\" lists APIs, add Map Tiles API and Save.\n4. Wait 5 minutes. The car map changes by itself.")
                        .font(.footnote)
                    Text("The car itself never contacts Google. Only this iPhone does.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Fix the car map")
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

/// Build 104: the map picture used while the app is not on screen needs "Maps Static API".
struct CarMapPictureSheet: View {
    let problem: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("What is wrong") {
                    Text("When you leave ScreenLink or lock the iPhone, the phone asks Google for one map picture and moves it with GPS for the car. Google did not give that picture: \(problem)")
                }
                Section("Fix (one time, on a computer)") {
                    Text("1. Open console.cloud.google.com.\n2. APIs & Services → Library → search \"Maps Static API\" → Enable.\n3. APIs & Services → Credentials → open your key. If \"API restrictions\" lists APIs, add Maps Static API and Save.\n4. Wait 5 minutes, then leave the app again and look at the car.")
                        .font(.footnote)
                    Text("The car itself never contacts Google. Only this iPhone does.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Fix the car map")
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

/// Build 101: paste a Google key that is allowed on the car website. Kept only on this iPhone.
struct CarMapKeyRows: View {
    @State private var text = UserDefaults.standard.string(forKey: "carMapKey") ?? ""
    @State private var saved = false
    var done: () -> Void = {}

    var body: some View {
        Text("1. Open console.cloud.google.com on a computer.\n2. APIs & Services → Library → turn on \"Maps JavaScript API\".\n3. APIs & Services → Credentials → Create credentials → API key.\n4. Open the new key. Application restrictions: Websites. Add:\nhttps://car.tesla4khmer.com/*\n5. API restrictions: Maps JavaScript API. Save.\n6. Copy the key and paste it below.")
            .font(.footnote)
        TextField("AIza… (website key)", text: $text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        Button(saved ? "Saved ✓ the car reloads its map" : "Save car map key") {
            let k = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !k.isEmpty else { return }
            UserDefaults.standard.set(k, forKey: "carMapKey")
            CarLink.carMapProblem = ""
            saved = true
            done()
        }
        if !(UserDefaults.standard.string(forKey: "carMapKey") ?? "").isEmpty {
            Button("Remove car map key", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "carMapKey")
                text = ""
                saved = false
            }
        }
    }
}

struct CarMapKeySheet: View {
    let problem: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("What is wrong") {
                    Text("The car could not draw the Google map itself: \(problem). So it shows pictures from this iPhone, and those stop when you leave ScreenLink or lock the phone.")
                    Text("Fix: give the car its own Google key for the website. You do this once.")
                        .font(.footnote).foregroundColor(.secondary)
                }
                Section("Car map key") { CarMapKeyRows() }
            }
            .navigationTitle("Fix the car map")
            .toolbar { Button("Close") { dismiss() } }
        }
    }
}

/// Objective-C entry point used by ScreenLink Home (main.m) through NSClassFromString.
@objc(SLMapsLauncher)
final class SLMapsLauncher: NSObject {
    private static var controller: UIViewController?

    @objc static func mapsController() -> UIViewController {
        if let existing = controller { return existing }
        var hosting: UIHostingController<CarMapsRoot>?
        let root = CarMapsRoot(close: { hosting?.dismiss(animated: true) })
        let made = UIHostingController(rootView: root)
        hosting = made
        made.modalPresentationStyle = .fullScreen
        controller = made
        return made
    }
}
