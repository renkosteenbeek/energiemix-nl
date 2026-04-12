import WidgetKit
import SwiftUI

struct EnergyEntry: TimelineEntry {
    let date: Date
    let greenPct: Int
    let totalGWh: String
    let topSources: [(label: String, pct: Int, color: Color)]
    let isPlaceholder: Bool

    static let placeholder = EnergyEntry(
        date: .now,
        greenPct: 62,
        totalGWh: "18 GWh",
        topSources: [
            ("Zon", 35, Color(hex: "#F5B13B")),
            ("Wind op land", 15, Color(hex: "#5896D1")),
            ("Aardgas", 12, Color(hex: "#E07A4E"))
        ],
        isPlaceholder: true
    )
}

struct EnergiemixProvider: TimelineProvider {
    func placeholder(in context: Context) -> EnergyEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (EnergyEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        fetchEntry { completion($0 ?? .placeholder) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EnergyEntry>) -> Void) {
        fetchEntry { entry in
            let current = entry ?? .placeholder
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
            completion(Timeline(entries: [current], policy: .after(nextUpdate)))
        }
    }

    private func fetchEntry(completion: @escaping (EnergyEntry?) -> Void) {
        guard let url = URL(string: "https://energiemix.gentle-innovations.nl/api/mix") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data, error == nil,
                  let response = try? JSONDecoder().decode(MixAPIResponse.self, from: data) else {
                completion(nil)
                return
            }

            let mix = response.mix
            let sorted = mix.sources.sorted { $0.percentage > $1.percentage }
            let top3 = Array(sorted.prefix(3)).map {
                (label: $0.label, pct: Int($0.percentage.rounded()), color: $0.swiftColor)
            }

            let totalGWh = mix.totalKWh >= 1000
                ? String(format: "%.0f GWh", mix.totalKWh / 1000)
                : String(format: "%.0f MWh", mix.totalKWh)

            completion(EnergyEntry(
                date: .now,
                greenPct: Int(mix.greenPct.rounded()),
                totalGWh: totalGWh,
                topSources: top3,
                isPlaceholder: false
            ))
        }.resume()
    }
}
