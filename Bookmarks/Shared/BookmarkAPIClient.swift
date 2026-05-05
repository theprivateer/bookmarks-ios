import Foundation

enum BookmarkAPIError: LocalizedError {
    case missingConfiguration
    case httpError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "API URL or key not configured. Open the Bookmarks app to set them up."
        case .httpError(let code, let message):
            return message ?? "Server error (\(code))"
        }
    }
}

enum BookmarkAPIClient {
    static func createBookmark(url: URL) async throws {
        let baseURL = SettingsStore.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = SettingsStore.apiKey
        guard !baseURL.isEmpty, !apiKey.isEmpty, let endpoint = URL(string: baseURL + "/bookmarks") else {
            throw BookmarkAPIError.missingConfiguration
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["url": url.absoluteString])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BookmarkAPIError.httpError(0, nil)
        }
        guard (200...299).contains(http.statusCode) else {
            let message = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw BookmarkAPIError.httpError(http.statusCode, message?.message)
        }
    }
}

private struct APIErrorResponse: Decodable {
    let message: String
}
