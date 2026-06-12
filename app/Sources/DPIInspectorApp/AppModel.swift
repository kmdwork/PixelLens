import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppCore)
import AppCore
#endif

@MainActor
final class AppModel: ObservableObject {
    @Published var document: ImageDocument?
    @Published var dpiInputX = "300"
    @Published var dpiInputY = "300"
    @Published var statusMessage = "JPEG を選択してください。"
    @Published var errorMessage: String?

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
            var resolvedURL: URL?
            if let data = item as? Data {
                resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                resolvedURL = url
            }
            guard let resolvedURL else { return }
            Task { @MainActor in
                self.load(url: resolvedURL)
            }
        }
        return true
    }

    func load(url: URL) {
        do {
            let document = try ImageDocumentService.loadDocument(from: url)
            self.document = document
            syncDpiInputs(from: document)
            statusMessage = "読み込み: \(document.filename)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() {
        guard let document else { return }
        guard let dpiX = Double(dpiInputX), let dpiY = Double(dpiInputY) else {
            errorMessage = "DPI は数値で入力してください。"
            return
        }

        do {
            let outputURL = try ImageDocumentService.saveWithUpdatedDpi(inputURL: document.fileURL, dpiX: dpiX, dpiY: dpiY)
            let updated = try ImageDocumentService.loadDocument(from: outputURL)
            self.document = updated
            statusMessage = "保存完了: \(outputURL.lastPathComponent)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncDpiInputs(from document: ImageDocument) {
        dpiInputX = formatDpi(document.tiffDpiX ?? 300)
        dpiInputY = formatDpi(document.tiffDpiY ?? 300)
    }
}
