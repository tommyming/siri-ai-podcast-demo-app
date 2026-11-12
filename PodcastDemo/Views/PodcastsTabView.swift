import SwiftUI

/// Main tab: searchable grid of podcasts. With an empty search term it shows a
/// curated set of podcasts; typing switches to live search results.
struct PodcastsTabView: View {
    @State private var searchText = ""
    @State private var podcasts: [Podcast] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    private let service = ITunesPodcastService.shared
    private let defaultTerms = ["technology", "news", "comedy"]

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    content(for: podcasts, title: "Browse Podcasts")
                } else {
                    SearchResultsView(query: searchText)
                }
            }
            .navigationTitle(searchText.isEmpty ? "Podcasts" : "Search")
            .searchable(text: $searchText, prompt: "Search podcasts")
        }
        .task { await loadDefaults() }
    }

    @ViewBuilder
    private func content(for podcasts: [Podcast], title: LocalizedStringKey) -> some View {
        if isLoading && podcasts.isEmpty {
            ProgressView(title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, podcasts.isEmpty {
            ContentUnavailableView {
                Label("Something went wrong", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") { Task { await loadDefaults() } }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16, alignment: .top)], spacing: 16) {
                    ForEach(podcasts) { podcast in
                        NavigationLink(value: podcast) {
                            PodcastCard(podcast: podcast)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationDestination(for: Podcast.self) { podcast in
                PodcastDetailView(podcast: podcast)
            }
        }
    }

    private func loadDefaults() async {
        guard podcasts.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        // Fetch a few curated terms in parallel and interleave the results.
        var seen = Set<Int>()
        let responses = await withTaskGroup(of: [Podcast].self, returning: [Podcast].self) { group in
            for term in defaultTerms {
                group.addTask {
                    (try? await service.searchPodcasts(term, limit: 12)) ?? []
                }
            }
            var all: [Podcast] = []
            for await results in group { all.append(contentsOf: results) }
            return all.shuffled()
        }
        var combined: [Podcast] = []
        for podcast in responses where !seen.contains(podcast.id) {
            seen.insert(podcast.id)
            combined.append(podcast)
        }
        if combined.isEmpty {
            errorMessage = "Couldn't load podcasts. Check your connection and try again."
        } else {
            errorMessage = nil
            podcasts = combined
        }
    }
}

// MARK: - Podcast card

struct PodcastCard: View {
    let podcast: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: podcast.artworkURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(podcast.collectionName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .foregroundStyle(.primary)

            Text(podcast.artistName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("podcast-card")
    }
}

// MARK: - Search results

struct SearchResultsView: View {
    @State private var podcasts: [Podcast] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    let query: String
    private let service = ITunesPodcastService.shared

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ContentUnavailableView("Search failed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else if podcasts.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16, alignment: .top)], spacing: 16) {
                        ForEach(podcasts) { podcast in
                            NavigationLink(value: podcast) {
                                PodcastCard(podcast: podcast)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .navigationDestination(for: Podcast.self) { podcast in
                    PodcastDetailView(podcast: podcast)
                }
            }
        }
        .task(id: query) {
            // Debounce: wait for typing to pause before hitting the API
            // (iTunes is rate-limited to ~20 requests/minute).
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private func search() async {
        guard !query.isEmpty else { return }
        AppLogger.app.notice("searching podcasts for \(self.query, privacy: .public)")
        isLoading = true
        defer { isLoading = false }
        do {
            podcasts = try await service.searchPodcasts(query)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
