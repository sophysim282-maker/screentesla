import Foundation

@main
struct CarPlayerConnectionTest {
    static func main() async throws {
        try await CarPlayerConnection.send("volumeUp")
        for action in ["playPause", "auto"] {
            do {
                try await CarPlayerConnection.send(action)
                fatalError("Unexpected acceptance for \(action)")
            } catch is CarPlayerConnectionError {
                continue
            }
        }
    }
}
