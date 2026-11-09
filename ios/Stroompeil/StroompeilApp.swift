import SwiftUI

@main
struct StroompeilApp: App {
    @State private var model = DashboardModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(model: model)
                .tint(Palette.ink)
        }
    }
}
