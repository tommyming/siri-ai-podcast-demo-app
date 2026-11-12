import AVFoundation
import Foundation
import Observation

/// Shared app state exposed to views and App Intents.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    let favorites: FavoritesStore
    let player: PlayerManager

    init() {
        let favorites = FavoritesStore()
        self.favorites = favorites
        self.player = PlayerManager()
    }
}

/// Streams podcast episodes with `AVPlayer` and publishes playback state.
/// `currentEpisode` doubles as the "last played" record used by the
/// "Play last played episode" App Intent (persisted to UserDefaults).
@MainActor
@Observable
final class PlayerManager {
    private static let lastPlayedKey = "lastPlayedEpisode"
    private static let lastPositionKey = "lastPlayedPosition"

    private(set) var currentEpisode: PodcastEpisode?
    private(set) var currentPodcast: Podcast?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// When true, the root view presents the full player sheet.
    var isPlayerPresented = false

    var lastPlayed: (episode: PodcastEpisode, podcast: Podcast)? {
        didSet {
            guard let lastPlayed else { return }
            if let data = try? JSONEncoder().encode(lastPlayed.podcast),
               let episodeData = try? JSONEncoder().encode(lastPlayed.episode) {
                let defaults = UserDefaults.standard
                defaults.set(data, forKey: "\(Self.lastPlayedKey).podcast")
                defaults.set(episodeData, forKey: "\(Self.lastPlayedKey).episode")
            }
        }
    }

    private var player: AVPlayer?
    private var timeObserver: Any?

    /// Playback position (seconds) of the last played episode, persisted so
    /// the "Play last played episode" intent can resume where the user left off.
    private(set) var lastPlayedPosition: TimeInterval = 0 {
        didSet { UserDefaults.standard.set(lastPlayedPosition, forKey: Self.lastPositionKey) }
    }

    init() {
        lastPlayedPosition = UserDefaults.standard.double(forKey: Self.lastPositionKey)
        // Restore the last played episode so the intent works across launches.
        let defaults = UserDefaults.standard
        if let podcastData = defaults.data(forKey: "\(Self.lastPlayedKey).podcast"),
           let episodeData = defaults.data(forKey: "\(Self.lastPlayedKey).episode"),
           let podcast = try? JSONDecoder().decode(Podcast.self, from: podcastData),
           let episode = try? JSONDecoder().decode(PodcastEpisode.self, from: episodeData) {
            lastPlayed = (episode, podcast)
            AppLogger.playback.info("restored last played episode: \(episode.trackName, privacy: .public)")
        }

        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            AppLogger.playback.debug("audio session configured (.playback / .spokenAudio)")
        } catch {
            // Playback still works; we just may not continue in the background.
            AppLogger.playback.error("audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Playback

    /// Starts playing `episode`. Replaces whatever is currently playing.
    func play(_ episode: PodcastEpisode, from podcast: Podcast) {
        guard let url = episode.streamURL else {
            AppLogger.playback.error("no stream URL for episode \(episode.trackName, privacy: .public)")
            return
        }

        // Same episode: just resume.
        if episode.id == currentEpisode?.id {
            AppLogger.playback.notice("resuming episode \(episode.trackName, privacy: .public)")
            resume()
            return
        }

        removeTimeObserver()
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        addTimeObserver(to: newPlayer)
        player = newPlayer

        // Same episode as last played: resume from the stored position.
        let resumePosition: TimeInterval
        if episode.id == lastPlayed?.episode.id, lastPlayedPosition > 5 {
            resumePosition = lastPlayedPosition
        } else {
            resumePosition = 0
        }

        currentEpisode = episode
        currentPodcast = podcast
        lastPlayed = (episode, podcast)
        currentTime = resumePosition
        duration = episode.duration ?? 0
        isPlaying = true
        newPlayer.play()
        if resumePosition > 0 {
            newPlayer.seek(to: CMTime(seconds: resumePosition, preferredTimescale: 600))
        }
        AppLogger.playback.notice("playing \(episode.trackName, privacy: .public) from \(podcast.collectionName, privacy: .public)")
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        lastPlayedPosition = currentTime
        AppLogger.playback.notice("paused at \(self.currentTime)s")
    }

    func resume() {
        guard player != nil else { return }
        player?.play()
        isPlaying = true
        AppLogger.playback.notice("resumed playback")
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        currentTime = time
        AppLogger.playback.notice("seeked to \(time)s")
    }

    // MARK: - Time observation

    private func addTimeObserver(to player: AVPlayer) {
        let observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                // Persist the position at most once per second.
                if Int(time.seconds) != Int(self.lastPlayedPosition) {
                    self.lastPlayedPosition = time.seconds
                }
                if let seconds = player.currentItem?.duration.seconds, seconds.isFinite {
                    self.duration = seconds
                }
            }
        }
        timeObserver = observer
    }

    private func removeTimeObserver() {
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
    }

}
