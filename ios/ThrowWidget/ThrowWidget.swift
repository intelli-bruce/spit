import WidgetKit
import SwiftUI

struct ThrowWidgetEntry: TimelineEntry {
    let date: Date
}

struct ThrowWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ThrowWidgetEntry {
        ThrowWidgetEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (ThrowWidgetEntry) -> Void) {
        completion(ThrowWidgetEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ThrowWidgetEntry>) -> Void) {
        let entry = ThrowWidgetEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct ThrowWidgetEntryView: View {
    var entry: ThrowWidgetProvider.Entry
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
        .widgetURL(URL(string: "throw://record"))
    }

    private var smallWidgetView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color.accentColor.gradient)

            VStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)

                Text("Throw")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
        }
        .widgetURL(URL(string: "throw://record"))
    }
}

struct ThrowWidget: Widget {
    let kind: String = "ThrowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ThrowWidgetProvider()) { entry in
            ThrowWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Throw")
        .description("빠르게 음성 메모를 시작하세요")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

#Preview(as: .systemSmall) {
    ThrowWidget()
} timeline: {
    ThrowWidgetEntry(date: .now)
}

#Preview(as: .accessoryCircular) {
    ThrowWidget()
} timeline: {
    ThrowWidgetEntry(date: .now)
}
