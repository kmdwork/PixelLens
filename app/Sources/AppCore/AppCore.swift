import AppKit
import DPIEngine
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct SegmentNodeViewModel: Identifiable, Equatable {
    public struct EditMetadata: Equatable {
        public let valueType: String
        public let byteOrder: String
        public let maxEditableLength: Int
    }

    public let id: String
    public let name: String
    public let kind: String
    public let markerHex: String
    public let offset: Int
    public let length: Int
    public let payloadOffset: Int
    public let payloadLength: Int
    public let decodedValue: String
    public let editMetadata: EditMetadata?
    public let depth: Int

    public var byteRangeLabel: String {
        "\(offset) ..< \(offset + length)"
    }

    public var payloadRangeLabel: String {
        "\(payloadOffset) ..< \(payloadOffset + payloadLength)"
    }
}

public struct HexLineViewModel: Identifiable, Equatable {
    public let id: Int
    public let lineOffset: Int
    public let hexPrefix: String
    public let hexHighlight: String
    public let hexSuffix: String
    public let highlightedRange: Range<Int>?
    public let ascii: String

    public var offsetLabel: String {
        String(format: "%08X", lineOffset)
    }
}

public struct ImageStructureDocument {
    public let fileURL: URL
    public let filename: String
    public let width: Int
    public let height: Int
    public let previewImage: NSImage?
    public let fileSize: Int
    public let rawData: Data
    public let segments: [SegmentNodeViewModel]
}

public struct HexViewData {
    public let displayedByteCount: Int
    public let totalByteCount: Int
    public let totalLineCount: Int
    public let bytesPerLine: Int
    public let linesPerPage: Int
    public let bytesPerPage: Int
    public let totalPages: Int

    public var isTruncated: Bool {
        displayedByteCount < totalByteCount
    }

    public init(
        displayedByteCount: Int,
        totalByteCount: Int,
        totalLineCount: Int,
        bytesPerLine: Int,
        linesPerPage: Int
    ) {
        self.displayedByteCount = displayedByteCount
        self.totalByteCount = totalByteCount
        self.totalLineCount = totalLineCount
        self.bytesPerLine = bytesPerLine
        self.linesPerPage = linesPerPage
        self.bytesPerPage = bytesPerLine * linesPerPage
        self.totalPages = max(1, Int(ceil(Double(max(totalLineCount, 1)) / Double(linesPerPage))))
    }
}

public enum ImageDocumentError: Error, LocalizedError {
    case unsupportedFile
    case cannotOpenImage
    case cannotReadMetadata
    case cannotReadFile
    case cannotWriteFile
    case parserFailed(String)
    case invalidParserOutput
    case unsupportedEdit(String)
    case invalidEditValue(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "JPEG ファイルのみ対応しています。"
        case .cannotOpenImage:
            return "画像を開けませんでした。"
        case .cannotReadMetadata:
            return "画像メタデータを読み取れませんでした。"
        case .cannotReadFile:
            return "ファイルを読み取れませんでした。"
        case .cannotWriteFile:
            return "ファイルを書き出せませんでした。"
        case .parserFailed(let message):
            return "JPEG 構造解析に失敗しました: \(message)"
        case .invalidParserOutput:
            return "構造解析結果を読み取れませんでした。"
        case .unsupportedEdit(let message):
            return "未対応の編集です: \(message)"
        case .invalidEditValue(let message):
            return "入力値が不正です: \(message)"
        }
    }
}

private struct JPEGStructureReport: Decodable {
    let ok: Bool
    let segments: [JPEGSegment]
    let error: String?
}

private struct JPEGSegment: Decodable {
    let name: String
    let kind: String
    let markerHex: String
    let offset: Int
    let length: Int
    let payloadOffset: Int
    let payloadLength: Int
    let decodedValue: String
    let editValueType: String
    let byteOrder: String
    let maxEditableLength: Int
    let children: [JPEGSegment]
}

public enum ImageDocumentService {
    public static func loadDocument(from fileURL: URL) throws -> ImageStructureDocument {
        guard isJPEG(url: fileURL) else {
            throw ImageDocumentError.unsupportedFile
        }
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            throw ImageDocumentError.cannotOpenImage
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ImageDocumentError.cannotReadMetadata
        }
        guard let rawData = try? Data(contentsOf: fileURL) else {
            throw ImageDocumentError.cannotReadFile
        }

        return ImageStructureDocument(
            fileURL: fileURL,
            filename: fileURL.lastPathComponent,
            width: properties[kCGImagePropertyPixelWidth] as? Int ?? 0,
            height: properties[kCGImagePropertyPixelHeight] as? Int ?? 0,
            previewImage: NSImage(contentsOf: fileURL),
            fileSize: rawData.count,
            rawData: rawData,
            segments: try parseSegments(from: rawData)
        )
    }

    public static func makeHexViewData(
        data: Data,
        bytesPerLine: Int = 16,
        linesPerPage: Int = 85,
        maxDisplayedBytes: Int = .max
    ) -> HexViewData {
        let displayedByteCount = min(data.count, maxDisplayedBytes)
        let totalLineCount = Int(ceil(Double(displayedByteCount) / Double(bytesPerLine)))
        return HexViewData(
            displayedByteCount: displayedByteCount,
            totalByteCount: data.count,
            totalLineCount: totalLineCount,
            bytesPerLine: bytesPerLine,
            linesPerPage: linesPerPage
        )
    }

    public static func pageIndex(for offset: Int, hexViewData: HexViewData) -> Int {
        guard hexViewData.bytesPerPage > 0 else { return 0 }
        let normalizedOffset = max(0, min(offset, max(0, hexViewData.displayedByteCount - 1)))
        return min(hexViewData.totalPages - 1, normalizedOffset / hexViewData.bytesPerPage)
    }

    public static func makeHexLinesForPage(
        data: Data,
        highlightedRange: Range<Int>?,
        pageIndex: Int,
        hexViewData: HexViewData,
        maxDisplayedBytes: Int = .max
    ) -> [HexLineViewModel] {
        guard hexViewData.displayedByteCount > 0 else { return [] }

        let bytes = [UInt8](data.prefix(hexViewData.displayedByteCount))
        let safePageIndex = max(0, min(pageIndex, hexViewData.totalPages - 1))
        let pageStartLine = safePageIndex * hexViewData.linesPerPage
        let pageEndLine = min(hexViewData.totalLineCount, pageStartLine + hexViewData.linesPerPage)

        return (pageStartLine..<pageEndLine).map { lineIndex in
            let offset = lineIndex * hexViewData.bytesPerLine
            let end = min(offset + hexViewData.bytesPerLine, bytes.count)
            let lineBytes = Array(bytes[offset..<end])
            let absoluteLineRange = offset..<end
            let lineHighlight = highlightedRange.flatMap { range -> Range<Int>? in
                let lower = max(absoluteLineRange.lowerBound, range.lowerBound)
                let upper = min(absoluteLineRange.upperBound, range.upperBound)
                guard lower < upper else { return nil }
                return (lower - offset)..<(upper - offset)
            }

            return HexLineViewModel(
                id: offset,
                lineOffset: offset,
                hexPrefix: lineHexString(bytes: lineBytes, range: 0..<(lineHighlight?.lowerBound ?? lineBytes.count)),
                hexHighlight: lineHighlight.map { lineHexString(bytes: lineBytes, range: $0) } ?? "",
                hexSuffix: lineHighlight.map { lineHexString(bytes: lineBytes, range: $0.upperBound..<lineBytes.count) } ?? "",
                highlightedRange: lineHighlight,
                ascii: asciiString(bytes: lineBytes)
            )
        }
    }

    public static func saveEditedDocument(
        document: ImageStructureDocument,
        overrides: [String: String],
        to destinationURL: URL
    ) throws {
        var mutableData = document.rawData

        for segment in document.segments {
            guard let override = overrides[segment.id], let editMetadata = segment.editMetadata else { continue }
            try applyEdit(
                value: override,
                to: &mutableData,
                segment: segment,
                editMetadata: editMetadata
            )
        }

        do {
            try mutableData.write(to: destinationURL, options: .atomic)
        } catch {
            throw ImageDocumentError.cannotWriteFile
        }
    }
}

public func segmentDescription(for segment: SegmentNodeViewModel) -> String {
    switch segment.name {
    case "SOI":
        return "JPEG ファイルの開始マーカーです。"
    case "EOI":
        return "JPEG ファイルの終了マーカーです。"
    case "APP0":
        return "一般的には JFIF 情報が格納されるセグメントです。"
    case "APP1":
        return "一般的には EXIF 情報が格納されるセグメントです。"
    case "TIFF Header":
        return "EXIF 内の TIFF ヘッダです。エンディアンと最初の IFD 位置を決めます。"
    case "IFD0":
        return "TIFF の最初の Image File Directory です。tag entry の一覧を持ちます。"
    case "Exif IFD":
        return "EXIF 用の追加 IFD です。撮影情報や色空間、寸法関連 tag を持ちます。"
    case "XResolution", "YResolution", "ResolutionUnit":
        return "TIFF / EXIF の解像度関連 tag です。"
    case "DateTimeOriginal":
        return "撮影日時を示す EXIF tag です。"
    case "PixelXDimension", "PixelYDimension":
        return "EXIF が保持する画像寸法関連 tag です。"
    case "ColorSpace":
        return "EXIF の色空間指定です。"
    case "ExifVersion":
        return "EXIF のバージョン文字列です。"
    case "DQT":
        return "量子化テーブルを保持するセグメントです。"
    case "DHT":
        return "ハフマンテーブルを保持するセグメントです。"
    case "SOS":
        return "圧縮画像データの開始を示すセグメントです。"
    default:
        if segment.name.hasPrefix("SOF") {
            return "画像サイズやサンプリング情報を持つフレームヘッダです。"
        }
        if segment.name.hasPrefix("APP") {
            return "アプリケーション固有情報を持つセグメントです。"
        }
        return "JPEG の構造要素です。"
    }
}

public func formatByte(_ value: UInt8) -> String {
    String(format: "%02X", value)
}

public func rawByteSnippet(data: Data, range: Range<Int>, limit: Int = 32) -> String {
    guard !data.isEmpty else { return "" }
    let lower = max(0, min(range.lowerBound, data.count))
    let upper = max(lower, min(range.upperBound, data.count))
    let slice = data[lower..<min(upper, lower + limit)]
    let values = slice.map { formatByte($0) }.joined(separator: " ")
    if upper - lower > limit {
        return values + " ..."
    }
    return values
}

private func isJPEG(url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else {
        return false
    }
    return type.conforms(to: .jpeg)
}

private func parseSegments(from data: Data) throws -> [SegmentNodeViewModel] {
    let jsonString: String = try data.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
            throw ImageDocumentError.cannotReadFile
        }
        guard let cString = DPIEngineParseJPEGStructure(baseAddress, data.count) else {
            throw ImageDocumentError.invalidParserOutput
        }
        defer { DPIEngineFreeString(cString) }
        return String(cString: cString)
    }

    guard let jsonData = jsonString.data(using: .utf8) else {
        throw ImageDocumentError.invalidParserOutput
    }

    let report = try JSONDecoder().decode(JPEGStructureReport.self, from: jsonData)
    guard report.ok else {
        throw ImageDocumentError.parserFailed(report.error ?? "Unknown parser error")
    }

    var flattened: [SegmentNodeViewModel] = []
    for (index, segment) in report.segments.enumerated() {
        flatten(segment: segment, idPrefix: "\(index)", depth: 0, into: &flattened)
    }
    return flattened
}

private func lineHexString(bytes: [UInt8], range: Range<Int>) -> String {
    let lower = max(0, min(range.lowerBound, bytes.count))
    let upper = max(lower, min(range.upperBound, bytes.count))
    guard lower < upper else { return "" }
    return bytes[lower..<upper].map { formatByte($0) }.joined(separator: " ") + " "
}

private func asciiString(bytes: [UInt8]) -> String {
    bytes.map { byte in
        (32...126).contains(Int(byte)) ? String(UnicodeScalar(byte)) : "."
    }.joined()
}

private func flatten(segment: JPEGSegment, idPrefix: String, depth: Int, into result: inout [SegmentNodeViewModel]) {
    result.append(
        SegmentNodeViewModel(
            id: idPrefix,
            name: segment.name,
            kind: segment.kind,
            markerHex: segment.markerHex,
            offset: segment.offset,
            length: segment.length,
            payloadOffset: segment.payloadOffset,
            payloadLength: segment.payloadLength,
            decodedValue: segment.decodedValue,
            editMetadata: makeEditMetadata(segment: segment),
            depth: depth
        )
    )
    for (childIndex, child) in segment.children.enumerated() {
        flatten(segment: child, idPrefix: "\(idPrefix).\(childIndex)", depth: depth + 1, into: &result)
    }
}

private func makeEditMetadata(segment: JPEGSegment) -> SegmentNodeViewModel.EditMetadata? {
    guard !segment.editValueType.isEmpty else { return nil }
    return SegmentNodeViewModel.EditMetadata(
        valueType: segment.editValueType,
        byteOrder: segment.byteOrder,
        maxEditableLength: segment.maxEditableLength
    )
}

private func applyEdit(
    value: String,
    to data: inout Data,
    segment: SegmentNodeViewModel,
    editMetadata: SegmentNodeViewModel.EditMetadata
) throws {
    let payloadOffset = segment.payloadOffset
    let payloadLength = segment.payloadLength
    guard payloadOffset >= 0, payloadLength >= 0, payloadOffset + payloadLength <= data.count else {
        throw ImageDocumentError.unsupportedEdit(segment.name)
    }

    switch editMetadata.valueType {
    case "jfif-u8":
        let normalized = normalizedJFIFDensityUnit(value)
        data[payloadOffset] = normalized
    case "jfif-u16":
        let number = try parseUnsignedInt(value, max: UInt32(UInt16.max), field: segment.name)
        writeUInt16(Int(number), to: &data, at: payloadOffset, byteOrder: "be")
    case "tiff-short":
        let number = try parseUnsignedInt(value, max: UInt32(UInt16.max), field: segment.name)
        writeUInt16(Int(number), to: &data, at: payloadOffset, byteOrder: editMetadata.byteOrder)
    case "tiff-long":
        let number = try parseUnsignedInt(value, max: UInt32.max, field: segment.name)
        writeUInt32(number, to: &data, at: payloadOffset, byteOrder: editMetadata.byteOrder)
    case "tiff-rational":
        let numerator = try parseRationalNumerator(value, field: segment.name)
        writeUInt32(numerator, to: &data, at: payloadOffset, byteOrder: editMetadata.byteOrder)
        writeUInt32(1, to: &data, at: payloadOffset + 4, byteOrder: editMetadata.byteOrder)
    case "ascii":
        try writeASCII(value, to: &data, at: payloadOffset, maxLength: editMetadata.maxEditableLength)
    default:
        throw ImageDocumentError.unsupportedEdit("\(segment.name) (\(editMetadata.valueType))")
    }
}

private func parseUnsignedInt(_ value: String, max: UInt32, field: String) throws -> UInt32 {
    guard let parsed = UInt32(value.trimmingCharacters(in: .whitespacesAndNewlines)), parsed <= max else {
        throw ImageDocumentError.invalidEditValue(field)
    }
    return parsed
}

private func parseRationalNumerator(_ value: String, field: String) throws -> UInt32 {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if let fractionPart = trimmed.split(separator: " ").first {
        let pieces = fractionPart.split(separator: "/")
        if pieces.count == 2,
           let numerator = UInt32(pieces[0]),
           let denominator = UInt32(pieces[1]),
           denominator != 0 {
            return numerator / denominator == 0 ? numerator : numerator
        }
    }
    if let integerValue = UInt32(trimmed) {
        return integerValue
    }
    guard let decimal = Double(trimmed), decimal >= 0 else {
        throw ImageDocumentError.invalidEditValue(field)
    }
    return UInt32(decimal.rounded())
}

private func normalizedJFIFDensityUnit(_ value: String) -> UInt8 {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch normalized {
    case "0", "none":
        return 0
    case "1", "dpi", "inch":
        return 1
    case "2", "dpcm", "centimeter", "cm":
        return 2
    default:
        return 1
    }
}

private func writeUInt16(_ value: Int, to data: inout Data, at offset: Int, byteOrder: String) {
    let clamped = UInt16(max(0, min(value, Int(UInt16.max))))
    switch byteOrder {
    case "le":
        data[offset] = UInt8(clamped & 0x00FF)
        data[offset + 1] = UInt8((clamped & 0xFF00) >> 8)
    default:
        data[offset] = UInt8((clamped & 0xFF00) >> 8)
        data[offset + 1] = UInt8(clamped & 0x00FF)
    }
}

private func writeUInt32(_ value: UInt32, to data: inout Data, at offset: Int, byteOrder: String) {
    switch byteOrder {
    case "le":
        data[offset] = UInt8(value & 0x000000FF)
        data[offset + 1] = UInt8((value & 0x0000FF00) >> 8)
        data[offset + 2] = UInt8((value & 0x00FF0000) >> 16)
        data[offset + 3] = UInt8((value & 0xFF000000) >> 24)
    default:
        data[offset] = UInt8((value & 0xFF000000) >> 24)
        data[offset + 1] = UInt8((value & 0x00FF0000) >> 16)
        data[offset + 2] = UInt8((value & 0x0000FF00) >> 8)
        data[offset + 3] = UInt8(value & 0x000000FF)
    }
}

private func writeASCII(_ value: String, to data: inout Data, at offset: Int, maxLength: Int) throws {
    let utf8Bytes = Array(value.utf8)
    guard utf8Bytes.count < maxLength else {
        throw ImageDocumentError.invalidEditValue("ASCII value is too long")
    }
    for index in 0..<maxLength {
        data[offset + index] = 0
    }
    for (index, byte) in utf8Bytes.enumerated() {
        data[offset + index] = byte
    }
}
