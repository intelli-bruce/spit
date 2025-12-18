import WidgetKit
import SwiftUI

struct DropsWidgetEntry: TimelineEntry {
    let date: Date
}

struct DropsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DropsWidgetEntry {
        DropsWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (DropsWidgetEntry) -> Void) {
        completion(DropsWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DropsWidgetEntry>) -> Void) {
        let entry = DropsWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct DropsWidgetEntryView: View {
    var entry: DropsWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .systemSmall:
            smallWidgetView
        default:
            smallWidgetView
        }
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "mic.fill")
                .font(.title2)
        }
        .widgetURL(URL(string: "drops://record"))
    }

    private var smallWidgetView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.accentColor.gradient)

            VStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)

                Text("Drops")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .widgetURL(URL(string: "drops://record"))
    }
}

struct DropsWidget: Widget {
    let kind: String = "DropsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DropsWidgetProvider()) { entry in
            DropsWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Drops")
        .description("빠르게 음성 메모를 시작하세요")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    DropsWidget()
} timeline: {
    DropsWidgetEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    DropsWidget()
} timeline: {
    DropsWidgetEntry(date: .now)
}
