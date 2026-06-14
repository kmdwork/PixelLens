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

    var hexLines: [HexLineViewModel] {
        guard let document else { return [] }
        return ImageDocumentService.makeHexLinesForPage(
            data: document.rawData,
            highlightedRange: selectedSegmentRange,
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
}
