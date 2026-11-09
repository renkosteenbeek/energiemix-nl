import Foundation

enum SourceCategory: String, Codable, Sendable {
    case groen
    case grijs

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SourceCategory(rawValue: raw) ?? .grijs
    }
}

struct SourceSlice: Codable, Sendable, Equatable, Identifiable {
    let typeId: Int
    let label: String
    let category: SourceCategory
    let volumeKWh: Double
    let percentage: Double

    var id: Int { typeId }
}

struct Mix: Codable, Sendable, Equatable {
    let focusTime: Date
    let greenPct: Double
    let totalKWh: Double
    let sources: [SourceSlice]

    var hasData: Bool { totalKWh > 0 && !sources.isEmpty }
    var hour: Date { focusTime.flooredToHour }
    var roundedGreenPct: Int { Int(greenPct.rounded()) }
}

struct MixResponse: Decodable, Sendable {
    let mix: Mix
}

struct SourceMeta: Decodable, Sendable, Equatable {
    let typeId: Int
    let label: String
    let category: SourceCategory
}

struct DayPoint: Sendable, Equatable {
    let day: Date
    let totalKWh: Double
    let greenPct: Double
    let volumes: [Double]
}

struct YearData: Decodable, Sendable, Equatable {
    let year: Int
    let sources: [SourceMeta]
    let days: [DayPoint]

    private enum CodingKeys: String, CodingKey { case year, sources, days }

    private struct RawDay: Decodable {
        let date: String
        let totalKWh: Double
        let greenPct: Double
        let volumes: [Double]
    }

    init(year: Int, sources: [SourceMeta], days: [DayPoint]) {
        self.year = year
        self.sources = sources
        self.days = days
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        year = try container.decode(Int.self, forKey: .year)
        sources = try container.decode([SourceMeta].self, forKey: .sources)
        let raw = try container.decode([RawDay].self, forKey: .days)
        days = try raw.map { item in
            guard let day = DutchFormat.day(fromISO: item.date) else {
                throw DecodingError.dataCorruptedError(forKey: .days, in: container, debugDescription: "Ongeldige dag: \(item.date)")
            }
            return DayPoint(day: day, totalKWh: item.totalKWh, greenPct: item.greenPct, volumes: item.volumes)
        }
    }
}

struct Snapshot: Sendable, Equatable {
    enum Span: Sendable, Equatable {
        case hour
        case day
    }

    let span: Span
    let date: Date
    let greenPct: Double
    let totalKWh: Double
    let sources: [SourceSlice]

    var hasData: Bool { totalKWh > 0 && !sources.isEmpty }
    var roundedGreenPct: Int { Int(greenPct.rounded()) }

    init(mix: Mix) {
        span = .hour
        date = mix.focusTime
        greenPct = mix.greenPct
        totalKWh = mix.totalKWh
        sources = mix.sources
    }

    init(day point: DayPoint, sources meta: [SourceMeta]) {
        span = .day
        date = point.day
        greenPct = point.greenPct
        totalKWh = point.totalKWh
        sources = zip(meta, point.volumes)
            .filter { $0.1 > 0 }
            .map { meta, volume in
                SourceSlice(
                    typeId: meta.typeId,
                    label: meta.label,
                    category: meta.category,
                    volumeKWh: volume,
                    percentage: point.totalKWh > 0 ? volume / point.totalKWh * 100 : 0
                )
            }
            .sorted { $0.volumeKWh > $1.volumeKWh }
    }
}

struct TimePoint: Decodable, Sendable, Equatable {
    let time: Date
    let greenPct: Double
    let totalKWh: Double
}

extension JSONDecoder {
    static var stroompeil: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = ISODate.parse(raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Ongeldige datum: \(raw)")
            }
            return date
        }
        return decoder
    }
}

extension JSONEncoder {
    static var stroompeil: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISODate.string(from: date))
        }
        return encoder
    }
}

enum ISODate {
    private static let plain = Date.ISO8601FormatStyle()
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func parse(_ raw: String) -> Date? {
        (try? plain.parse(raw)) ?? (try? fractional.parse(raw))
    }

    static func string(from date: Date) -> String {
        plain.format(date)
    }
}
