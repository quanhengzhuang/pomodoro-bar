import Foundation

struct ReadingProgress: Codable, Equatable, Sendable {
    let totalReadingSeconds: Int?
    let progressPercentage: Int?
    let lastReadAt: Date?
    let finishedAt: Date?
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
            readerURL: validatedURL(readerLink, schemes: ["https", "weread"]),
            detailURL: validatedURL(deepLink, schemes: ["https", "weread"]),
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

    private func validatedURL(_ value: String?, schemes: Set<String>) -> URL? {
        guard let value, let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme), scheme == "weread" || url.host?.isEmpty == false else { return nil }
        return url
    }
}
