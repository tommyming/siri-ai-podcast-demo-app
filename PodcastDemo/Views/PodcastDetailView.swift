import SwiftUI

/// Podcast page: header with artwork, podcast name, artist and description,
/// followed by the recent episodes list. Rows play on tap and have a
/// favorite toggle.
struct PodcastDetailView: View {
    @Environment(AppModel.self) private var app

    let podcast: Podcast

    @State private var episodes: [PodcastEpisode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = ITunesPodcastService.shared

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)

            Section("Recent Episodes") {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                }
                ForEach(episodes) { episode in
                    Button {
                        app.player.play(episode, from: podcast)
                        app.player.isPlayerPresented = true
                    } label: {
                        EpisodeRow(
                            episode: episode,
                            isFavorite: app.favorites.isFavorite(episode)
                        ) {
                            app.favorites.toggle(episode, podcast: podcast)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("episode-row")
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(podcast.collectionName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEpisodes() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: podcast.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 6, y: 3)

            Text(podcast.collectionName)
                .font(.title2.weight(.bold))

            Text(podcast.artistName)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let genre = podcast.primaryGenreName {
                Text(genre)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }

            if !podcastDescription.isEmpty {
                Text(podcastDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var podcastDescription: String {
        // The search endpoint has no podcast description; use the genre as a
        // stand-in summary so the header still reads well.
        guard let genre = podcast.primaryGenreName else { return "" }
        return "A \(genre.lowercased()) podcast with \(podcast.trackCount.map(String.init) ?? "many") episodes."
    }

    private func loadEpisodes() async {
        isLoading = true
        defer { isLoading = false }
        AppLogger.app.notice("loading episodes for podcast \(self.podcast.collectionName, privacy: .public)")
        do {
            episodes = try await service.recentEpisodes(ofPodcast: podcast.collectionId, limit: 30)
            errorMessage = nil
            AppLogger.app.info("loaded \(self.episodes.count) episode(s)")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.app.error("episode load failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Episode row

struct EpisodeRow: View {
    let episode: PodcastEpisode
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.trackName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let date = episode.releaseDateValue {
                        Text(date, style: .date)
                    }
                    if let duration = episode.duration {
                        Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let summary = episode.displayDescription, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
        }
        .padding(.vertical, 2)
    }
}
