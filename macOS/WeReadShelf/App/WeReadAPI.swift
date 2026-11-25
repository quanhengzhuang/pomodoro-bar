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
    let readingCount: Int?
    let wordCountIsApproximate: Bool?
    let detailURL: URL?

    init(
        recommendation: Double?, wordCount: Int?, readingCount: Int? = nil,
        wordCountIsApproximate: Bool? = nil, detailURL: URL? = nil
    ) {
        self.recommendation = recommendation
        self.wordCount = wordCount
        self.readingCount = readingCount
        self.wordCountIsApproximate = wordCountIsApproximate
        self.detailURL = detailURL
    }
}

struct WeReadAPI {
    struct Shelf {
        let books: [ReadingBook]
        let hasSkillUpgrade: Bool
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
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
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

    func fetchReadingCount(bookID: String, title: String, apiKey: String) async throws -> Int? {
        let response: BookSearchResponse = try await request(
            "/store/search",
            parameters: ["keyword": title, "scope": 10, "context": "查询书虫列表中同一版本书籍的在读人数"],
            apiKey: apiKey
        )
        for group in response.results ?? [] {
            for book in group.books ?? [] where book.bookInfo?.bookId == bookID {
                if let count = book.readingCount, count > 0 { return count }
            }
        }
        return nil
    }

    private func request<Response: GatewayResponse>(
        _ endpoint: String, parameters: [String: Any] = [:], apiKey: String
    ) async throws -> Response {
        var request = URLRequest(url: Self.gateway, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = parameters
        body["api_name"] = endpoint
        body["skill_version"] = "1.0.6"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

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
        case errcode, bookId, newRating, newRatingCount, wordCount, readingCount, deepLink
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
            readingCount: fields.losslessInteger(forKey: .readingCount).flatMap { $0 > 0 ? $0 : nil },
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

private struct BookSearchResponse: GatewayResponse {
    let errcode: Int?
    let results: [Group]?

    struct Group: Decodable {
        let books: [Book]?
    }

    struct Book: Decodable {
        let bookInfo: Info?
        let readingCount: Int?

        struct Info: Decodable {
            let bookId: String?
        }

        private enum CodingKeys: String, CodingKey { case bookInfo, readingCount }

        init(from decoder: any Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            bookInfo = try? fields.decode(Info.self, forKey: .bookInfo)
            readingCount = fields.losslessInteger(forKey: .readingCount)
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
