import SwiftUI

/// Full player presented as a modal sheet. Drag up for the large detent,
/// drag down past the medium detent to dismiss back to the mini player bar.
struct PlayerSheetView: View {
    @Environment(AppModel.self) private var app

    @State private var seekPosition: Double = 0
    @State private var isScrubbing = false

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            if let episode = app.player.currentEpisode,
               let podcast = app.player.currentPodcast {
                VStack(spacing: 20) {
                    AsyncImage(url: podcast.artworkURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color.secondary.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 12, y: 6)
                    .padding(.horizontal, 48)

                    VStack(spacing: 6) {
                        Text(episode.trackName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("\(podcast.collectionName) · \(podcast.artistName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 24)

                    seekSlider

                    controls
                }
            } else {
                ContentUnavailableView(
                    "Nothing playing",
                    systemImage: "headphones",
                    description: Text("Pick an episode to start listening.")
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var seekSlider: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: {
                        isScrubbing ? seekPosition : app.player.currentTime
                    },
                    set: { newValue in
                        isScrubbing = true
                        seekPosition = newValue
                    }
                ),
                in: 0...max(app.player.duration, app.player.currentTime, 1)
            ) { editing in
                if !editing {
                    app.player.seek(to: seekPosition)
                    isScrubbing = false
                }
            }
            HStack {
                Text(timeString(app.player.currentTime))
                Spacer()
                Text("-" + timeString(max(0, app.player.duration - app.player.currentTime)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 32)
    }

    private var controls: some View {
        HStack(spacing: 48) {
            Button {
                let delta = app.player.currentTime - 15
                app.player.seek(to: max(0, delta))
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.title)
            }

            Button {
                app.player.togglePlayPause()
            } label: {
                Image(systemName: app.player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .contentTransition(.symbolEffect(.replace))
            }

            Button {
                let delta = app.player.currentTime + 15
                app.player.seek(to: min(app.player.duration, delta))
            } label: {
                Image(systemName: "goforward.15")
                    .font(.title)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func timeString(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 0 else { return "0:00" }
        let duration = Duration.seconds(interval)
        // Show hours only when the value actually needs them.
        return interval >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond))
    }
}
