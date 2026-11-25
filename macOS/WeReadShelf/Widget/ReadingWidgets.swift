import Foundation
import SwiftUI
import WidgetKit

#if os(iOS)
import UIKit
#endif

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
#if os(iOS)
        CoverReadingWidgetView(list: list, entry: entry)
            .containerBackground(.background, for: .widget)
#else
        ReadingWidgetView(list: list, entry: entry)
            .containerBackground(.background, for: .widget)
            .widgetURL(list.openURL)
#endif
    }
    .configurationDisplayName(list.title)
    .description(list == .recent ? "查看上次同步的阅读记录。" : "查看你在应用里选好的书。")
    .supportedFamilies([.systemSmall, .systemMedium])
}

private struct ReadingEntry: TimelineEntry {
    let date: Date
    let books: [ReadingBook]
    let hasSynced: Bool
#if os(iOS)
    var covers: [URL: UIImage] = [:]
#endif

    func emptyMessage(for list: ReadingList) -> String {
        switch list {
        case .recent:
            hasSynced ? "书架里暂无阅读记录。" : "打开应用同步书架。"
        case .custom:
            "打开应用，从书架选书。"
        }
    }
}

private struct ReadingTimelineProvider: TimelineProvider {
    let list: ReadingList

    func placeholder(in context: Context) -> ReadingEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(context.isPreview ? previewEntry() : savedEntry(for: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        // The app requests a new timeline after a sync or a list edit.
        completion(Timeline(entries: [savedEntry(for: context.family)], policy: .never))
    }

    private func savedEntry(for family: WidgetFamily) -> ReadingEntry {
        let snapshot = WidgetSnapshotStore.load()
        let books = list == .recent ? snapshot.recentBooks : snapshot.customBooks
#if os(iOS)
        let visibleBooks = Array(books.prefix(family == .systemSmall ? 1 : 4))
        var entry = ReadingEntry(date: .now, books: visibleBooks, hasSynced: snapshot.lastSyncedAt != nil)
        for book in visibleBooks {
            guard let url = book.coverURL, entry.covers[url] == nil,
                  let data = WidgetSnapshotStore.coverData(for: url), let cover = UIImage(data: data) else { continue }
            entry.covers[url] = cover
        }
        return entry
#else
        return ReadingEntry(date: .now, books: Array(books.prefix(4)), hasSynced: snapshot.lastSyncedAt != nil)
#endif
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

#if os(iOS)
private struct CoverReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.displayScale) private var displayScale

    let list: ReadingList
    let entry: ReadingEntry

    private let coverSpacing: CGFloat = 10
    private let coverAspect: CGFloat = 0.7
    private var accent: Color { list == .recent ? .indigo : .teal }

    private var titleFont: Font {
        let name = "PingFangSC-Semibold"
        guard UIFont(name: name, size: 15) != nil else { return .system(.subheadline, weight: .bold) }
        return .custom(name, size: 15, relativeTo: .subheadline)
    }

    private var widgetDestination: URL {
        guard family == .systemSmall, let book = entry.books.first, book.destinationURL != nil else {
            return list.openURL
        }
        return list.widgetBookURL(for: book.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(list.title)
                .font(titleFont)
                .accessibilityAddTraits(.isHeader)

            if entry.books.isEmpty {
                Text(entry.emptyMessage(for: list))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { geometry in
                    if family == .systemSmall, let book = entry.books.first {
                        let height = min(geometry.size.width / coverAspect, geometry.size.height)
                        sizedCover(book, height: height)
                            .privacySensitive(book.isPrivate)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        let width = max(0, (geometry.size.width - coverSpacing * 3) / 4)
                        let height = min(width / coverAspect, geometry.size.height)
                        HStack(spacing: coverSpacing) {
                            ForEach(entry.books.prefix(4)) { book in
                                mediumTile(book, coverHeight: height)
                                    .frame(width: width)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(widgetDestination)
    }

    private func mediumTile(_ book: ReadingBook, coverHeight: CGFloat) -> some View {
        Group {
            if book.destinationURL != nil {
                Link(destination: list.widgetBookURL(for: book.id)) {
                    sizedCover(book, height: coverHeight)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(book.title)
            } else {
                sizedCover(book, height: coverHeight)
            }
        }
        .privacySensitive(book.isPrivate)
    }

    private func sizedCover(_ book: ReadingBook, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return cover(for: book)
            .frame(width: height * coverAspect, height: height)
            .clipShape(shape)
            .overlay {
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(0.07), .clear, .black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    shape.strokeBorder(.primary.opacity(0.24), lineWidth: 1 / displayScale)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(book.title)
    }

    @ViewBuilder
    private func cover(for book: ReadingBook) -> some View {
        if let url = book.coverURL, let cover = entry.covers[url] {
            let image = Image(uiImage: cover).resizable()
            if #available(iOS 18.0, *) {
                image.widgetAccentedRenderingMode(.fullColor).scaledToFit()
            } else {
                image.scaledToFit()
            }
        } else {
            ZStack(alignment: .leading) {
                Rectangle().fill(accent.opacity(0.14))
                Rectangle().fill(accent.opacity(0.48)).frame(width: 2)
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
#else
private struct ReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let list: ReadingList
    let entry: ReadingEntry

    private var accent: Color { list == .recent ? .indigo : .teal }
    private var dateFormat: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(timeZone: .autoupdatingCurrent).year().month().day()
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
                Text(entry.emptyMessage(for: list))
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
#endif
