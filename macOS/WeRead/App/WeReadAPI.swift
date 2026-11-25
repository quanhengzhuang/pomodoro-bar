import Foundation

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
                "微信读书返回的书架数据格式有误，请稍后重试。"
            }
        }
    }

    private static let gateway = URL(string: "https://i.weread.qq.com/api/agent/gateway")!
    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func fetchShelf(apiKey: String) async throws -> Shelf {
        var request = URLRequest(url: Self.gateway, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "api_name": "/shelf/sync",
            "skill_version": "1.0.6"
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw Failure.unexpectedResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw Failure.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw Failure.gateway(http.statusCode) }
        guard let shelf = try? JSONDecoder().decode(ShelfResponse.self, from: data) else {
            throw Failure.unexpectedResponse
        }
        if let code = shelf.errcode, code != 0 { throw Failure.gateway(code) }
        guard let books = shelf.books ?? (shelf.bookCount == 0 ? [] : nil) else {
            throw Failure.unexpectedResponse
        }

        var ids = Set<String>()
        return Shelf(
            books: books.map(\.readingBook).filter { ids.insert($0.id).inserted },
            hasSkillUpgrade: shelf.upgradeInfo != nil
        )
    }
}

private struct ShelfResponse: Decodable {
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
            coverURL: validatedURL(cover, schemes: ["https"]),
            readerURL: validatedURL(readerLink, schemes: ["https", "weread"]),
            detailURL: validatedURL(deepLink, schemes: ["https", "weread"]),
            lastReadAt: readUpdateTime.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil },
            isPrivate: secret == 1
        )
    }

    private func validatedURL(_ value: String?, schemes: Set<String>) -> URL? {
        guard let value, let url = URL(string: value), let scheme = url.scheme?.lowercased(),
              schemes.contains(scheme), scheme == "weread" || url.host?.isEmpty == false else { return nil }
        return url
    }
}
