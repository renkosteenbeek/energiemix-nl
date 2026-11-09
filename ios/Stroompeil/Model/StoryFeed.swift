import Foundation
import Observation

enum StoryPhase: Equatable, Sendable {
    case loading
    case streaming
    case ready
    case unavailable
}

enum StoryKey: Hashable, Sendable {
    case hour(Date)
    case day(Date)
}

@MainActor
@Observable
final class StoryFeed {
    private(set) var text = ""
    private(set) var phase: StoryPhase = .loading
    private(set) var key: StoryKey?

    @ObservationIgnored private let source: any EnergyDataSource
    @ObservationIgnored private var cache: [StoryKey: String] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?

    init(source: any EnergyDataSource) {
        self.source = source
    }

    func show(_ key: StoryKey, reload: Bool = false) {
        guard reload || key != self.key || phase == .unavailable else { return }
        task?.cancel()
        self.key = key
        if !reload, let cached = cache[key] {
            text = cached
            phase = .ready
            task = nil
            return
        }
        text = ""
        phase = .loading
        task = Task { await stream(key, reload: reload) }
    }

    func retry() {
        if let key { show(key, reload: true) }
    }

    func forget(where shouldForget: (StoryKey) -> Bool) {
        cache = cache.filter { !shouldForget($0.key) }
        if let key, shouldForget(key), phase == .ready {
            self.key = nil
        }
    }

    func forgetAll() {
        cache.removeAll()
    }

    private func stream(_ key: StoryKey, reload: Bool) async {
        let chunks: AsyncThrowingStream<String, Error>
        switch key {
        case .hour(let hour): chunks = source.story(at: hour, reload: reload)
        case .day(let day): chunks = source.dayStory(day, reload: reload)
        }
        var latest = ""
        do {
            for try await partial in chunks {
                guard !Task.isCancelled, key == self.key else { return }
                latest = partial
                text = partial
                phase = .streaming
            }
            guard !Task.isCancelled, key == self.key else { return }
            let finished = latest.trimmingCharacters(in: .whitespacesAndNewlines)
            if finished.isEmpty {
                text = ""
                phase = .unavailable
            } else {
                text = finished
                cache[key] = finished
                phase = .ready
            }
        } catch {
            guard !Task.isCancelled, key == self.key else { return }
            text = ""
            phase = .unavailable
        }
    }
}
