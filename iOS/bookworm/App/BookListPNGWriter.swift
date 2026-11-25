import CoreGraphics
import Foundation
import zlib

final class BookListPNGWriter {
    private enum Failure: Error {
        case invalidImage
        case fileUnavailable
        case compressionFailed
    }

    private let width: Int
    private var remainingRows: Int
    private var file: FileHandle?
    private var stream = z_stream()
    private var isCompressing = false
    private var outputBuffer = [UInt8](repeating: 0, count: 64 * 1_024)

    init(to destination: URL, width: Int, height: Int) throws {
        guard (1...Int(Int32.max)).contains(width), (1...Int(Int32.max)).contains(height),
              width * 3 + 1 <= Int(UInt32.max) else { throw Failure.invalidImage }
        self.width = width
        remainingRows = height

        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw Failure.fileUnavailable
        }
        let file = try FileHandle(forWritingTo: destination)
        self.file = file
        let status = deflateInit_(&stream, Z_DEFAULT_COMPRESSION, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw Failure.compressionFailed }
        isCompressing = true

        try file.write(contentsOf: Data([137, 80, 78, 71, 13, 10, 26, 10]))
        var header = Data()
        header.appendBigEndian(UInt32(width))
        header.appendBigEndian(UInt32(height))
        // Eight-bit RGB with standard PNG compression and filtering, without interlacing.
        header.append(contentsOf: [8, 2, 0, 0, 0])
        try writeChunk("IHDR", data: header)
        try writeChunk("sRGB", data: Data([0]))
    }

    deinit {
        if isCompressing { deflateEnd(&stream) }
        try? file?.close()
    }

    func append(_ image: CGImage) throws {
        guard isCompressing, image.width == width, (1...Int.max).contains(image.height),
              image.height <= remainingRows,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let pixels = CGContext(data: nil, width: width, height: image.height, bitsPerComponent: 8,
                                     bytesPerRow: width * 4, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue |
                                         CGBitmapInfo.byteOrder32Big.rawValue),
              let bitmap = pixels.data?.assumingMemoryBound(to: UInt8.self) else { throw Failure.invalidImage }

        let bounds = CGRect(x: 0, y: 0, width: width, height: image.height)
        pixels.setFillColor(gray: 1, alpha: 1)
        pixels.fill(bounds)
        pixels.draw(image, in: bounds)

        var scanline = [UInt8](repeating: 0, count: width * 3 + 1)
        try scanline.withUnsafeMutableBufferPointer { row in
            row[0] = 1 // PNG Sub filter predicts each channel from the previous pixel.
            for y in 0..<image.height {
                try Task.checkCancellation()
                let source = bitmap.advanced(by: y * pixels.bytesPerRow)
                var red: UInt8 = 0
                var green: UInt8 = 0
                var blue: UInt8 = 0
                for x in 0..<width {
                    let pixel = x * 4
                    let target = x * 3 + 1
                    let nextRed = source[pixel]
                    let nextGreen = source[pixel + 1]
                    let nextBlue = source[pixel + 2]
                    row[target] = nextRed &- red
                    row[target + 1] = nextGreen &- green
                    row[target + 2] = nextBlue &- blue
                    red = nextRed
                    green = nextGreen
                    blue = nextBlue
                }
                try compress(row, flush: Z_NO_FLUSH)
            }
        }
        remainingRows -= image.height
    }

    func finish() throws {
        guard isCompressing, remainingRows == 0, let file else { throw Failure.invalidImage }
        try compress(nil, flush: Z_FINISH)
        try writeChunk("IEND", data: Data())
        deflateEnd(&stream)
        isCompressing = false
        try file.close()
        self.file = nil
    }

    private func compress(_ input: UnsafeMutableBufferPointer<UInt8>?, flush: Int32) throws {
        stream.next_in = input?.baseAddress
        stream.avail_in = UInt32(input?.count ?? 0)
        defer { stream.next_in = nil }

        while true {
            let (result, length) = outputBuffer.withUnsafeMutableBufferPointer { output in
                stream.next_out = output.baseAddress
                stream.avail_out = UInt32(output.count)
                let result = deflate(&stream, flush)
                return (result, output.count - Int(stream.avail_out))
            }
            stream.next_out = nil
            guard result == Z_OK || result == Z_STREAM_END else { throw Failure.compressionFailed }
            if length > 0 { try writeChunk("IDAT", data: Data(outputBuffer.prefix(length))) }
            if result == Z_STREAM_END || (flush == Z_NO_FLUSH && stream.avail_in == 0) { return }
        }
    }

    private func writeChunk(_ type: String, data: Data) throws {
        guard let file else { throw Failure.fileUnavailable }
        var chunk = Data()
        chunk.reserveCapacity(data.count + 12)
        chunk.appendBigEndian(UInt32(data.count))
        chunk.append(contentsOf: type.utf8)
        chunk.append(data)
        let checksum = chunk.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            crc32(0, bytes.bindMemory(to: UInt8.self).baseAddress?.advanced(by: 4), UInt32(bytes.count - 4))
        }
        chunk.appendBigEndian(UInt32(checksum))
        try file.write(contentsOf: chunk)
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        var bytes = value.bigEndian
        Swift.withUnsafeBytes(of: &bytes) { append(contentsOf: $0) }
    }
}
