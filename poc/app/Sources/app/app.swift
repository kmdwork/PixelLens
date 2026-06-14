import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

@_silgen_name("ParseJPEGStructure")
private func ParseJPEGStructure(_ bytes: UnsafePointer<UInt8>?, _ length: Int) -> UnsafePointer<CChar>?

@_silgen_name("FreeJPEGStructureString")
private func FreeJPEGStructureString(_ value: UnsafePointer<CChar>?)

struct ImageInspection: Codable {
    let width: Int
    let height: Int
    let jfifXDensity: Double?
    let jfifYDensity: Double?
    let jfifDensityUnit: Int?
    let tiffXResolution: Double?
    let tiffYResolution: Double?
    let tiffResolutionUnit: Int?
    let exifDateTimeOriginal: String?
}

struct JPEGStructureReport: Codable {
    let ok: Bool
    let fileLength: Int?
    let segmentCount: Int?
    let segments: [JPEGSegment]?
    let error: String?
}

struct JPEGSegment: Codable {
    let name: String
    let markerHex: String
    let offset: Int
    let length: Int
    let payloadOffset: Int
    let payloadLength: Int
}

enum PocError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case cannotOpenImage(URL)
    case cannotCreateDestination(URL)
    case cannotReadProperties(URL)
    case cannotCreateImage(URL)
    case writeFailed(String)
    case cannotReadFile(URL)
    case parserFailed(String)
    case invalidParserOutput

    var description: String {
        switch self {
        case .invalidArguments(let message):
            return message
        case .cannotOpenImage(let url):
            return "Failed to open image: \(url.path)"
        case .cannotCreateDestination(let url):
            return "Failed to create image destination: \(url.path)"
        case .cannotReadProperties(let url):
            return "Failed to read image properties: \(url.path)"
        case .cannotCreateImage(let url):
            return "Failed to create image data for: \(url.path)"
        case .writeFailed(let message):
            return "Write failed: \(message)"
        case .cannotReadFile(let url):
            return "Failed to read file: \(url.path)"
        case .parserFailed(let message):
            return "Parser failed: \(message)"
        case .invalidParserOutput:
            return "Parser returned invalid JSON"
        }
    }
}

private enum TIFFResolutionUnit: Int {
    case none = 1
    case inch = 2
    case centimeter = 3
}

private enum JFIFDensityUnit: Int {
    case none = 0
    case inch = 1
    case centimeter = 2
}

private enum PocCommand {
    case inspect(URL)
    case setDpi(input: URL, output: URL, dpiX: Double, dpiY: Double)
    case makeSample(URL)
    case inspectJPEGStructure(URL)
}

@main
struct App {
    static func main() {
        do {
            let command = try parseCommand(arguments: CommandLine.arguments)
            switch command {
            case .inspect(let url):
                let inspection = try inspectJPEG(at: url)
                try printJSON(inspection)
            case .setDpi(let input, let output, let dpiX, let dpiY):
                try updateJPEGResolution(inputURL: input, outputURL: output, dpiX: dpiX, dpiY: dpiY)
                let inspection = try inspectJPEG(at: output)
                try printJSON(inspection)
            case .makeSample(let output):
                try createSampleJPEG(at: output)
                let inspection = try inspectJPEG(at: output)
                try printJSON(inspection)
            case .inspectJPEGStructure(let url):
                let report = try inspectJPEGStructure(at: url)
                try printJSON(report)
            }
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }
}

private func parseCommand(arguments: [String]) throws -> PocCommand {
    guard arguments.count >= 2 else {
        throw PocError.invalidArguments(usageText)
    }

    switch arguments[1] {
    case "inspect":
        guard arguments.count == 3 else {
            throw PocError.invalidArguments("Usage: app inspect <input.jpg>")
        }
        return .inspect(URL(fileURLWithPath: arguments[2]))
    case "set-dpi":
        guard arguments.count == 5 || arguments.count == 6 else {
            throw PocError.invalidArguments("Usage: app set-dpi <input.jpg> <output.jpg> <dpi> [dpiY]")
        }

        guard let dpiX = Double(arguments[4]) else {
            throw PocError.invalidArguments("Invalid dpi value: \(arguments[4])")
        }
        let dpiY = arguments.count == 6 ? Double(arguments[5]) : dpiX
        guard let resolvedDpiY = dpiY else {
            throw PocError.invalidArguments("Invalid dpiY value: \(arguments[5])")
        }
        return .setDpi(
            input: URL(fileURLWithPath: arguments[2]),
            output: URL(fileURLWithPath: arguments[3]),
            dpiX: dpiX,
            dpiY: resolvedDpiY
        )
    case "make-sample":
        guard arguments.count == 3 else {
            throw PocError.invalidArguments("Usage: app make-sample <output.jpg>")
        }
        return .makeSample(URL(fileURLWithPath: arguments[2]))
    case "inspect-jpeg-structure":
        guard arguments.count == 3 else {
            throw PocError.invalidArguments("Usage: app inspect-jpeg-structure <input.jpg>")
        }
        return .inspectJPEGStructure(URL(fileURLWithPath: arguments[2]))
    default:
        throw PocError.invalidArguments(usageText)
    }
}

func inspectJPEG(at url: URL) throws -> ImageInspection {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw PocError.cannotOpenImage(url)
    }
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
        throw PocError.cannotReadProperties(url)
    }
    return inspection(from: properties)
}

func inspectJPEGStructure(at url: URL) throws -> JPEGStructureReport {
    guard let data = try? Data(contentsOf: url) else {
        throw PocError.cannotReadFile(url)
    }
    let jsonString: String = try data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
            throw PocError.cannotReadFile(url)
        }
        guard let cString = ParseJPEGStructure(baseAddress, data.count) else {
            throw PocError.invalidParserOutput
        }
        defer { FreeJPEGStructureString(cString) }
        return String(cString: cString)
    }

    guard let jsonData = jsonString.data(using: .utf8) else {
        throw PocError.invalidParserOutput
    }
    let report = try JSONDecoder().decode(JPEGStructureReport.self, from: jsonData)
    if report.ok == false {
        throw PocError.parserFailed(report.error ?? "Unknown parser error")
    }
    return report
}

func updateJPEGResolution(inputURL: URL, outputURL: URL, dpiX: Double, dpiY: Double) throws {
    guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
        throw PocError.cannotOpenImage(inputURL)
    }
    guard let type = CGImageSourceGetType(source) else {
        throw PocError.cannotOpenImage(inputURL)
    }
    guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, type, 1, nil) else {
        throw PocError.cannotCreateDestination(outputURL)
    }
    guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        throw PocError.cannotCreateImage(inputURL)
    }

    let jfif: [CFString: Any] = [
        kCGImagePropertyJFIFXDensity: dpiX,
        kCGImagePropertyJFIFYDensity: dpiY,
        kCGImagePropertyJFIFDensityUnit: JFIFDensityUnit.inch.rawValue
    ]
    let tiff: [CFString: Any] = [
        kCGImagePropertyTIFFXResolution: dpiX,
        kCGImagePropertyTIFFYResolution: dpiY,
        kCGImagePropertyTIFFResolutionUnit: TIFFResolutionUnit.inch.rawValue
    ]
    var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
    properties[kCGImagePropertyJFIFDictionary] = jfif
    properties[kCGImagePropertyTIFFDictionary] = tiff

    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw PocError.writeFailed("Failed to finalize updated JPEG")
    }
}

func createSampleJPEG(at url: URL) throws {
    let width = 32
    let height = 24
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw PocError.cannotCreateImage(url)
    }

    context.setFillColor(NSColor.systemRed.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height))

    guard let image = context.makeImage() else {
        throw PocError.cannotCreateImage(url)
    }
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
        throw PocError.cannotCreateDestination(url)
    }

    let jfif: [CFString: Any] = [
        kCGImagePropertyJFIFXDensity: 72,
        kCGImagePropertyJFIFYDensity: 72,
        kCGImagePropertyJFIFDensityUnit: JFIFDensityUnit.inch.rawValue
    ]
    let tiff: [CFString: Any] = [
        kCGImagePropertyTIFFXResolution: 72,
        kCGImagePropertyTIFFYResolution: 72,
        kCGImagePropertyTIFFResolutionUnit: TIFFResolutionUnit.inch.rawValue
    ]
    let exif: [CFString: Any] = [
        kCGImagePropertyExifDateTimeOriginal: "2024:01:02 03:04:05",
        kCGImagePropertyExifUserComment: "dpi inspector poc"
    ]
    let properties: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.95,
        kCGImagePropertyJFIFDictionary: jfif,
        kCGImagePropertyTIFFDictionary: tiff,
        kCGImagePropertyExifDictionary: exif
    ]

    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
        throw PocError.writeFailed("Failed to finalize sample JPEG")
    }
}

func inspection(from properties: [CFString: Any]) -> ImageInspection {
    let jfif = properties[kCGImagePropertyJFIFDictionary] as? [CFString: Any]
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]

    return ImageInspection(
        width: properties[kCGImagePropertyPixelWidth] as? Int ?? 0,
        height: properties[kCGImagePropertyPixelHeight] as? Int ?? 0,
        jfifXDensity: numberValue(jfif?[kCGImagePropertyJFIFXDensity]),
        jfifYDensity: numberValue(jfif?[kCGImagePropertyJFIFYDensity]),
        jfifDensityUnit: intValue(jfif?[kCGImagePropertyJFIFDensityUnit]),
        tiffXResolution: numberValue(tiff?[kCGImagePropertyTIFFXResolution]),
        tiffYResolution: numberValue(tiff?[kCGImagePropertyTIFFYResolution]),
        tiffResolutionUnit: intValue(tiff?[kCGImagePropertyTIFFResolutionUnit]),
        exifDateTimeOriginal: exif?[kCGImagePropertyExifDateTimeOriginal] as? String
    )
}

func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    if let string = String(data: data, encoding: .utf8) {
        print(string)
    }
}

func numberValue(_ value: Any?) -> Double? {
    switch value {
    case let number as NSNumber:
        return number.doubleValue
    case let value as Double:
        return value
    case let value as Int:
        return Double(value)
    default:
        return nil
    }
}

func intValue(_ value: Any?) -> Int? {
    switch value {
    case let number as NSNumber:
        return number.intValue
    case let value as Int:
        return value
    case let value as Double:
        return Int(value)
    default:
        return nil
    }
}

private let usageText = """
Usage:
  app inspect <input.jpg>
  app set-dpi <input.jpg> <output.jpg> <dpi> [dpiY]
  app make-sample <output.jpg>
  app inspect-jpeg-structure <input.jpg>
"""
