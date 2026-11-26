import Foundation

struct ReadingProgress: Codable, Equatable, Sendable {
    let totalReadingSeconds: Int?
    let progressPercentage: Int?
    let lastReadAt: Date?
    let finishedAt: Date?
}

struct BookMetadata: Codable, Sendable {
    let recommendation: Double?
    let wordCount: Int?
    let publicReaderCount: Int?
    let wordCountIsApproximate: Bool?
    let detailURL: URL?

    init(
        recommendation: Double?, wordCount: Int?, publicReaderCount: Int? = nil,
        wordCountIsApproximate: Bool? = nil, detailURL: URL? = nil
    ) {
        self.recommendation = recommendation
        self.wordCount = wordCount
        self.publicReaderCount = publicReaderCount
        self.wordCountIsApproximate = wordCountIsApproximate
        self.detailURL = detailURL
    }
}

struct WeReadAPI {
    struct Shelf {
        let books: [ReadingBook]
        let hasSkillUpgrade: Bool
    }

    struct PublicBookMetadata: Sendable {
        let readerCount: Int?
        let wordCount: Int?
    }

    enum Failure: LocalizedError {
        case unauthorized
        case gateway(Int)
        case unexpectedResponse

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                "微信读书未能验证 API Key，请在设置中检查或更换。"
            case let .gateway(code):
                "微信读书同步失败（\(code)）。请检查 API Key 或稍后重试。"
            case .unexpectedResponse:
                "微信读书返回的数据格式有误，请稍后重试。"
            }
        }
    }

    private static let gateway = URL(string: "https://i.weread.qq.com/api/agent/gateway")!
    private static let maximumPublicPageBytes = 2 * 1_024 * 1_024
    private static let anonymousSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration, delegate: PublicBookPageRedirects(), delegateQueue: nil)
    }()
    private let session: URLSession
    private let publicSession: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral), publicSession: URLSession? = nil) {
        self.session = session
        self.publicSession = publicSession ?? Self.anonymousSession
    }

    func fetchShelf(apiKey: String) async throws -> Shelf {
        let shelf: ShelfResponse = try await request("/shelf/sync", apiKey: apiKey)
        guard let books = shelf.books ?? (shelf.bookCount == 0 ? [] : nil) else {
            throw Failure.unexpectedResponse
        }

        var ids = Set<String>()
        return Shelf(
            books: books.map(\.readingBook).filter { ids.insert($0.id).inserted },
            hasSkillUpgrade: shelf.upgradeInfo != nil
        )
    }

    func fetchProgress(bookID: String, apiKey: String) async throws -> ReadingProgress {
        let response: ProgressResponse = try await request(
            "/book/getprogress", parameters: ["bookId": bookID], apiKey: apiKey
        )
        guard let book = response.book, response.bookId == nil || response.bookId == bookID else {
            throw Failure.unexpectedResponse
        }
        return book.readingProgress
    }

    func fetchBookMetadata(bookID: String, apiKey: String) async throws -> BookMetadata {
        let response: BookInfoResponse = try await request(
            "/book/info", parameters: ["bookId": bookID], apiKey: apiKey
        )
        guard response.bookId == bookID else { throw Failure.unexpectedResponse }
        return response.metadata
    }

    func fetchChapterWordCount(bookID: String, apiKey: String) async throws -> Int? {
        let response: ChapterInfoResponse = try await request(
            "/book/chapterinfo", parameters: ["bookId": bookID], apiKey: apiKey
        )
        guard response.bookId == nil || response.bookId == bookID else { throw Failure.unexpectedResponse }
        return response.totalWordCount
    }

    func fetchPublicBookMetadata(bookID: String, links: [URL?]) async throws -> PublicBookMetadata? {
        guard let url = links.lazy.compactMap({ PublicBookPage.canonicalURL(from: $0) }).first else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        request.httpShouldHandleCookies = false
        let (bytes, response) = try await publicSession.bytes(for: request)
        defer { bytes.task.cancel() }
        guard let response = response as? HTTPURLResponse, response.url == url else { throw Failure.unexpectedResponse }
        if response.statusCode == 404 || response.statusCode == 410 { return nil }
        guard (200..<300).contains(response.statusCode) else { throw Failure.gateway(response.statusCode) }
        guard response.expectedContentLength <= Int64(Self.maximumPublicPageBytes) else { return nil }

        var data = Data()
        for try await byte in bytes {
            guard data.count < Self.maximumPublicPageBytes else { return nil }
            data.append(byte)
        }
        return PublicBookPage.metadata(in: data, bookID: bookID)
    }

    private func request<Response: GatewayResponse>(
        _ endpoint: String, parameters: [String: String] = [:], apiKey: String
    ) async throws -> Response {
        var request = URLRequest(url: Self.gateway, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = parameters
        body["api_name"] = endpoint
        body["skill_version"] = "1.0.6"
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.unexpectedResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw Failure.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw Failure.gateway(http.statusCode) }
        guard let payload = try? JSONDecoder().decode(Response.self, from: data) else {
            throw Failure.unexpectedResponse
        }
        if let code = payload.errcode, code != 0 { throw Failure.gateway(code) }
        return payload
    }
}

private protocol GatewayResponse: Decodable {
    var errcode: Int? { get }
}

private struct ShelfResponse: GatewayResponse {
    let errcode: Int?
    let books: [ShelfBook]?
    let bookCount: Int?
    let upgradeInfo: UpgradeInfo?

    enum CodingKeys: String, CodingKey {
        case errcode, books, bookCount
        case upgradeInfo = "upgrade_info"
    }

    struct UpgradeInfo: Decodable {}
}

private struct BookInfoResponse: GatewayResponse {
    let errcode: Int?
    let bookId: String?
    let metadata: BookMetadata

    private enum CodingKeys: String, CodingKey {
        case errcode, bookId, newRating, newRatingCount, wordCount, deepLink
    }

    init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        errcode = try fields.decodeIfPresent(Int.self, forKey: .errcode)
        bookId = try fields.decodeIfPresent(String.self, forKey: .bookId)
        let ratingCount = try? fields.decode(Int.self, forKey: .newRatingCount)
        let rating = try? fields.decode(Double.self, forKey: .newRating)
        metadata = BookMetadata(
            recommendation: ratingCount == 0 ? nil : rating.flatMap(Self.recommendationPercent),
            wordCount: fields.losslessInteger(forKey: .wordCount).flatMap { $0 > 0 ? $0 : nil },
            detailURL: validatedReadingURL(try? fields.decode(String.self, forKey: .deepLink))
        )
    }

    private static func recommendationPercent(_ rating: Double) -> Double? {
        // Older gateway responses encode the percentage in tenths (WeChatReading issue #8).
        guard (0...1_000).contains(rating) else { return nil }
        return rating > 100 ? rating / 10 : rating
    }
}

private struct ChapterInfoResponse: GatewayResponse {
    let errcode: Int?
    let bookId: String?
    let chapters: [Chapter]?

    struct Chapter: Decodable {
        let chapterUid: Int?
        let wordCount: Int?

        private enum CodingKeys: String, CodingKey { case chapterUid, wordCount }

        init(from decoder: any Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            chapterUid = fields.losslessInteger(forKey: .chapterUid)
            wordCount = fields.losslessInteger(forKey: .wordCount)
        }
    }

    var totalWordCount: Int? {
        guard let chapters else { return nil }
        var chapterCounts: [Int: Int] = [:]
        var total = 0
        for chapter in chapters {
            guard let id = chapter.chapterUid, id >= 0,
                  let count = chapter.wordCount, count >= 0 else { return nil }
            if let previousCount = chapterCounts.updateValue(count, forKey: id) {
                guard previousCount == count else { return nil }
                continue
            }
            let (sum, overflow) = total.addingReportingOverflow(count)
            guard !overflow else { return nil }
            total = sum
        }
        return total > 0 ? total : nil
    }
}

private final class PublicBookPageRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private enum PublicBookPage {
    private static let host = "weread.qq.com"

    static func canonicalURL(from url: URL?) -> URL? {
        guard let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https", components.host?.lowercased() == host,
              components.port == nil || components.port == 443,
              components.user == nil, components.password == nil else { return nil }

        let token: String?
        let path = components.path.split(separator: "/", omittingEmptySubsequences: false)
        if path.count == 4, path[0].isEmpty, path[1] == "web", path[2] == "reader" || path[2] == "bookDetail" {
            token = String(path[3])
        } else if components.path == "/book-detail" {
            let matches = components.queryItems?.filter { $0.name == "v" }
            token = matches?.count == 1 ? matches?.first?.value : nil
        } else {
            token = nil
        }

        guard let token, (8...200).contains(token.utf8.count), token.utf8.allSatisfy({ byte in
            (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte) || byte == 45 || byte == 95
        }) else { return nil }
        return URL(string: "https://\(host)/web/bookDetail/\(token)")
    }

    static func metadata(in data: Data, bookID: String) -> WeReadAPI.PublicBookMetadata? {
        guard let html = String(data: data, encoding: .utf8),
              let assignment = html.range(
                  of: #"<script(?:\s+[^>]*)?>\s*window\.__INITIAL_STATE__\s*=\s*"#, options: .regularExpression
              ),
              let json = firstJSONObject(in: html[assignment.upperBound...]),
              let reader = try? JSONDecoder().decode(PageState.self, from: Data(json.utf8)).reader,
              reader.bookInfo.bookId == bookID else { return nil }
        return WeReadAPI.PublicBookMetadata(
            readerCount: reader.readingStat?.readingCount.flatMap { $0 > 0 ? $0 : nil },
            wordCount: reader.bookInfo.totalWords.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    private static func firstJSONObject(in text: Substring) -> Substring? {
        guard text.utf8.first == 123 else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        for index in text.utf8.indices {
            let byte = text.utf8[index]
            if inString {
                if escaped {
                    escaped = false
                } else if byte == 92 {
                    escaped = true
                } else if byte == 34 {
                    inString = false
                }
            } else if byte == 34 {
                inString = true
            } else if byte == 123 {
                depth += 1
            } else if byte == 125 {
                depth -= 1
                if depth == 0 { return text[...index] }
            }
        }
        return nil
    }

    private struct PageState: Decodable {
        let reader: Reader

        struct Reader: Decodable {
            let bookInfo: BookInfo
            let readingStat: ReadingStat?

            struct BookInfo: Decodable {
                let bookId: String
                let totalWords: Int?
            }

            struct ReadingStat: Decodable {
                let readingCount: Int?
            }
        }
    }
}

private extension KeyedDecodingContainer {
    func losslessInteger(forKey key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        return (try? decode(String.self, forKey: key)).flatMap { Int($0) }
    }
}

private struct ProgressResponse: GatewayResponse {
    let errcode: Int?
    let bookId: String?
    let book: Book?

    struct Book: Decodable {
        let progress: Int?
        let readingTime: Int?
        let recordReadingTime: Int?
        let updateTime: TimeInterval?
        let finishTime: TimeInterval?

        var readingProgress: ReadingProgress {
            ReadingProgress(
                totalReadingSeconds: [readingTime, recordReadingTime].compactMap { $0 }.first { $0 > 0 },
                progressPercentage: progress.flatMap { (0...100).contains($0) ? $0 : nil },
                lastReadAt: readingDate(updateTime),
                finishedAt: progress == 100 ? readingDate(finishTime) : nil
            )
        }

        private func readingDate(_ value: TimeInterval?) -> Date? {
            value.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
        }
    }
}

private struct ShelfBook: Decodable {
    let bookId: String
    let title: String
    let author: String?
    let cover: String?
    let readerLink: String?
    let deepLink: String?
    let readUpdateTime: TimeInterval?
    let secret: Int?

    var readingBook: ReadingBook {
        ReadingBook(
            id: bookId,
            title: title,
            author: author,
            coverURL: coverURL,
            readerURL: validatedReadingURL(readerLink),
            detailURL: validatedReadingURL(deepLink),
            lastReadAt: readUpdateTime.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
            isPrivate: secret == 1
        )
    }

    private var coverURL: URL? {
        guard let cover, var components = URLComponents(string: cover),
              components.host?.isEmpty == false else { return nil }

        switch components.scheme?.lowercased() {
        case nil, "http":
            components.scheme = "https"
            if components.port == 80 { components.port = nil }
        case "https":
            break
        default:
            return nil
        }
        return components.url
    }

}

private func validatedReadingURL(_ value: String?) -> URL? {
    guard let value, let url = URL(string: value), let scheme = url.scheme?.lowercased(),
          scheme == "weread" || (scheme == "https" && url.host?.isEmpty == false) else { return nil }
    return url
}
