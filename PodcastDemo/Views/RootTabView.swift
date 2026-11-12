import SwiftUI

struct RootTabView: View {
    @Environment(AppModel.self) private var app
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PodcastsTabView()
                .tabItem { Label("Podcasts", systemImage: "square.grid.2x2") }
                .tag(0)

            FavoritesView()
                .tabItem { Label("Favorites", systemImage: "heart") }
                .tag(1)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if app.player.currentEpisode != nil {
                MiniPlayerBar()
            }
        }
        .sheet(isPresented: bindPlayerPresented) {
            PlayerSheetView()
                .presentationDetents([.medium, .large])
        }
    }

    private var bindPlayerPresented: Binding<Bool> {
        Binding(
            get: { app.player.isPlayerPresented },
            set: { newValue in
                if newValue != app.player.isPlayerPresented {
                    AppLogger.app.notice("player sheet \(newValue ? "presented" : "dismissed", privacy: .public)")
                }
                app.player.isPlayerPresented = newValue
            }
        )
    }
}

// MARK: - Mini player bar

/// Slim bar pinned above the tab bar. Tapping (or dragging up) re-opens the
/// full player sheet.
struct MiniPlayerBar: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 12) {
            artwork
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.player.currentEpisode?.trackName ?? "")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text(app.player.currentPodcast?.collectionName ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                app.player.togglePlayPause()
            } label: {
                Image(systemName: app.player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .contentShape(Rectangle())
        .onTapGesture { app.player.isPlayerPresented = true }
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height < -20 {
                    app.player.isPlayerPresented = true
                }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing")
        .accessibilityHint("Opens the player")
        .accessibilityIdentifier("mini-player")
    }

    @ViewBuilder
    private var artwork: some View {
        if let url = app.player.currentPodcast?.artworkURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
        } else {
            Image(systemName: "headphones")
        }
    }
}
