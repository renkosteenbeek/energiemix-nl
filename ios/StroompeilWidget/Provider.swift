import Foundation
import WidgetKit

struct EnergyEntry: TimelineEntry {
    enum Content {
        case mix(Mix)
        case unavailable
    }

    let date: Date
    let content: Content

    static var sample: EnergyEntry {
        EnergyEntry(date: .now, content: .mix(.sample))
    }
}

extension Mix {
    static var sample: Mix {
        Mix(
            focusTime: Date().flooredToHour,
            greenPct: 62,
            totalKWh: 15_800_000,
            sources: [
                SourceSlice(typeId: 2, label: "Zon", category: .groen, volumeKWh: 5_530_000, percentage: 35),
                SourceSlice(typeId: 1, label: "Wind op land", category: .groen, volumeKWh: 2_370_000, percentage: 15),
                SourceSlice(typeId: 18, label: "Aardgas", category: .grijs, volumeKWh: 1_900_000, percentage: 12),
            ]
        )
    }
}

struct StroompeilProvider: TimelineProvider {
    static let maxCacheAgeHours = 3
    let source: any EnergyDataSource = APIClient.live

    func placeholder(in context: Context) -> EnergyEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (EnergyEntry) -> Void) {
        if context.isPreview {
            completion(WidgetCache.load().map { EnergyEntry(date: .now, content: .mix($0)) } ?? .sample)
            return
        }
        Task {
            completion(await currentEntry().entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<EnergyEntry>) -> Void) {
        Task {
            let result = await currentEntry()
            completion(Timeline(entries: [result.entry], policy: .after(result.nextRefresh)))
        }
    }

    private func currentEntry() async -> (entry: EnergyEntry, nextRefresh: Date) {
        let now = Date()
        let hour = now.flooredToHour
        do {
            let mix = try await source.mix(at: hour, reload: false)
            guard mix.hasData else { throw APIError.invalidResponse }
            WidgetCache.save(mix)
            return (EnergyEntry(date: now, content: .mix(mix)), hour.addingHours(1).addingTimeInterval(5 * 60))
        } catch {
            let retry = now.addingTimeInterval(15 * 60)
            if let cached = WidgetCache.load(), cached.hour >= hour.addingHours(-Self.maxCacheAgeHours) {
                return (EnergyEntry(date: now, content: .mix(cached)), retry)
            }
            return (EnergyEntry(date: now, content: .unavailable), retry)
        }
    }
}

enum WidgetCache {
    private static var fileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appending(path: "laatste-mix.json")
    }

    static func load() -> Mix? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.stroompeil.decode(Mix.self, from: data)
    }

    static func save(_ mix: Mix) {
        guard let fileURL, let data = try? JSONEncoder.stroompeil.encode(mix) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
