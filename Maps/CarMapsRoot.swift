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

struct CarMapsRoot: View {
    @StateObject private var keyStore = KeyStore()
    let close: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            if keyStore.ready {
                ContentView(apiKey: keyStore.key)
            } else {
                KeySetupView(keyStore: keyStore)
            }
            Button(action: close) {
                Label("ScreenLink", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(.leading, 12).padding(.top, 6)
            .accessibilityLabel("Back to ScreenLink. Navigation keeps running.")
            // Build 98: one switch for the small map on the car screen.
            HStack { Spacer(); CarMapSwitch() }.padding(.trailing, 12).padding(.top, 6)
        }
    }
}

struct CarMapSwitch: View {
    @State private var on = CarLink.carMapOn
    @State private var works = false
    @State private var problem = ""
    @State private var showFix = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
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
            // Build 101: say plainly whether the car draws the map itself (needed for background use).
            if on && works {
                Text("Car draws the map ✓ works when you leave the app")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.85), in: Capsule())
                    .foregroundColor(.white)
            } else if on && !problem.isEmpty {
                Button { showFix = true } label: {
                    Text("Car map stops when you leave the app · Tap to fix")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.orange, in: Capsule())
                        .foregroundColor(.white)
                }
            }
        }
        .onReceive(tick) { _ in works = CarLink.carDrawsMap; problem = CarLink.carMapProblem }
        .sheet(isPresented: $showFix) { CarMapKeySheet(problem: problem) }
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
