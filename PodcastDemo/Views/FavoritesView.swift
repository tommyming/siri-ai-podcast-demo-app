import SwiftUI

/// Favorites tab: list layout. Tapping a row plays the favorited episode.
struct FavoritesView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            Group {
                if app.favorites.entries.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "heart.slash",
                        description: Text("Tap the heart on any episode to see it here.")
                    )
                } else {
                    List(app.favorites.entries) { entry in
                        Button {
                            app.player.play(entry.episode, from: favoritePodcastStub(entry))
                        } label: {
                            favoriteRow(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Favorites")
        }
    }

    private func favoriteRow(_ entry: FavoriteEntry) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: entry.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.episode.trackName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text("\(entry.podcastName) · \(entry.podcastArtist)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                app.favorites.toggle(
                    entry.episode,
                    podcast: favoritePodcastStub(entry)
                )
            } label: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from favorites")
        }
    }

    /// A minimal `Podcast` describing where the favorited episode came from,
    /// used for playback metadata and un-favoriting.
    private func favoritePodcastStub(_ entry: FavoriteEntry) -> Podcast {
        Podcast(
            collectionId: entry.podcastCollectionId ?? entry.id,
            trackId: entry.id,
            artistName: entry.podcastArtist,
            collectionName: entry.podcastName,
            feedUrl: nil,
            artworkUrl600: entry.artworkURL?.absoluteString,
            primaryGenreName: nil,
            trackCount: nil,
            collectionViewUrl: nil
        )
    }
}
