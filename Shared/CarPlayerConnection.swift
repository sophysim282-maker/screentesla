import Foundation

struct CarPlayerConnectionError: LocalizedError {
    var errorDescription: String? {
        "Car player unavailable. Start ScreenLink and connect YouTube AirPlay, then try again."
    }
}

// Build 84: live state shown by the widget and Control Center (phone loopback only).
struct CarPlayerState: Decodable {
    var running: Bool
    var active: Bool
    var paused: Bool
    var position: Double
    var duration: Double
    var quality: String
    var volume: Double
    var eq: String
    var car: Bool
    var epoch: String?
}

enum CarPlayerConnection {
    static func state() async -> CarPlayerState? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 1.5
        configuration.timeoutIntervalForResource = 2
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8080/local/widget/state")!,
                                 cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("app", forHTTPHeaderField: "X-ScreenLink-Control")
        guard let (body, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(CarPlayerState.self, from: body)
    }

    static func send(_ action: String) async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 3
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let url = URL(string: "http://127.0.0.1:8080/local/viewer/playback")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "POST"
        request.setValue("app", forHTTPHeaderField: "X-ScreenLink-Control")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["action": action])

        do {
            let (body, response) = try await session.data(for: request, delegate: NoRedirect())
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  try JSONDecoder().decode([String: Bool].self, from: body)["accepted"] == true else {
                throw CarPlayerConnectionError()
            }
        } catch {
            throw CarPlayerConnectionError()
        }
    }

    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}
