import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppCore)
import AppCore
#endif

@MainActor
final class AppModel: ObservableObject {
    @Published var document: ImageStructureDocument?
    @Published var selectedSegmentID: SegmentNodeViewModel.ID?
    @Published var hexViewData = HexViewData(displayedByteCount: 0, totalByteCount: 0, totalLineCount: 0, bytesPerLine: 16, linesPerPage: 85)
    @Published var currentBytePage = 0
    @Published var isEditMode = false
    @Published var editDraftValue = ""
    @Published var pendingDecodedValueOverrides: [SegmentNodeViewModel.ID: String] = [:]
    @Published var statusMessage = "JPEG を選択してください。"
    @Published var errorMessage: String?

    var selectedSegment: SegmentNodeViewModel? {
        guard let selectedSegmentID, let document else { return nil }
        return document.segments.first(where: { $0.id == selectedSegmentID })
    }

    var selectedSegmentRange: Range<Int>? {
        guard let selectedSegment else { return nil }
        return selectedSegment.offset..<(selectedSegment.offset + selectedSegment.length)
    }

    var selectedHighlightRanges: [Range<Int>] {
        guard let document, let selectedSegment else { return [] }

        var ranges: [Range<Int>] = [
            selectedSegment.offset..<(selectedSegment.offset + selectedSegment.length)
        ]

        if selectedSegment.hasSeparatePayloadRange {
            ranges.append(selectedSegment.payloadOffset..<(selectedSegment.payloadOffset + selectedSegment.payloadLength))
        }

        if let referencedOffset = selectedSegment.referencedOffset {
            if let targetNode = document.segments.first(where: { $0.offset == referencedOffset }) {
                ranges.append(targetNode.offset..<(targetNode.offset + targetNode.length))
            } else {
                ranges.append(referencedOffset..<(referencedOffset + 2))
            }
        }

        return normalizedRanges(ranges)
    }

    var hexLines: [HexLineViewModel] {
        guard let document else { return [] }
        return ImageDocumentService.makeHexLinesForPage(
            data: document.rawData,
            highlightedRanges: selectedHighlightRanges,
            pageIndex: currentBytePage,
            hexViewData: hexViewData
        )
    }

    var currentPageLabel: String {
        "\(currentBytePage + 1) / \(hexViewData.totalPages)"
    }

    var canMoveToPreviousBytePage: Bool {
        currentBytePage > 0
    }

    var canMoveToNextBytePage: Bool {
        currentBytePage + 1 < hexViewData.totalPages
    }

    var currentPageByteRangeLabel: String {
        let start = currentBytePage * hexViewData.bytesPerPage
        let end = min(hexViewData.displayedByteCount, start + hexViewData.bytesPerPage)
        return "\(start) ..< \(end)"
    }

    var pendingChangeCount: Int {
        pendingDecodedValueOverrides.count
    }

    var mpfStatusText: String? {
        guard let document else { return nil }
        if document.hasMPFMarker {
            return "MPF marker detected / Embedded JPEGs: \(document.embeddedJPEGImages.count)"
        }
        if document.embeddedJPEGImages.count > 1 {
            return "Embedded JPEGs: \(document.embeddedJPEGImages.count)"
        }
        return nil
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            load(url: url)
        }
    }

    func handleDroppedItems(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            guard let self else { return }
            let resolvedURL: URL?
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                resolvedURL = item as? URL
            }
            guard let resolvedURL else { return }
            Task { @MainActor in
                self.load(url: resolvedURL)
            }
        }
        return true
    }

    func load(url: URL) {
        statusMessage = "読み込み中..."
        errorMessage = nil

        Task.detached(priority: .userInitiated) {
            do {
                let document = try ImageDocumentService.loadDocument(from: url)
                await MainActor.run {
                    self.document = document
                    self.selectedSegmentID = document.segments.first?.id
                    self.pendingDecodedValueOverrides = [:]
                    self.isEditMode = false
                    self.editDraftValue = ""
                    self.rebuildHexViewMetadata()
                    self.jumpToSelectedSegmentPage()
                    self.statusMessage = "読み込み: \(document.filename)"
                    self.errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusMessage = "JPEG を選択してください。"
                }
            }
        }
    }

    func selectSegment(_ segment: SegmentNodeViewModel) {
        selectedSegmentID = segment.id
        jumpToSelectedSegmentPage()
        refreshEditDraftForSelection()
    }

    func moveToPreviousBytePage() {
        guard canMoveToPreviousBytePage else { return }
        currentBytePage -= 1
    }

    func moveToNextBytePage() {
        guard canMoveToNextBytePage else { return }
        currentBytePage += 1
    }

    func displayedDecodedValue(for segment: SegmentNodeViewModel) -> String {
        pendingDecodedValueOverrides[segment.id] ?? segment.decodedValue
    }

    func isEditable(_ segment: SegmentNodeViewModel) -> Bool {
        segment.editMetadata != nil
    }

    func toggleEditMode() {
        isEditMode.toggle()
        refreshEditDraftForSelection()
    }

    func applyDraftToSelectedSegment() {
        guard let selectedSegment, isEditable(selectedSegment) else { return }
        pendingDecodedValueOverrides[selectedSegment.id] = editDraftValue
    }

    func discardAllPendingChanges() {
        pendingDecodedValueOverrides = [:]
        isEditMode = false
        refreshEditDraftForSelection()
    }

    func saveAs() {
        guard let document, pendingChangeCount > 0 else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedSaveFilename(for: document.filename)

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            try ImageDocumentService.saveEditedDocument(
                document: document,
                overrides: pendingDecodedValueOverrides,
                to: destinationURL
            )
            load(url: destinationURL)
            statusMessage = "保存: \(destinationURL.lastPathComponent)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEditDraftForSelection() {
        guard let selectedSegment else {
            editDraftValue = ""
            return
        }
        editDraftValue = displayedDecodedValue(for: selectedSegment)
    }

    func exportEmbeddedJPEG(_ image: EmbeddedJPEGImage) {
        guard let document else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedEmbeddedJPEGFilename(for: document.filename, image: image)

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }
        let range = image.startOffset..<image.endOffset

        do {
            let subdata = document.rawData.subdata(in: range)
            try subdata.write(to: destinationURL, options: .atomic)
            statusMessage = "副画像を書き出しました: \(destinationURL.lastPathComponent)"
        } catch {
            errorMessage = "副画像を書き出せませんでした。"
        }
    }

    private func rebuildHexViewMetadata() {
        guard let document else {
            hexViewData = HexViewData(displayedByteCount: 0, totalByteCount: 0, totalLineCount: 0, bytesPerLine: 16, linesPerPage: 85)
            currentBytePage = 0
            return
        }
        hexViewData = ImageDocumentService.makeHexViewData(data: document.rawData)
        currentBytePage = 0
    }

    private func jumpToSelectedSegmentPage() {
        guard let selectedSegment else { return }
        currentBytePage = ImageDocumentService.pageIndex(for: selectedSegment.offset, hexViewData: hexViewData)
    }

    private func suggestedSaveFilename(for filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        return base + "_edited.jpg"
    }

    private func suggestedEmbeddedJPEGFilename(for filename: String, image: EmbeddedJPEGImage) -> String {
        let base = (filename as NSString).deletingPathExtension
        let suffix = image.isPrimary ? "primary" : image.label.replacingOccurrences(of: " ", with: "_").lowercased()
        return "\(base)_\(suffix).jpg"
    }

    private func normalizedRanges(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges
            .filter { $0.lowerBound < $0.upperBound }
            .sorted { lhs, rhs in lhs.lowerBound < rhs.lowerBound }

        guard var current = sorted.first else { return [] }
        var result: [Range<Int>] = []

        for range in sorted.dropFirst() {
            if range.lowerBound <= current.upperBound {
                current = current.lowerBound..<max(current.upperBound, range.upperBound)
            } else {
                result.append(current)
                current = range
            }
        }

        result.append(current)
        return result
    }
}
