import AppIntents
import Foundation

// MARK: - Podcast entity

struct PodcastEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Podcast"
    static let defaultQuery = PodcastEntityQuery()

    let id: Int
    let name: String
    let artistName: String
    let artworkURL: URL?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(artistName)"
        )
    }

    /// Maps the API model to the entity.
    init(podcast: Podcast) {
        self.id = podcast.collectionId
        self.name = podcast.collectionName
        self.artistName = podcast.artistName
        self.artworkURL = podcast.artworkURL
    }

    init(id: Int, name: String, artistName: String, artworkURL: URL?) {
        self.id = id
        self.name = name
        self.artistName = artistName
        self.artworkURL = artworkURL
    }
}

/// String query that searches the iTunes catalog for podcast suggestions.
struct PodcastEntityQuery: EntityStringQuery {
    func entities(for identifiers: [PodcastEntity.ID]) async throws -> [PodcastEntity] {
        guard !identifiers.isEmpty else { return [] }
        let podcasts = try await ITunesPodcastService.shared.podcasts(matchingIDs: identifiers)
        return podcasts.map(PodcastEntity.init)
    }

    func suggestedEntities() async throws -> [PodcastEntity] {
        try await matching("podcast", limit: 10)
    }

    func entities(matching query: String) async throws -> [PodcastEntity] {
        // EntityStringQuery results are not auto-filtered; do it ourselves.
        try await matching(query, limit: 10)
    }

    private func matching(_ term: String, limit: Int) async throws -> [PodcastEntity] {
        let podcasts = try await ITunesPodcastService.shared.searchPodcasts(term, limit: limit)
        return podcasts.map(PodcastEntity.init)
    }
}

// MARK: - 1. Play last played episode

/// Plays the most recently played episode (persisted across launches).
struct PlayLastPlayedEpisodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Play Last Played Episode"
    static let description = IntentDescription("Resumes the podcast episode you played most recently, from where you left off.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLogger.intents.notice("PlayLastPlayedEpisodeIntent invoked")
        let player = AppModel.shared.player
        guard let last = player.lastPlayed else {
            AppLogger.intents.error("no last played episode on record")
            return .result(dialog: "You haven't played any episode yet. Play one in the app first.")
        }
        player.play(last.episode, from: last.podcast)
        return .result(dialog: "Playing \(last.episode.trackName) from \(last.podcast.collectionName).")
    }
}

// MARK: - 2. Latest episodes of a podcast

/// Returns the 10 most recent episodes of a specific podcast.
struct LatestEpisodesIntent: AppIntent {
    static let title: LocalizedStringResource = "Latest Episodes of a Podcast"
    static let description = IntentDescription("Gets the 10 most recent episodes of a podcast.")

    @Parameter(title: "Podcast")
    var podcast: PodcastEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Latest episodes of \(\.$podcast)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLogger.intents.notice("LatestEpisodesIntent invoked for podcast \(self.podcast.id)")
        let episodes = try await ITunesPodcastService.shared.recentEpisodes(
            ofPodcast: podcast.id,
            limit: 10
        )
        guard !episodes.isEmpty else {
            return .result(dialog: "No recent episodes found for \(podcast.name).")
        }
        let list = episodes
            .prefix(10)
            .enumerated()
            .map { index, episode in
                "\(index + 1). \(episode.trackName)"
            }
            .joined(separator: ", ")
        return .result(dialog: "The 10 latest episodes of \(podcast.name): \(list)")
    }
}

// MARK: - 3. Search by description and play the latest episode

/// Searches the catalog from a free-text description, lets the user pick the
/// podcast, then plays its latest episode.
struct SearchAndPlayPodcastIntent: AppIntent {
    static let title: LocalizedStringResource = "Play a Podcast I Describe"
    static let description = IntentDescription("Describes a podcast, picks from matches, and plays its latest episode.")

    @Parameter(title: "Description")
    var description: String

    static var parameterSummary: some ParameterSummary {
        Summary("Play a podcast about \(\.$description)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        AppLogger.intents.notice("SearchAndPlayPodcastIntent invoked with description \(self.description, privacy: .public)")
        // 1. Search the catalog from the description.
        let results = try await ITunesPodcastService.shared.searchPodcasts(description, limit: 8)
        guard !results.isEmpty else {
            AppLogger.intents.error("search returned no podcasts")
            return .result(dialog: "I couldn't find any podcasts matching \"\(description)\".")
        }

        // 2. Let the user pick which podcast to play.
        let topResults = Array(results.prefix(5))
        let options: [IntentChoiceOption] = topResults.map {
            IntentChoiceOption(title: "\($0.collectionName)")
        }
        let choice = try await requestChoice(
            between: options,
            dialog: "Which podcast?"
        )
        guard let chosen = topResults.first(where: { $0.collectionName == choice.title.key }) else {
            AppLogger.intents.error("user choice \(choice.title.key, privacy: .public) matched no result")
            return .result(dialog: "Playback cancelled.")
        }

        // 3. Fetch and play the latest episode of the chosen podcast.
        AppLogger.intents.notice("user selected podcast \(chosen.collectionName, privacy: .public)")
        let episodes = try await ITunesPodcastService.shared.recentEpisodes(ofPodcast: chosen.collectionId, limit: 1)
        guard let latest = episodes.first, latest.streamURL != nil else {
            return .result(dialog: "The latest episode of \(chosen.collectionName) isn't available for playback.")
        }

        await MainActor.run {
            AppModel.shared.player.play(latest, from: chosen)
        }
        return .result(dialog: "Playing the latest episode of \(chosen.collectionName): \(latest.trackName).")
    }
}
