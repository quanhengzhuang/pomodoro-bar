import Foundation
import SwiftUI
import WidgetKit

@main
struct ReadingWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentReadingWidget()
        CustomBookListWidget()
    }
}

private struct RecentReadingWidget: Widget {
    var body: some WidgetConfiguration { readingConfiguration(for: .recent) }
}

private struct CustomBookListWidget: Widget {
    var body: some WidgetConfiguration { readingConfiguration(for: .custom) }
}

@MainActor
private func readingConfiguration(for list: ReadingList) -> some WidgetConfiguration {
    StaticConfiguration(kind: list.widgetKind, provider: ReadingTimelineProvider(list: list)) { entry in
        ReadingWidgetView(list: list, entry: entry)
            .containerBackground(.background, for: .widget)
            .widgetURL(list.openURL)
    }
    .configurationDisplayName(list.title)
    .description(list == .recent ? "查看上次同步的阅读记录。" : "查看你在应用里选好的书。")
    .supportedFamilies([.systemSmall, .systemMedium])
}

private struct ReadingEntry: TimelineEntry {
    let date: Date
    let books: [ReadingBook]
    let hasSynced: Bool
}

private struct ReadingTimelineProvider: TimelineProvider {
    let list: ReadingList

    func placeholder(in context: Context) -> ReadingEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(context.isPreview ? previewEntry() : savedEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        // The app requests a new timeline after a sync or a list edit.
        completion(Timeline(entries: [savedEntry()], policy: .never))
    }

    private func savedEntry() -> ReadingEntry {
        let snapshot = WidgetSnapshotStore.load()
        let books = list == .recent ? snapshot.recentBooks : snapshot.customBooks
        return ReadingEntry(date: .now, books: Array(books.prefix(4)), hasSynced: snapshot.lastSyncedAt != nil)
    }

    private func previewEntry() -> ReadingEntry {
        let date = Date.now
        let samples = [
            ("边城", "沈从文"),
            ("城南旧事", "林海音"),
            ("瓦尔登湖", "亨利·戴维·梭罗"),
            ("人间草木", "汪曾祺")
        ]
        let books = samples.enumerated().map { index, sample in
            ReadingBook(
                id: "preview-\(index)", title: sample.0, author: sample.1,
                coverURL: nil, readerURL: nil, detailURL: nil,
                lastReadAt: Calendar.current.date(byAdding: .day, value: -index, to: date), isPrivate: false
            )
        }
        return ReadingEntry(date: date, books: books, hasSynced: true)
    }
}

private struct ReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let list: ReadingList
    let entry: ReadingEntry

    private var accent: Color { list == .recent ? .indigo : .teal }
    private var dateFormat: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent).year().month().day()
    }

    private var emptyMessage: String {
        switch list {
        case .recent:
            entry.hasSynced ? "书架里暂无阅读记录。" : "打开应用同步书架。"
        case .custom:
            "打开应用，从书架选书。"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(list.title)
            } icon: {
                Image(systemName: list.iconName)
                    .foregroundStyle(accent)
                    .widgetAccentable()
            }
            .font(.system(.subheadline, design: .serif, weight: .semibold))
            .accessibilityAddTraits(.isHeader)

            if entry.books.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    shelfColumn(entry.books.prefix(2))
                    if family == .systemMedium {
                        shelfColumn(entry.books.dropFirst(2).prefix(2))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func shelfColumn(_ books: ArraySlice<ReadingBook>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(books) { book in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(accent.opacity(0.65))
                        .frame(width: 3, height: 24)
                        .widgetAccentable()
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title)
                            .font(.system(.caption, weight: .semibold))
                            .lineLimit(1)
                        if list == .recent, let date = book.lastReadAt {
                            Text(date, format: dateFormat)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else if let author = book.author, !author.isEmpty {
                            Text(author)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .privacySensitive(book.isPrivate)
                    .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
