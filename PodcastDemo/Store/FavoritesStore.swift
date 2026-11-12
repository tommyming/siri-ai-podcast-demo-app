import Foundation
import Observation

// MARK: - Favorite episode storage

/// An episode together with the podcast it belongs to, so the Favorites tab
/// can display artwork and podcast title without extra lookups.
nonisolated struct FavoriteEntry: Codable, Identifiable, Hashable, Sendable {
    var episode: PodcastEpisode
    var podcastName: String
    var podcastArtist: String
    var artworkURL: URL?
    /// The podcast's real collection ID. Optional for backward compatibility
    /// with favorites persisted before this field existed.
    var podcastCollectionId: Int?

    var id: Int { episode.id }
}

@MainActor
@Observable
final class FavoritesStore {
    private static let storageKey = "favoriteEpisodes"

    /// In insertion order; newest favorite last.
    private(set) var entries: [FavoriteEntry] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode([FavoriteEntry].self, from: data) {
            entries = saved
        }
        AppLogger.favorites.info("restored \(self.entries.count) favorite(s) from storage")
    }

    func isFavorite(_ episode: PodcastEpisode) -> Bool {
        entries.contains { $0.id == episode.id }
    }

    func toggle(_ episode: PodcastEpisode, podcast: Podcast) {
        if isFavorite(episode) {
            entries.removeAll { $0.id == episode.id }
            AppLogger.favorites.notice("removed favorite: \(episode.trackName, privacy: .public)")
        } else {
            entries.append(
                FavoriteEntry(
                    episode: episode,
                    podcastName: podcast.collectionName,
                    podcastArtist: podcast.artistName,
                    artworkURL: podcast.artworkURL,
                    podcastCollectionId: podcast.collectionId
                )
            )
            AppLogger.favorites.notice("added favorite: \(episode.trackName, privacy: .public)")
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: Self.storageKey)
        AppLogger.favorites.debug("persisted \(self.entries.count) favorite(s)")
    }
}
