import Foundation

// MARK: - ITunesPodcastService

/// A clean service wrapping the free Apple iTunes Search API
/// (https://itunes.apple.com). No authentication required; ~20 req/min rate limit.
struct ITunesPodcastService: Sendable {
    static let shared = ITunesPodcastService()

    private let baseURL = URL(string: "https://itunes.apple.com")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    enum ServiceError: LocalizedError {
        case invalidURL
        case network(Error)
        case decoding(Error)
        case noResults

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Could not build the request URL."
            case .network(let error): "Network request failed: \(error.localizedDescription)"
            case .decoding(let error): "Could not read the server response: \(error.localizedDescription)"
            case .noResults: "No podcasts were found."
            }
        }
    }

    // MARK: Search podcasts

    /// Searches for podcasts matching `query`.
    /// - Parameters:
    ///   - query: free-text search term.
    ///   - limit: maximum number of results (practically capped at ~100 by the API).
    ///   - country: two-letter ISO country code (default "US").
    func searchPodcasts(
        _ query: String,
        limit: Int = 30,
        country: String = "US"
    ) async throws -> [Podcast] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "term", value: query),
            .init(name: "media", value: "podcast"),
            .init(name: "entity", value: "podcast"),
            .init(name: "limit", value: String(limit)),
            .init(name: "country", value: country),
        ]
        let response: ITunesResponse<Podcast> = try await get(components.url!)
        return response.results
    }

    // MARK: Recent episodes

    /// Fetches the most recent episodes of a podcast via the lookup endpoint.
    /// - Note: the lookup endpoint only returns *recent* episodes. For the full
    ///   back-catalog, parse the podcast's `feedUrl` (RSS) instead.
    func recentEpisodes(
        ofPodcast collectionId: Int,
        limit: Int = 10
    ) async throws -> [PodcastEpisode] {
        var components = URLComponents(url: baseURL.appendingPathComponent("lookup"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "id", value: String(collectionId)),
            .init(name: "entity", value: "podcastEpisode"),
            .init(name: "limit", value: String(limit)),
        ]
        let response: ITunesResponse<PodcastEpisode> = try await get(components.url!)
        // The first result of a lookup is the podcast collection itself; keep only episodes.
        return response.results.filter { $0.episodeUrl != nil }
    }

    // MARK: Lookup podcasts by id (used by App Intents entity resolution)

    func podcasts(matchingIDs ids: [Int]) async throws -> [Podcast] {
        var components = URLComponents(url: baseURL.appendingPathComponent("lookup"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "id", value: ids.map(String.init).joined(separator: ",")),
            .init(name: "entity", value: "podcast"),
        ]
        let response: ITunesResponse<Podcast> = try await get(components.url!)
        return response.results
    }

    // MARK: - Private

    private func get<Response: Decodable>(_ url: URL) async throws -> Response {
        AppLogger.network.debug("GET \(url.path, privacy: .public) ?\(url.query ?? "-", privacy: .public)")
        let (data, httpResponse): (Data, URLResponse)
        do {
            (data, httpResponse) = try await session.data(from: url)
        } catch {
            AppLogger.network.error("GET \(url.path, privacy: .public) network failure: \(error.localizedDescription, privacy: .public)")
            throw ServiceError.network(error)
        }
        guard (httpResponse as? HTTPURLResponse)?.statusCode == 200 else {
            let status = (httpResponse as? HTTPURLResponse)?.statusCode ?? -1
            AppLogger.network.error("GET \(url.path, privacy: .public) unexpected status \(status)")
            throw ServiceError.network(
                URLError(.badServerResponse)
            )
        }
        do {
            let decoded = try decoder.decode(Response.self, from: data)
            AppLogger.network.info("GET \(url.path, privacy: .public) succeeded (\(data.count) bytes)")
            return decoded
        } catch {
            AppLogger.network.error("GET \(url.path, privacy: .public) decoding failure: \(error.localizedDescription, privacy: .public)")
            throw ServiceError.decoding(error)
        }
    }
}

// MARK: - Usage example

/*
 // Both endpoints run off the main actor with plain async/await:

 Task { @concurrent in
     // 1. Search podcasts
     let podcasts = try await ITunesPodcastService.shared.searchPodcasts("Swift")
     print(podcasts.first?.collectionName ?? "none")

     // 2. Fetch the 10 most recent episodes of the first result
     if let id = podcasts.first?.collectionId {
         let episodes = try await ITunesPodcastService.shared.recentEpisodes(ofPodcast: id, limit: 10)
         print(episodes.map(\.trackName))
     }
 }
 */
