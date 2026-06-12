import AppKit
import DPIEngine
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ResolutionEntry: Identifiable, Equatable {
    public let id: String
    public let label: String
    public let xDpi: Double?
    public let yDpi: Double?

    public var displayValue: String {
        guard let xDpi, let yDpi else { return "N/A" }
        let difference: Double = Swift.abs(xDpi - yDpi)
        if difference < 0.01 {
            return "\(formatDpi(xDpi)) dpi"
        }
        return "\(formatDpi(xDpi)) x \(formatDpi(yDpi)) dpi"
    }
}

public struct ImageDocument: Equatable {
    public let fileURL: URL
    public let filename: String
    public let width: Int
    public let height: Int
    public let resolutions: [ResolutionEntry]
    public let tiffDpiX: Double?
    public let tiffDpiY: Double?
    public let printWidthCm: Double
    public let printHeightCm: Double

    public var dominantDpiLabel: String {
        guard let tiffDpiX, let tiffDpiY else { return "N/A" }
        let difference: Double = Swift.abs(tiffDpiX - tiffDpiY)
        if difference < 0.01 {
            return "\(formatDpi(tiffDpiX)) dpi"
        }
        return "\(formatDpi(tiffDpiX)) x \(formatDpi(tiffDpiY)) dpi"
    }
}

public enum ImageDocumentError: Error, LocalizedError {
    case unsupportedFile
    case cannotOpenImage
    case cannotReadMetadata
    case cannotCreateDestination
    case failedToWriteImage
    case invalidDpi

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "JPEG ファイルのみ対応しています。"
        case .cannotOpenImage:
            return "画像を開けませんでした。"
        case .cannotReadMetadata:
            return "画像メタデータを読み取れませんでした。"
        case .cannotCreateDestination:
            return "保存先ファイルを作成できませんでした。"
        case .failedToWriteImage:
            return "画像の保存に失敗しました。"
        case .invalidDpi:
            return "DPI は 1 以上の数値を指定してください。"
        }
    }
}

public enum ImageDocumentService {
    public static func loadDocument(from fileURL: URL) throws -> ImageDocument {
        guard isJPEG(url: fileURL) else {
            throw ImageDocumentError.unsupportedFile
        }
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            throw ImageDocumentError.cannotOpenImage
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ImageDocumentError.cannotReadMetadata
        }

        let info = makeEngineInfo(from: properties)
        let printSize = DPIEngineComputePrintSizeCm(info)

        return ImageDocument(
            fileURL: fileURL,
            filename: fileURL.lastPathComponent,
            width: Int(info.width),
            height: Int(info.height),
            resolutions: [
                ResolutionEntry(id: "tiff", label: "TIFF", xDpi: optionalDpi(info.tiffDpiX), yDpi: optionalDpi(info.tiffDpiY)),
                ResolutionEntry(id: "exif", label: "EXIF", xDpi: optionalDpi(info.exifDpiX), yDpi: optionalDpi(info.exifDpiY)),
                ResolutionEntry(id: "jfif", label: "JFIF", xDpi: optionalDpi(info.jfifDpiX), yDpi: optionalDpi(info.jfifDpiY))
            ],
            tiffDpiX: optionalDpi(info.tiffDpiX),
            tiffDpiY: optionalDpi(info.tiffDpiY),
            printWidthCm: printSize.widthCm,
            printHeightCm: printSize.heightCm
        )
    }

    @discardableResult
    public static func saveWithUpdatedDpi(inputURL: URL, dpiX: Double, dpiY: Double) throws -> URL {
        guard dpiX > 0, dpiY > 0 else {
            throw ImageDocumentError.invalidDpi
        }
        guard isJPEG(url: inputURL) else {
            throw ImageDocumentError.unsupportedFile
        }
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ImageDocumentError.cannotOpenImage
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageDocumentError.cannotOpenImage
        }
        guard let type = CGImageSourceGetType(source) else {
            throw ImageDocumentError.cannotOpenImage
        }

        let outputURL = makeOutputURL(inputURL: inputURL, dpiX: dpiX, dpiY: dpiY)
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, type, 1, nil) else {
            throw ImageDocumentError.cannotCreateDestination
        }

        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        properties[kCGImagePropertyTIFFDictionary] = updatedTiffProperties(
            base: properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
            dpiX: dpiX,
            dpiY: dpiY
        )

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageDocumentError.failedToWriteImage
        }
        return outputURL
    }
}

private func isJPEG(url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else {
        return false
    }
    return type.conforms(to: .jpeg)
}

private func makeEngineInfo(from properties: [CFString: Any]) -> DPIEngineImageInfo {
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    let jfif = properties[kCGImagePropertyJFIFDictionary] as? [CFString: Any]

    return DPIEngineImageInfo(
        width: properties[kCGImagePropertyPixelWidth] as? Int32 ?? 0,
        height: properties[kCGImagePropertyPixelHeight] as? Int32 ?? 0,
        tiffDpiX: numberValue(tiff?[kCGImagePropertyTIFFXResolution]),
        tiffDpiY: numberValue(tiff?[kCGImagePropertyTIFFYResolution]),
        exifDpiX: numberValue(tiff?[kCGImagePropertyTIFFXResolution]),
        exifDpiY: numberValue(tiff?[kCGImagePropertyTIFFYResolution]),
        jfifDpiX: numberValue(jfif?[kCGImagePropertyJFIFXDensity]),
        jfifDpiY: numberValue(jfif?[kCGImagePropertyJFIFYDensity])
    )
}

private func updatedTiffProperties(base: [CFString: Any]?, dpiX: Double, dpiY: Double) -> [CFString: Any] {
    var result = base ?? [:]
    result[kCGImagePropertyTIFFXResolution] = dpiX
    result[kCGImagePropertyTIFFYResolution] = dpiY
    result[kCGImagePropertyTIFFResolutionUnit] = 2
    return result
}

private func makeOutputURL(inputURL: URL, dpiX: Double, dpiY: Double) -> URL {
    let baseName = inputURL.deletingPathExtension().lastPathComponent
    let ext = inputURL.pathExtension
    let difference: Double = Swift.abs(dpiX - dpiY)
    let suffix: String = difference < 0.01
        ? "\(Int(dpiX.rounded()))dpi"
        : "\(Int(dpiX.rounded()))x\(Int(dpiY.rounded()))dpi"
    return inputURL.deletingLastPathComponent().appendingPathComponent("\(baseName)_\(suffix).\(ext)")
}

private func optionalDpi(_ value: Double) -> Double? {
    value > 0 ? value : nil
}

private func numberValue(_ value: Any?) -> Double {
    switch value {
    case let number as NSNumber:
        return number.doubleValue
    case let value as Double:
        return value
    case let value as Int:
        return Double(value)
    default:
        return 0
    }
}

public func formatDpi(_ value: Double) -> String {
    let roundedDifference: Double = Swift.abs(value.rounded() - value)
    if roundedDifference < 0.01 {
        return String(Int(value.rounded()))
    }
    return String(format: "%.1f", value)
}

public func formatCentimeters(_ value: Double) -> String {
    String(format: "%.1f cm", value)
}
