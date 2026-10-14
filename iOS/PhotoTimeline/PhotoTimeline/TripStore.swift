import Foundation
import CoreLocation
import ImageIO
import Photos
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
    var framingX: Double? = nil
    var framingY: Double? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var placeName: String? = nil
}

struct ImportResult {
    var imported: Int = 0
    var failed: Int = 0
    var missingTimes: Int = 0
}

private struct DeletedPointBackup: Codable {
    let tripID: UUID
    let tripTitle: String
    let point: PhotoPoint
    let deletedAt: Date
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
    private var locatingTrips: Set<UUID> = []
    private var needsLocationRefresh: Set<UUID> = []

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

    func updatePoint(tripID: UUID, pointID: UUID, note: String,
                     framingX: Double, framingY: Double) throws {
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }),
              let pointIndex = updated[tripIndex].points.firstIndex(where: { $0.id == pointID })
        else { throw TripStoreError.missingTrip }
        updated[tripIndex].points[pointIndex].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updated[tripIndex].points[pointIndex].framingX = min(max(framingX, 0), 1)
        updated[tripIndex].points[pointIndex].framingY = min(max(framingY, 0), 1)
        try persist(updated)
    }

    func populateLocations(in tripID: UUID) async {
        guard loadError == nil, trip(id: tripID) != nil else { return }
        if locatingTrips.contains(tripID) {
            needsLocationRefresh.insert(tripID)
            return
        }
        locatingTrips.insert(tripID)
        defer { locatingTrips.remove(tripID) }

        let geocoder = CLGeocoder()
        var queued = trip(id: tripID)?.points.map(\.id) ?? []
        while !queued.isEmpty && !Task.isCancelled {
            let pointID = queued.removeFirst()
            guard !Task.isCancelled,
                  let point = trip(id: tripID)?.points.first(where: { $0.id == pointID }) else { continue }

            if point.latitude == nil || point.longitude == nil,
               let coordinate = PhotoMetadata.readGPS(from: originalsURL.appendingPathComponent(point.originalName)) {
                try? updateLocation(tripID: tripID, pointID: pointID, coordinate: coordinate)
            }

            if let current = trip(id: tripID)?.points.first(where: { $0.id == pointID }),
               current.placeName == nil,
               let latitude = current.latitude, let longitude = current.longitude {
                let location = CLLocation(latitude: latitude, longitude: longitude)
                if let placemark = try? await geocoder.reverseGeocodeLocation(
                    location, preferredLocale: Locale(identifier: "zh_CN")).first,
                   let name = Self.placeName(from: placemark) {
                    try? updateLocation(tripID: tripID, pointID: pointID, placeName: name)
                }
            }
            if queued.isEmpty, needsLocationRefresh.remove(tripID) != nil {
                queued = trip(id: tripID)?.points.map(\.id) ?? []
            }
        }
    }

    private func updateLocation(tripID: UUID, pointID: UUID,
                                coordinate: CLLocationCoordinate2D? = nil,
                                placeName: String? = nil) throws {
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }),
              let pointIndex = updated[tripIndex].points.firstIndex(where: { $0.id == pointID })
        else { throw TripStoreError.missingTrip }
        if let coordinate {
            updated[tripIndex].points[pointIndex].latitude = coordinate.latitude
            updated[tripIndex].points[pointIndex].longitude = coordinate.longitude
        }
        if let placeName, updated[tripIndex].points[pointIndex].placeName == nil {
            updated[tripIndex].points[pointIndex].placeName = placeName
        }
        try persist(updated)
    }

    private static func placeName(from placemark: CLPlacemark) -> String? {
        if let interest = placemark.areasOfInterest?.first(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            return interest
        }
        let parts = [placemark.locality ?? placemark.administrativeArea,
                     placemark.subLocality]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? placemark.name : parts.joined(separator: " · ")
    }

    func deletePoint(tripID: UUID, pointID: UUID) throws {
        guard loadError == nil else { throw TripStoreError.unreadableLibrary }
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }),
              let pointIndex = updated[tripIndex].points.firstIndex(where: { $0.id == pointID })
        else { throw TripStoreError.missingTrip }

        let trip = updated[tripIndex]
        let point = trip.points[pointIndex]
        let originalURL = originalsURL.appendingPathComponent(point.originalName)
        let thumbnailURL = thumbnailsURL.appendingPathComponent(point.thumbnailName)
        let backupURL = rootURL.appendingPathComponent("Backups/DeletedPoints/\(point.id.uuidString)",
                                                       isDirectory: true)
        let backupOriginalsURL = backupURL.appendingPathComponent("Originals", isDirectory: true)
        let backupThumbnailsURL = backupURL.appendingPathComponent("Thumbnails", isDirectory: true)
        try FileManager.default.createDirectory(at: backupOriginalsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupThumbnailsURL, withIntermediateDirectories: true)
        let backup = DeletedPointBackup(tripID: trip.id, tripTitle: trip.title,
                                        point: point, deletedAt: Date())
        try Self.encoder.encode(backup).write(
            to: backupURL.appendingPathComponent("point.json"), options: .atomic)
        let backupManifestURL = backupURL.appendingPathComponent("trips-before-delete.json")
        if !FileManager.default.fileExists(atPath: backupManifestURL.path) {
            try FileManager.default.copyItem(at: manifestURL, to: backupManifestURL)
        }
        for (source, directory) in [(originalURL, backupOriginalsURL),
                                     (thumbnailURL, backupThumbnailsURL)] {
            let destination = directory.appendingPathComponent(source.lastPathComponent)
            if FileManager.default.fileExists(atPath: source.path),
               !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: source, to: destination)
            }
        }

        updated[tripIndex].points.remove(at: pointIndex)
        try persist(updated)
        // The backup keeps both images recoverable even if cleanup succeeds.
        try? FileManager.default.removeItem(at: originalURL)
        try? FileManager.default.removeItem(at: thumbnailURL)
    }

    func importPhotos(_ items: [PhotosPickerItem], into tripID: UUID) async -> ImportResult {
        var result = ImportResult()
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw TripStoreError.noImage
                }
                if try importPhoto(data, into: tripID) { result.missingTimes += 1 }
                result.imported += 1
            } catch {
                result.failed += 1
            }
        }
        return result
    }

    func importPhotos(_ assets: [PHAsset], into tripID: UUID) async -> ImportResult {
        var result = ImportResult()
        for asset in assets {
            do {
                guard let data = await Self.imageData(for: asset) else { throw TripStoreError.noImage }
                if try importPhoto(data, into: tripID, capturedAt: asset.creationDate,
                                   coordinate: asset.location?.coordinate) {
                    result.missingTimes += 1
                }
                result.imported += 1
            } catch {
                result.failed += 1
            }
        }
        return result
    }

    private static func imageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .original
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) {
                data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private func importPhoto(_ data: Data, into tripID: UUID, capturedAt: Date? = nil,
                             coordinate: CLLocationCoordinate2D? = nil) throws -> Bool {
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
            let date = capturedAt ?? image.capturedAt
            var point = PhotoPoint(id: id, originalName: originalName,
                thumbnailName: thumbnailName, capturedAt: date,
                note: "", addedAt: Date())
            point.latitude = (image.coordinate ?? coordinate)?.latitude
            point.longitude = (image.coordinate ?? coordinate)?.longitude
            updated[index].points.append(point)
            try persist(updated)
            return date == nil
        } catch {
            try? FileManager.default.removeItem(at: originalURL)
            try? FileManager.default.removeItem(at: thumbnailURL)
            throw error
        }
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
        let coordinate: CLLocationCoordinate2D?
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
                         coordinate: gpsCoordinate(in: properties),
                         fileExtension: fileExtension, thumbnail: thumbnail)
    }

    static func readGPS(from url: URL) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        return gpsCoordinate(in: properties)
    }

    private static func gpsCoordinate(in properties: [CFString: Any]?) -> CLLocationCoordinate2D? {
        guard let gps = properties?[kCGImagePropertyGPSDictionary] as? [CFString: Any],
              let rawLatitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let rawLongitude = gps[kCGImagePropertyGPSLongitude] as? Double else { return nil }
        let latitude = (gps[kCGImagePropertyGPSLatitudeRef] as? String) == "S" ? -rawLatitude : rawLatitude
        let longitude = (gps[kCGImagePropertyGPSLongitudeRef] as? String) == "W" ? -rawLongitude : rawLongitude
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
