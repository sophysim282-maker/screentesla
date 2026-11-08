import Foundation

struct CarPlayerConnectionError: LocalizedError {
    var errorDescription: String? {
        "Car player unavailable. Start ScreenLink and connect YouTube AirPlay, then try again."
    }
}

enum CarPlayerConnection {
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
