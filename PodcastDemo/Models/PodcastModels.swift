import Foundation

// MARK: - API Models (iTunes Search API)

nonisolated struct ITunesResponse<Result: Decodable & Sendable>: Decodable {
    let resultCount: Int
    let results: [Result]
}

nonisolated struct Podcast: Codable, Identifiable, Sendable, Hashable {
    let collectionId: Int
    let trackId: Int
    let artistName: String
    let collectionName: String
    let feedUrl: String?
    let artworkUrl600: String?
    let primaryGenreName: String?
    let trackCount: Int?
    let collectionViewUrl: String?

    var id: Int { collectionId }
    var artworkURL: URL? { artworkUrl600.flatMap(URL.init) }
}

nonisolated struct PodcastEpisode: Codable, Identifiable, Sendable, Hashable {
    let trackId: Int
    let trackName: String
    let description: String?
    let shortDescription: String?
    let releaseDate: String?
    let trackTimeMillis: Int?
    let episodeUrl: String?

    var id: Int { trackId }
    var streamURL: URL? { episodeUrl.flatMap(URL.init) }
    var displayDescription: String? { shortDescription ?? description }
    var duration: TimeInterval? {
        trackTimeMillis.map { TimeInterval($0) / 1000 }
    }
    var releaseDateValue: Date? {
        releaseDate.flatMap { ISO8601DateFormatter().date(from: $0) }
    }
}
