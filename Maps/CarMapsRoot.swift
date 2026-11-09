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
    var body: some View {
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
