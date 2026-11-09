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
