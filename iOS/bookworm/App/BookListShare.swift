import ImageIO
import UIKit

enum BookListShareLayout: Equatable, Sendable {
    case list
    case grid
}

struct BookListShareItem: Sendable {
    let book: ReadingBook
    let details: [String]
}

struct BookListShareExport: Identifiable, Sendable {
    let directory: URL
    let file: URL

    var id: URL { directory }
}

enum BookListShareRenderer {
    private enum ExportError: Error {
        case emptyList
        case encodingFailed
    }

    private struct ImageStrip {
        var rows: [Range<Int>] = []
        var height: CGFloat = 0
    }

    private static let width: CGFloat = 960
    private static let sideMargin: CGFloat = 44
    private static let headerHeight: CGFloat = 163
    private static let bottomMargin: CGFloat = 30
    private static let maximumStripHeight: CGFloat = 4_096
    private static let columnGap: CGFloat = 20
    private static let gridCoverWidth = (width - sideMargin * 2 - columnGap * 3) / 4
    private static let gridCoverHeight = (gridCoverWidth / 0.7).rounded()
    private static let maximumCoverBytes = 3 * 1_024 * 1_024

    private static let ink = UIColor(red: 0.09, green: 0.13, blue: 0.19, alpha: 1)
    private static let secondary = UIColor(red: 0.33, green: 0.38, blue: 0.45, alpha: 1)
    private static let metadataDivider = UIColor(white: 224.0 / 255, alpha: 1)
    private static let border = UIColor(red: 0.89, green: 0.91, blue: 0.94, alpha: 1)
    private static let placeholder = UIColor(red: 0.91, green: 0.95, blue: 0.99, alpha: 1)
    private static let accent = UIColor(red: 0.20, green: 0.37, blue: 0.58, alpha: 1)

    static func render(items: [BookListShareItem], layout: BookListShareLayout) async throws -> BookListShareExport {
        guard !items.isEmpty else { throw ExportError.emptyList }
        try Task.checkCancellation()
        let strips = makeStrips(for: items, layout: layout)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("bookworm-share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var complete = false
        defer { if !complete { try? FileManager.default.removeItem(at: directory) } }

        let session = items.contains { canDownload($0.book.coverURL) } ? coverSession() : nil
        let coverCutoff = ContinuousClock.now.advanced(by: .seconds(6))
        defer { session?.invalidateAndCancel() }

        let destination = directory.appendingPathComponent("我的书单.png")
        let height = strips.reduce(0) { $0 + Int($1.height) }
        let writer = try BookListPNGWriter(to: destination, width: Int(width), height: height)
        for (index, strip) in strips.enumerated() {
            try Task.checkCancellation()
            let urls = Set(strip.rows.flatMap { row in items[row].compactMap { $0.book.coverURL } })
            let covers = await loadCovers(from: urls, session: session, cutoff: coverCutoff)
            try Task.checkCancellation()
            try appendStrip(
                strip, includesHeader: index == 0, items: items,
                layout: layout, covers: covers, to: writer
            )
        }
        try Task.checkCancellation()
        try writer.finish()
        complete = true
        return BookListShareExport(directory: directory, file: destination)
    }

    private static func makeStrips(for items: [BookListShareItem], layout: BookListShareLayout) -> [ImageStrip] {
        var strips: [ImageStrip] = []
        var strip = ImageStrip(height: headerHeight)
        let columns = layout == .grid ? 4 : 1
        for start in stride(from: 0, to: items.count, by: columns) {
            let row = start..<min(start + columns, items.count)
            let height = rowHeight(items[start], layout: layout)
            if !strip.rows.isEmpty, strip.height + height + bottomMargin > maximumStripHeight {
                strips.append(strip)
                strip = ImageStrip()
            }
            strip.rows.append(row)
            strip.height += height
        }
        strip.height += bottomMargin
        strips.append(strip)
        return strips
    }

    private static func rowHeight(_ item: BookListShareItem, layout: BookListShareLayout) -> CGFloat {
        switch layout {
        case .grid: gridCoverHeight + 78
        case .list: max(180, 93 + CGFloat(item.details.count) * 33)
        }
    }

    private static func appendStrip(
        _ strip: ImageStrip, includesHeader: Bool, items: [BookListShareItem],
        layout: BookListShareLayout, covers: [URL: UIImage], to writer: BookListPNGWriter
    ) throws {
        try autoreleasepool {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            format.preferredRange = .standard
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: strip.height), format: format)
            let image = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: strip.height))
                if includesHeader {
                    drawText("我的书单", in: CGRect(x: sideMargin, y: 32, width: 600, height: 66),
                             size: 53, weight: .bold, color: ink)
                    drawText("共 \(items.count) 本", in: CGRect(x: sideMargin, y: 102, width: 500, height: 36),
                             size: 27, color: secondary)
                    border.setFill()
                    context.fill(CGRect(x: sideMargin, y: 145, width: width - sideMargin * 2, height: 2))
                }

                var y = includesHeader ? headerHeight : 0
                for row in strip.rows {
                    let rowHeight = rowHeight(items[row.lowerBound], layout: layout)
                    switch layout {
                    case .grid:
                        for (column, item) in items[row].enumerated() {
                            let x = sideMargin + CGFloat(column) * (gridCoverWidth + columnGap)
                            let cover = CGRect(x: x, y: y, width: gridCoverWidth, height: gridCoverHeight)
                            drawCover(item.book.coverURL.flatMap { covers[$0] }, in: cover, context: context.cgContext)
                            drawText(item.book.title,
                                     in: CGRect(x: x, y: cover.maxY + 12, width: cover.width, height: 38),
                                     size: 26, weight: .medium, color: ink)
                        }
                    case .list:
                        let item = items[row.lowerBound]
                        let cover = CGRect(x: sideMargin, y: y + (rowHeight - 145) / 2, width: 101, height: 145)
                        drawCover(item.book.coverURL.flatMap { covers[$0] }, in: cover, context: context.cgContext)
                        let x = cover.maxX + 30
                        let textWidth = width - x - sideMargin
                        let textTop = y + (rowHeight - 46 - CGFloat(item.details.count) * 33) / 2
                        drawText(item.book.title, in: CGRect(x: x, y: textTop, width: textWidth, height: 46),
                                 size: 33, weight: .semibold, color: ink)
                        for (line, detail) in item.details.enumerated() {
                            let isAuthor = line == 0 && detail == item.book.author
                            drawText(detail,
                                     in: CGRect(x: x, y: textTop + 46 + CGFloat(line) * 33, width: textWidth, height: 33),
                                     size: 25, color: secondary, stylesMetadataDivider: !isAuthor)
                        }
                        border.setFill()
                        context.fill(CGRect(x: x, y: y + rowHeight - 1, width: textWidth, height: 1))
                    }
                    y += rowHeight
                }
            }
            guard let image = image.cgImage else { throw ExportError.encodingFailed }
            try writer.append(image)
        }
    }

    private static func drawText(
        _ text: String, in rect: CGRect, size: CGFloat, weight: UIFont.Weight = .regular,
        color: UIColor, stylesMetadataDivider: Bool = false
    ) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.alignment = .left
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let string = text as NSString
        let delimiter = "  |  "
        var separator = string.range(of: delimiter)
        guard stylesMetadataDivider, separator.location != NSNotFound else {
            string.draw(in: rect, withAttributes: attributes)
            return
        }

        let rendered = NSMutableAttributedString(string: text, attributes: attributes)
        let dividerFont = UIFont.systemFont(ofSize: size * 0.72)
        let dividerAttributes: [NSAttributedString.Key: Any] = [
            .font: dividerFont,
            .foregroundColor: metadataDivider,
            .baselineOffset: (font.capHeight - dividerFont.capHeight) / 2
        ]
        while separator.location != NSNotFound {
            rendered.addAttributes(dividerAttributes, range: NSRange(location: separator.location + 2, length: 1))
            let nextStart = NSMaxRange(separator)
            separator = string.range(of: delimiter, range: NSRange(location: nextStart, length: string.length - nextStart))
        }
        rendered.draw(in: rect)
    }

    private static func drawCover(_ image: UIImage?, in rect: CGRect, context: CGContext) {
        let outline = UIBezierPath(roundedRect: rect, cornerRadius: 5)
        context.saveGState()
        outline.addClip()
        placeholder.setFill()
        outline.fill()
        if let image, image.size.width > 0, image.size.height > 0 {
            let scale = max(rect.width / image.size.width, rect.height / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                  width: size.width, height: size.height))
        } else if let symbol = UIImage(systemName: "book.closed", withConfiguration: UIImage.SymbolConfiguration(
            pointSize: rect.width * 0.33, weight: .regular
        ))?.withTintColor(accent, renderingMode: .alwaysOriginal) {
            symbol.draw(at: CGPoint(x: rect.midX - symbol.size.width / 2, y: rect.midY - symbol.size.height / 2))
        }
        context.restoreGState()
        border.setStroke()
        outline.lineWidth = 2
        outline.stroke()
    }

    private static func coverSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 6
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    private static func canDownload(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme?.lowercased() == "https" && url.host?.isEmpty == false && url.user == nil && url.password == nil
    }

    private static func loadCovers(
        from urls: Set<URL>, session: URLSession?, cutoff: ContinuousClock.Instant
    ) async -> [URL: UIImage] {
        var covers: [URL: UIImage] = [:]
        var missing: [URL] = []
        for url in urls {
            if let data = WidgetSnapshotStore.coverData(for: url), let image = coverImage(from: data) {
                covers[url] = image
            } else if canDownload(url) {
                missing.append(url)
            }
        }
        guard let session, !Task.isCancelled, ContinuousClock.now < cutoff else { return covers }
        let workers = min(missing.count, 6)
        await withTaskGroup(of: [URL: UIImage].self) { group in
            for worker in 0..<workers {
                group.addTask { [missing] in
                    var images: [URL: UIImage] = [:]
                    for index in stride(from: worker, to: missing.count, by: workers) {
                        guard !Task.isCancelled, ContinuousClock.now < cutoff else { break }
                        let url = missing[index]
                        images[url] = await downloadCover(at: url, session: session)
                    }
                    return images
                }
            }
            for await images in group {
                covers.merge(images) { cached, _ in cached }
            }
        }
        return covers
    }

    private static func downloadCover(at url: URL, session: URLSession) async -> UIImage? {
        guard let (bytes, response) = try? await session.bytes(from: url) else { return nil }
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode),
              canDownload(response.url), response.expectedContentLength <= Int64(maximumCoverBytes) else { return nil }
        var data = Data()
        do {
            for try await byte in bytes {
                guard data.count < maximumCoverBytes else { return nil }
                data.append(byte)
            }
            try Task.checkCancellation()
        } catch {
            return nil
        }
        return coverImage(from: data)
    }

    private static func coverImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 480
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: thumbnail)
    }
}
