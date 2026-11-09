import Foundation

protocol EnergyDataSource: Sendable {
    func mix(at hour: Date, reload: Bool) async throws -> Mix
    func timeline(reload: Bool) async throws -> [TimePoint]
    func timeline(from: Date, to: Date) async throws -> [TimePoint]
    func year(_ year: Int, reload: Bool) async throws -> YearData
    func story(at hour: Date, reload: Bool) -> AsyncThrowingStream<String, Error>
    func dayStory(_ day: Date, reload: Bool) -> AsyncThrowingStream<String, Error>
}

enum APIError: LocalizedError, Equatable {
    case offline
    case timeout
    case server(status: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .offline: "Geen internetverbinding."
        case .timeout: "De server reageert niet."
        case .server: "De server kon de gegevens nu niet leveren."
        case .invalidResponse: "De gegevens van de server waren onleesbaar."
        }
    }
}

struct APIClient: EnergyDataSource {
    let baseURL: URL
    let session: URLSession

    static let live = APIClient(baseURL: AppConfig.apiBaseURL, session: .stroompeil)

    func mix(at hour: Date, reload: Bool) async throws -> Mix {
        let request = makeRequest(path: "api/mix", query: ["at": ISODate.string(from: hour.flooredToHour)], reload: reload)
        let data = try await fetch(request)
        do {
            return try JSONDecoder.stroompeil.decode(MixResponse.self, from: data).mix
        } catch {
            throw APIError.invalidResponse
        }
    }

    func timeline(reload: Bool) async throws -> [TimePoint] {
        try await decode([TimePoint].self, from: makeRequest(path: "api/timeline", query: [:], reload: reload))
    }

    func timeline(from: Date, to: Date) async throws -> [TimePoint] {
        let query = ["from": ISODate.string(from: from.flooredToHour), "to": ISODate.string(from: to.flooredToHour)]
        return try await decode([TimePoint].self, from: makeRequest(path: "api/timeline", query: query, reload: false))
    }

    func year(_ year: Int, reload: Bool) async throws -> YearData {
        try await decode(YearData.self, from: makeRequest(path: "api/year", query: ["year": String(year)], reload: reload))
    }

    func story(at hour: Date, reload: Bool) -> AsyncThrowingStream<String, Error> {
        streamText(makeRequest(path: "api/story", query: ["at": ISODate.string(from: hour.flooredToHour)], reload: reload))
    }

    func dayStory(_ day: Date, reload: Bool) -> AsyncThrowingStream<String, Error> {
        streamText(makeRequest(path: "api/story", query: ["day": DutchFormat.isoDay(day)], reload: reload))
    }

    private func decode<T: Decodable>(_ type: T.Type, from request: URLRequest) async throws -> T {
        let data = try await fetch(request)
        do {
            return try JSONDecoder.stroompeil.decode(type, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    private func streamText(_ request: URLRequest) -> AsyncThrowingStream<String, Error> {
        let session = session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: request)
                    try Self.validate(response)
                    var text = ""
                    for try await character in bytes.characters {
                        text.append(character)
                        if character.isWhitespace || character.isPunctuation {
                            continuation.yield(text)
                        }
                    }
                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    if error is CancellationError || (error as? URLError)?.code == .cancelled {
                        continuation.finish(throwing: CancellationError())
                    } else if let cached = Self.cachedData(for: request, in: session),
                              let text = String(data: cached, encoding: .utf8) {
                        continuation.yield(text)
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: Self.map(error))
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func makeRequest(path: String, query: [String: String], reload: Bool) -> URLRequest {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.cachePolicy = reload ? .reloadIgnoringLocalCacheData : .useProtocolCachePolicy
        return request
    }

    private func fetch(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try Self.validate(response)
            return data
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            if let cached = Self.cachedData(for: request, in: session) {
                return cached
            }
            throw Self.map(error)
        }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw APIError.server(status: http.statusCode) }
    }

    private static func cachedData(for request: URLRequest, in session: URLSession) -> Data? {
        guard let cached = session.configuration.urlCache?.cachedResponse(for: request),
              let http = cached.response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              !cached.data.isEmpty
        else { return nil }
        return cached.data
    }

    private static func map(_ error: Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        guard let urlError = error as? URLError else { return .invalidResponse }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost,
             .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            return .offline
        default:
            return .server(status: urlError.errorCode)
        }
    }
}

extension URLSession {
    static let stroompeil: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.waitsForConnectivity = false
        configuration.urlCache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 32 * 1024 * 1024)
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }()
}
