import Foundation
import CoreLocation
import ImageIO
import Photos
import PhotosUI
import SwiftUI
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
    var placeLookupVersion: Int? = nil
    var assetIdentifier: String? = nil
    var placeCity: String? = nil
    var placeDistrict: String? = nil
    var placeVenue: String? = nil

    func displayPlace(mode: PlaceDisplayMode) -> String? {
        guard mode != .hidden else { return nil }
        let city = placeCity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = (mode == .cityVenue ? placeVenue ?? placeDistrict : placeDistrict)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [city, detail].compactMap { $0 }.filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.count == 2 && parts[0] == parts[1] ? parts[0] : parts.joined(separator: " · ")
        }
        return mode == .cityVenue ? placeName : nil
    }
}

enum PlaceDisplayMode: String {
    case cityVenue
    case cityDistrict
    case hidden
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

    func image(for point: PhotoPoint, targetSize: CGSize) async -> UIImage? {
        guard let assetIdentifier = point.assetIdentifier else {
            return UIImage(contentsOfFile: thumbnailURL(for: point).path)
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = assets.firstObject else { return nil }
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize,
                contentMode: .aspectFit, options: options) { image, info in
                guard info?[PHImageResultIsDegradedKey] as? Bool != true else { return }
                continuation.resume(returning: image)
            }
        }
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

            if point.assetIdentifier == nil,
               point.latitude == nil || point.longitude == nil,
               let coordinate = PhotoMetadata.readGPS(from: originalsURL.appendingPathComponent(point.originalName)) {
                try? updateLocation(tripID: tripID, pointID: pointID, coordinate: coordinate)
            }

            if let current = trip(id: tripID)?.points.first(where: { $0.id == pointID }),
               current.placeLookupVersion != 2,
               let latitude = current.latitude, let longitude = current.longitude {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                if CLLocationCoordinate2DIsValid(coordinate) {
                    let location = CLLocation(latitude: latitude, longitude: longitude)
                    if let placemark = try? await geocoder.reverseGeocodeLocation(
                        location, preferredLocale: Locale(identifier: "zh_CN")).first {
                        try? updatePlace(tripID: tripID, pointID: pointID, placemark: placemark)
                    }
                }
            }
            if queued.isEmpty, needsLocationRefresh.remove(tripID) != nil {
                queued = trip(id: tripID)?.points.map(\.id) ?? []
            }
        }
    }

    private func updateLocation(tripID: UUID, pointID: UUID,
                                coordinate: CLLocationCoordinate2D) throws {
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }),
              let pointIndex = updated[tripIndex].points.firstIndex(where: { $0.id == pointID })
        else { throw TripStoreError.missingTrip }
        updated[tripIndex].points[pointIndex].latitude = coordinate.latitude
        updated[tripIndex].points[pointIndex].longitude = coordinate.longitude
        try persist(updated)
    }

    private func updatePlace(tripID: UUID, pointID: UUID, placemark: CLPlacemark) throws {
        guard let resolvedName = Self.placeName(from: placemark) else { return }
        var updated = trips
        guard let tripIndex = updated.firstIndex(where: { $0.id == tripID }),
              let pointIndex = updated[tripIndex].points.firstIndex(where: { $0.id == pointID })
        else { throw TripStoreError.missingTrip }
        let oldName = updated[tripIndex].points[pointIndex].placeName
        let previousAutomaticName = Self.districtName(from: placemark)
        if oldName == nil || oldName == previousAutomaticName {
            updated[tripIndex].points[pointIndex].placeName = resolvedName
        }
        updated[tripIndex].points[pointIndex].placeCity = placemark.locality
            ?? placemark.subAdministrativeArea ?? placemark.administrativeArea
        updated[tripIndex].points[pointIndex].placeDistrict = placemark.subLocality
        updated[tripIndex].points[pointIndex].placeVenue = oldName != nil
            && oldName != previousAutomaticName && oldName != resolvedName
            ? oldName : placemark.areasOfInterest?.first(where: {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
        updated[tripIndex].points[pointIndex].placeLookupVersion = 2
        try persist(updated)
    }

    private static func placeName(from placemark: CLPlacemark) -> String? {
        if let interest = placemark.areasOfInterest?.first(where: {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            return interest
        }
        return districtName(from: placemark)
    }

    private static func districtName(from placemark: CLPlacemark) -> String? {
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
        let copiedFiles: [(URL, URL)] = point.assetIdentifier == nil
            ? [(originalURL, backupOriginalsURL), (thumbnailURL, backupThumbnailsURL)] : []
        for (source, directory) in copiedFiles {
            let destination = directory.appendingPathComponent(source.lastPathComponent)
            if FileManager.default.fileExists(atPath: source.path),
               !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: source, to: destination)
            }
        }

        updated[tripIndex].points.remove(at: pointIndex)
        try persist(updated)
        // The backup keeps both images recoverable even if cleanup succeeds.
        for (source, _) in copiedFiles { try? FileManager.default.removeItem(at: source) }
    }

    func deleteLegacyPhotos(in tripID: UUID) throws -> Int {
        guard let trip = trip(id: tripID) else { throw TripStoreError.missingTrip }
        let pointIDs = trip.points.filter { $0.assetIdentifier == nil }.map(\.id)
        for pointID in pointIDs { try deletePoint(tripID: tripID, pointID: pointID) }
        for pointID in pointIDs {
            let backupURL = rootURL.appendingPathComponent("Backups/DeletedPoints/\(pointID.uuidString)")
            try? FileManager.default.removeItem(at: backupURL.appendingPathComponent("Originals"))
            try? FileManager.default.removeItem(at: backupURL.appendingPathComponent("Thumbnails"))
        }
        return pointIDs.count
    }

    func importPhotos(_ items: [PhotosPickerItem], into tripID: UUID) async -> ImportResult {
        var result = ImportResult()
        for item in items {
            do {
                guard let identifier = item.itemIdentifier,
                      let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
                    throw TripStoreError.noImage
                }
                if try importPhoto(asset, into: tripID) { result.missingTimes += 1 }
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
                if try importPhoto(asset, into: tripID) { result.missingTimes += 1 }
                result.imported += 1
            } catch {
                result.failed += 1
            }
        }
        return result
    }

    private func importPhoto(_ asset: PHAsset, into tripID: UUID) throws -> Bool {
        guard asset.mediaType == .image else { throw TripStoreError.noImage }
        var updated = trips
        guard let index = updated.firstIndex(where: { $0.id == tripID }) else {
            throw TripStoreError.missingTrip
        }
        var point = PhotoPoint(id: UUID(), originalName: "", thumbnailName: "",
                               capturedAt: asset.creationDate, note: "", addedAt: Date())
        point.assetIdentifier = asset.localIdentifier
        point.latitude = asset.location?.coordinate.latitude
        point.longitude = asset.location?.coordinate.longitude
        updated[index].points.append(point)
        try persist(updated)
        return point.capturedAt == nil
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

}
