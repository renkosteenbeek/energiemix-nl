import Foundation
import Testing
@testable import Stroompeil

struct ModelTests {
    private let mixJSON = """
    {
      "at": "2026-11-09T14:00:00.000Z",
      "mix": {
        "focusTime": "2026-11-09T14:00:00+00:00",
        "greenPct": 34.443678594567636,
        "totalKWh": 15808146,
        "sources": [
          { "typeId": 18, "label": "Aardgas", "category": "grijs", "color": "#E07A4E", "volumeKWh": 6768558, "percentage": 42.81689959088181 },
          { "typeId": 19, "label": "Steenkool", "category": "grijs", "color": "var(--color-coal)", "volumeKWh": 2611661, "percentage": 16.520982283437917 },
          { "typeId": 2, "label": "Zon", "category": "groen", "color": "#F5B13B", "volumeKWh": 4014618, "percentage": 25.395881338646543 },
          { "typeId": 99, "label": "Nieuw", "category": "onbekend", "color": "#000000", "volumeKWh": 1, "percentage": 0.0001 }
        ],
        "series": [{ "time": "2026-11-09T00:00:00+00:00", "greenPct": 19.3, "totalKWh": 15339275 }]
      },
      "facts": { "notable": [] }
    }
    """

    private let timelineJSON = """
    [
      { "time": "2026-11-09T13:00:00+00:00", "greenPct": 44.6, "totalKWh": 18701299, "forecast": false },
      { "time": "2026-11-09T15:00:00+00:00", "greenPct": 16.3, "totalKWh": 12817152, "forecast": true },
      { "time": "2026-11-09T16:00:00.000Z", "greenPct": 9.7, "totalKWh": 12107459 }
    ]
    """

    @Test func decodesLiveMixResponse() throws {
        let mix = try JSONDecoder.stroompeil.decode(MixResponse.self, from: Data(mixJSON.utf8)).mix
        #expect(mix.focusTime == ISODate.parse("2026-11-09T14:00:00Z"))
        #expect(mix.roundedGreenPct == 34)
        #expect(mix.sources.count == 4)
        #expect(mix.sources[1].category == .grijs)
        #expect(mix.sources[3].category == .grijs)
        #expect(mix.hasData)
    }

    @Test func decodesTimelineWithAndWithoutForecastFieldAndFractionalSeconds() throws {
        let points = try JSONDecoder.stroompeil.decode([TimePoint].self, from: Data(timelineJSON.utf8))
        #expect(points.count == 3)
        #expect(points[1].greenPct == 16.3)
        #expect(points[2].time == ISODate.parse("2026-11-09T16:00:00Z"))
    }

    @Test func mixSurvivesWidgetCacheRoundTrip() throws {
        let mix = try JSONDecoder.stroompeil.decode(MixResponse.self, from: Data(mixJSON.utf8)).mix
        let data = try JSONEncoder.stroompeil.encode(mix)
        let decoded = try JSONDecoder.stroompeil.decode(Mix.self, from: data)
        #expect(decoded == mix)
    }

    @Test func emptyMixHasNoData() {
        let mix = Mix(focusTime: .now, greenPct: 0, totalKWh: 0, sources: [])
        #expect(mix.hasData == false)
    }

    @Test func rejectsGarbageDates() {
        let json = #"[{ "time": "gisteren", "greenPct": 1, "totalKWh": 1 }]"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder.stroompeil.decode([TimePoint].self, from: Data(json.utf8))
        }
    }
}
