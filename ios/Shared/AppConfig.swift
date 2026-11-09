import Foundation

enum AppConfig {
    static let apiBaseURL: URL = {
        #if LOCAL_API
        URL(string: "http://127.0.0.1:3000")!
        #else
        URL(string: "https://energiemix.gentle-innovations.nl")!
        #endif
    }()

    static let privacyURL = URL(string: "https://energiemix.gentle-innovations.nl/privacy")!
    static let supportURL = URL(string: "https://energiemix.gentle-innovations.nl/support")!
    static let nowDeepLink = URL(string: "stroompeil://nu")!
    static let widgetKind = "StroompeilWidget"
}
