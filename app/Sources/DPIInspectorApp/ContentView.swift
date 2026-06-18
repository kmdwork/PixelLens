import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppCore)
import AppCore
#endif

struct ContentView: View {
    @ObservedObject var model: AppModel
    private let topPanelHeight: CGFloat = 420

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                dropZone
                if let document = model.document {
                    workspace(document)
                } else {
                    emptyState
                }
                footer
            }
            .padding(24)
            .frame(minWidth: 980, alignment: .top)
        }
        .frame(minWidth: 980, minHeight: 720)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.88),
                    Color(red: 0.87, green: 0.91, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(Color.black)
        .alert("エラー", isPresented: Binding(get: {
            model.errorMessage != nil
        }, set: { newValue in
            if !newValue {
                model.errorMessage = nil
            }
        })) {
            Button("閉じる", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PixelLens")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("JPEG の内部構造を読み取り、構造一覧とバイト列を対応表示します。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
            Spacer()
            Button("JPEG を開く") {
                model.openPanel()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.72))
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [10, 8]))
                .foregroundStyle(Color.primary.opacity(0.18))
            VStack(spacing: 8) {
                Text("JPEG をドラッグ＆ドロップ")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("または右上の「JPEG を開く」から選択")
                    .foregroundStyle(Color.black.opacity(0.72))
            }
        }
        .frame(height: 120)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            model.handleDroppedItems(providers)
        }
    }

    private func workspace(_ document: ImageStructureDocument) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                structurePanel(document)
                previewPanel(document)
                inspectorPanel(document)
            }
            sectionCard(title: "Bytes") {
                BytePageViewer(model: model)
            }
        }
    }

    private func structurePanel(_ document: ImageStructureDocument) -> some View {
        sectionCard(title: "Structure") {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    infoRow(label: "ファイル", value: document.filename)
                    infoRow(label: "サイズ", value: "\(document.width) x \(document.height) px")
                    infoRow(label: "バイト数", value: "\(document.fileSize)")
                    if let mpfStatusText = model.mpfStatusText {
                        infoRow(label: "MPF", value: mpfStatusText)
                    }
                    Divider()
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(document.segments) { segment in
                            Button {
                                model.selectSegment(segment)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(segment.name)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .padding(.leading, CGFloat(segment.depth) * 14)
                                        Text("\(segment.markerHex)  offset \(segment.offset)  length \(segment.length)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.black.opacity(0.72))
                                            .padding(.leading, CGFloat(segment.depth) * 14)
                                        let displayedDecodedValue = model.displayedDecodedValue(for: segment)
                                        if !displayedDecodedValue.isEmpty {
                                            Text(displayedDecodedValue)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundStyle(Color(red: 0.32, green: 0.38, blue: 0.18))
                                                .padding(.leading, CGFloat(segment.depth) * 14)
                                        }
                                        if model.pendingDecodedValueOverrides[segment.id] != nil {
                                            Text("Pending Change")
                                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                                .foregroundStyle(Color(red: 0.55, green: 0.23, blue: 0.08))
                                                .padding(.leading, CGFloat(segment.depth) * 14)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectionColor(for: segment))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, minHeight: topPanelHeight, maxHeight: topPanelHeight, alignment: .top)
    }

    private func previewPanel(_ document: ImageStructureDocument) -> some View {
        sectionCard(title: "Preview") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = document.previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
                            .background(Color.white.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.6))
                            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
                            .overlay {
                                Text("プレビューを表示できません")
                                    .foregroundStyle(Color.black.opacity(0.72))
                            }
                    }
                    Text("Ver1 MVP ではプレビューは補助表示です。構造解析の中心は左の一覧と下のバイト列です。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.72))
                    if let mpfStatusText = model.mpfStatusText {
                        Divider()
                        Text(mpfStatusText)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.38, green: 0.27, blue: 0.1))
                    }
                    if document.embeddedJPEGImages.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(document.embeddedJPEGImages.filter { !$0.isPrimary }) { embeddedImage in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(embeddedImage.label)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                        Text("\(embeddedImage.width) x \(embeddedImage.height)  /  \(embeddedImage.rangeLabel)")
                                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                                            .foregroundStyle(Color.black.opacity(0.72))
                                    }
                                    Spacer()
                                    Button("書き出し") {
                                        model.exportEmbeddedJPEG(embeddedImage)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 300)
        .frame(minHeight: topPanelHeight, maxHeight: topPanelHeight, alignment: .top)
    }

    private func inspectorPanel(_ document: ImageStructureDocument) -> some View {
        sectionCard(title: "Inspector") {
            HStack(spacing: 10) {
                if model.pendingChangeCount > 0 {
                    Text("Pending: \(model.pendingChangeCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.55, green: 0.23, blue: 0.08))
                }
                Button("Save As") {
                    model.saveAs()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.pendingChangeCount == 0)
            }
        } content: {
            ScrollView {
                if let segment = model.selectedSegment {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button(model.isEditMode ? "閲覧モード" : "Edit Mode") {
                                model.toggleEditMode()
                            }
                            .buttonStyle(.bordered)

                            Button("Discard") {
                                model.discardAllPendingChanges()
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.pendingChangeCount == 0)
                            Spacer()
                        }
                        infoRow(label: "Name", value: segment.name)
                        infoRow(label: "Marker", value: segment.markerHex)
                        infoRow(label: "Kind", value: segment.kind)
                        infoRow(label: "Offset", value: "\(segment.offset)")
                        infoRow(label: "Length", value: "\(segment.length)")
                        infoRow(label: "Entry Range", value: segment.byteRangeLabel)
                        infoRow(label: "Value Range", value: segment.payloadRangeLabel)
                        if let referencedOffset = segment.referencedOffset {
                            infoRow(label: "Referenced Offset", value: "\(referencedOffset)")
                        }
                        let displayedDecodedValue = model.displayedDecodedValue(for: segment)
                        if !displayedDecodedValue.isEmpty {
                            infoRow(label: "Decoded", value: displayedDecodedValue)
                        }
                        if model.isEditMode && model.isEditable(segment) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Edit Decoded Value")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.black.opacity(0.72))
                                TextField("新しい値", text: $model.editDraftValue, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.92, green: 0.92, blue: 0.89))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                HStack {
                                    Button("Apply") {
                                        model.applyDraftToSelectedSegment()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Text("Apply で変更候補に追加し、Save As で別名保存します。")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color.black.opacity(0.72))
                                }
                            }
                        } else if model.isEditMode {
                            Text("このノードは現在の編集対象ではありません。")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.72))
                        }
                        Divider()
                        Text(segmentDescription(for: segment))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Divider()
                        Text("Raw Bytes")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.72))
                        Text(rawByteSnippet(data: document.rawData, range: segment.offset..<(segment.offset + segment.length)))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .textSelection(.enabled)
                        if segment.payloadLength > 0 {
                            Text("Payload Bytes")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.black.opacity(0.72))
                            Text(rawByteSnippet(data: document.rawData, range: segment.payloadOffset..<(segment.payloadOffset + segment.payloadLength)))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("構造要素を選択すると詳細を表示します。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 280)
        .frame(minHeight: topPanelHeight, maxHeight: topPanelHeight, alignment: .top)
    }

    private var emptyState: some View {
        sectionCard(title: "待機中") {
            Text("まだ JPEG は読み込まれていません。読み込むと、構造一覧、プレビュー、バイト列、選択ノードの詳細を表示します。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
    }

    private var footer: some View {
        HStack {
            Text(model.statusMessage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.72))
            Spacer()
            if model.pendingChangeCount > 0 {
                Text("未保存の変更候補: \(model.pendingChangeCount)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.23, blue: 0.08))
            }
        }
    }

    private func sectionCard<Trailing: View, Content: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.black.opacity(0.72))
                Spacer()
                trailing()
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.black.opacity(0.72))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(Color.black)
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
    }

    private func selectionColor(for segment: SegmentNodeViewModel) -> Color {
        model.selectedSegmentID == segment.id
            ? Color(red: 0.82, green: 0.89, blue: 0.96)
            : Color.white.opacity(0.65)
    }
}

private struct BytePageViewer: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.hexViewData.isTruncated {
                Text("表示負荷を抑えるため、先頭 \(model.hexViewData.displayedByteCount) bytes のみ表示しています。全体: \(model.hexViewData.totalByteCount) bytes")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))
            }

            HStack {
                Button("←") {
                    model.moveToPreviousBytePage()
                }
                .disabled(!model.canMoveToPreviousBytePage)

                Text(model.currentPageLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(minWidth: 80)

                Button("→") {
                    model.moveToNextBytePage()
                }
                .disabled(!model.canMoveToNextBytePage)

                Spacer()

                Text("Page Range: \(model.currentPageByteRangeLabel)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.hexLines) { line in
                        HStack(alignment: .top, spacing: 10) {
                            Text(line.offsetLabel)
                                .foregroundStyle(Color.black.opacity(0.72))
                                .frame(width: 88, alignment: .leading)

                            HStack(spacing: 0) {
                                ForEach(line.hexTokens) { token in
                                    Text(token.text)
                                        .background(token.isHighlighted ? Color(red: 0.98, green: 0.87, blue: 0.49) : Color.clear)
                                    if token.id != line.hexTokens.last?.id {
                                        Text(" ")
                                    }
                                }
                            }
                            .frame(minWidth: 500, alignment: .leading)

                            HStack(spacing: 0) {
                                ForEach(line.asciiTokens) { token in
                                    Text(token.text)
                                        .foregroundStyle(Color.black.opacity(0.72))
                                        .background(token.isHighlighted ? Color(red: 0.98, green: 0.87, blue: 0.49) : Color.clear)
                                }
                            }
                            .frame(minWidth: 120, alignment: .leading)
                        }
                        .frame(height: 20, alignment: .topLeading)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
            }
            .frame(minHeight: 260)
            .background(Color.white.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
