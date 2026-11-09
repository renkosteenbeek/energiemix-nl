import SwiftUI
import WidgetKit

@main
struct StroompeilWidgetBundle: WidgetBundle {
    var body: some Widget {
        StroompeilWidget()
    }
}

struct StroompeilWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: StroompeilProvider()) { entry in
            StroompeilWidgetView(entry: entry)
        }
        .configurationDisplayName("Stroompeil")
        .description("Hoe groen is de Nederlandse stroom nu?")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
