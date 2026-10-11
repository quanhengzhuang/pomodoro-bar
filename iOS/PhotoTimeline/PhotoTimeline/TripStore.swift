import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct Trip: Codable, Identifiable {
    var id: UUID
    var title: String
    var createdAt: Date
    var points: [PhotoPoint]
}

struct PhotoPoint: Codable, Identifiable {
    var id: UUID
    var originalName: String
    var thumbnailName: String
    var capturedAt: Date?
    var note: String
    var addedAt: Date
}

struct ImportResult {
    var imported: Int = 0
    var failed: Int = 0
    var missingTimes: Int = 0
}

enum TripStoreError: LocalizedError {
    case noImage
    case invalidImage
    case missingTrip
    case unreadableLibrary

    var errorDescription: String? {
        switch self {
        case .noImage: return "无法读取所选照片。"
        case .invalidImage: return "照片格式无法识别。"
        case .missingTrip: return "找不到这段行程。"
        case .unreadableLibrary: return "已保存的行程暂时无法读取，请先检查 App 数据。"
        }
    }
}

@MainActor
final class TripStore: ObservableObject {
    @Published private(set) var trips: [Trip] = []
    @Published private(set) var loadError: String?

    private let rootURL: URL
    private let originalsURL: URL
    private let thumbnailsURL: URL
    private let manifestURL: URL

    init() {
        rootURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PhotoTimeline", isDirectory: true)
        originalsURL = rootURL.appendingPathComponent("Originals", isDirectory: true)
        thumbnailsURL = rootURL.appendingPathComponent("Thumbnails", isDirectory: true)
        manifestURL = rootURL.appendingPathComponent("trips.json")

        do {
            try FileManager.default.createDirectory(at: originalsURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: thumbnailsURL, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: manifestURL.path) {
                let data = try Data(contentsOf: manifestURL)
                trips = try Self.decoder.decode([Trip].self, from: data)
            }
        } catch {
            loadError = "无法读取已保存的行程：\(error.localizedDescription)"
        }
    }

    func trip(id: UUID) -> Trip? { trips.first { $0.id == id } }

    func thumbnailURL(for point: PhotoPoint) -> URL {
        thumbnailsURL.appendingPathComponent(point.thumbnailName)
    }

    func addTrip(title: String) throws -> UUID {
        let id = UUID()
        var updated = trips
        updated.insert(Trip(id: id, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: Date(), points: []), at: 0)
        try persist(updated)
        return id
    }

    func renameTrip(id: UUID, title: String) throws {
        var updated = trips
        guard let index = updated.firstIndex(where: { $0.id == id }) else { throw TripStoreError.missingTrip }
        updated[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try persist(updated)
    }

    func updatePoint(tripID: UUID, pointID: UUID, capturedAt: Date?, note: String) throws {
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }),
              let pointIndex = updated[tripIndex].points.firstIndex(where: { $0.id == pointID })
        else { throw TripStoreError.missingTrip }
        updated[tripIndex].points[pointIndex].capturedAt = capturedAt
        updated[tripIndex].points[pointIndex].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try persist(updated)
    }

    func importPhotos(_ items: [PhotosPickerItem], into tripID: UUID) async -> ImportResult {
        var result = ImportResult()
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw TripStoreError.noImage
                }
                let image = try PhotoMetadata.read(data)
                let id = UUID()
                let originalName = "\(id.uuidString).\(image.fileExtension)"
                let thumbnailName = "\(id.uuidString).jpg"
                let originalURL = originalsURL.appendingPathComponent(originalName)
                let thumbnailURL = thumbnailsURL.appendingPathComponent(thumbnailName)
                do {
                    try data.write(to: originalURL, options: .atomic)
                    try image.thumbnail.write(to: thumbnailURL, options: .atomic)
                    var updated = trips
                    guard let index = updated.firstIndex(where: { $0.id == tripID }) else {
                        throw TripStoreError.missingTrip
                    }
                    updated[index].points.append(PhotoPoint(id: id, originalName: originalName,
                        thumbnailName: thumbnailName, capturedAt: image.capturedAt,
                        note: "", addedAt: Date()))
                    try persist(updated)
                    result.imported += 1
                    if image.capturedAt == nil { result.missingTimes += 1 }
                } catch {
                    try? FileManager.default.removeItem(at: originalURL)
                    try? FileManager.default.removeItem(at: thumbnailURL)
                    throw error
                }
            } catch {
                result.failed += 1
            }
        }
        return result
    }

    private func persist(_ updated: [Trip]) throws {
        guard loadError == nil else { throw TripStoreError.unreadableLibrary }
        let data = try Self.encoder.encode(updated)
        try data.write(to: manifestURL, options: .atomic)
        trips = updated
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private enum PhotoMetadata {
    struct ImageInfo {
        let capturedAt: Date?
        let fileExtension: String
        let thumbnail: Data
    }

    static func read(_ data: Data) throws -> ImageInfo {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) as String?,
              let imageType = UTType(type),
              let fileExtension = imageType.preferredFilenameExtension,
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 1200
              ] as CFDictionary),
              let thumbnail = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.82)
        else { throw TripStoreError.invalidImage }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let timestamp = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        let offset = (exif?[kCGImagePropertyExifOffsetTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifOffsetTimeDigitized] as? String)
        return ImageInfo(capturedAt: parseDate(timestamp, offset: offset),
                         fileExtension: fileExtension, thumbnail: thumbnail)
    }

    private static func parseDate(_ timestamp: String?, offset: String?) -> Date? {
        guard let timestamp else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        if let offset, !offset.isEmpty {
            let normalized = offset.replacingOccurrences(of: ":", with: "")
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssZ"
            return formatter.date(from: timestamp + normalized)
        }
        // EXIF often omits a zone; use the device's zone and let the user correct it.
        formatter.timeZone = .current
        return formatter.date(from: timestamp)
    }
}
