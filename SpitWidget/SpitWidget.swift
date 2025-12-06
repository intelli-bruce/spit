import WidgetKit
import SwiftUI

struct SpitWidgetEntry: TimelineEntry {
    let date: Date
}

struct SpitWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpitWidgetEntry {
        SpitWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SpitWidgetEntry) -> Void) {
        completion(SpitWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpitWidgetEntry>) -> Void) {
        let entry = SpitWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SpitWidgetEntryView: View {
    var entry: SpitWidgetProvider.Entry
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
        .widgetURL(URL(string: "spit://record"))
    }

    private var smallWidgetView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.accentColor.gradient)

            VStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)

                Text("Spit")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .widgetURL(URL(string: "spit://record"))
    }
}

struct SpitWidget: Widget {
    let kind: String = "SpitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpitWidgetProvider()) { entry in
            SpitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spit")
        .description("빠르게 음성 메모를 시작하세요")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    SpitWidget()
} timeline: {
    SpitWidgetEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    SpitWidget()
} timeline: {
    SpitWidgetEntry(date: .now)
}
