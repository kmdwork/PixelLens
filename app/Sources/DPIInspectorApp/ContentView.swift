import SwiftUI
import UniformTypeIdentifiers

#if canImport(AppCore)
import AppCore
#endif

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                dropZone
                if let document = model.document {
                    details(document)
                    saveControls
                } else {
                    emptyState
                }
                footer
            }
            .padding(24)
            .frame(minWidth: 760, alignment: .top)
        }
        .frame(minWidth: 760, minHeight: 640)
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
                    .foregroundStyle(Color.black)
                Text("JPEG の TIFF / EXIF 系解像度を確認し、別名保存で更新します。")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.72))
            }
            Spacer()
            Button("画像を開く") {
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
                    .foregroundStyle(Color.black)
                Text("または右上の「画像を開く」から選択")
                    .foregroundStyle(Color.black.opacity(0.72))
            }
        }
        .frame(height: 120)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            model.handleDroppedItems(providers)
        }
    }

    private func details(_ document: ImageDocument) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                sectionCard(title: "画像情報") {
                    infoRow(label: "ファイル名", value: document.filename)
                    infoRow(label: "サイズ", value: "\(document.width) x \(document.height) px")
                    infoRow(label: "基準DPI", value: document.dominantDpiLabel)
                }
                sectionCard(title: "解像度情報") {
                    ForEach(document.resolutions) { entry in
                        infoRow(label: entry.label, value: entry.displayValue)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                sectionCard(title: "印刷サイズ") {
                    infoRow(label: "幅", value: formatCentimeters(document.printWidthCm))
                    infoRow(label: "高さ", value: formatCentimeters(document.printHeightCm))
                    Text("印刷サイズは TIFF / EXIF 系解像度を基準に計算します。")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.72))
                }
                sectionCard(title: "保存ポリシー") {
                    Text("MVP では TIFF / EXIF 系解像度のみ更新します。JFIF は表示のみで変更しません。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black)
                }
            }
        }
    }

    private var saveControls: some View {
        sectionCard(title: "DPI変更") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("DPI X")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    TextField("300", text: $model.dpiInputX)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.18))
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: 120)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("DPI Y")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    TextField("300", text: $model.dpiInputY)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.18))
                        .foregroundStyle(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .frame(width: 120)
                }
                Spacer()
                Button("別名保存") {
                    model.save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyState: some View {
        sectionCard(title: "待機中") {
            Text("まだ画像は読み込まれていません。JPEG を選択すると、TIFF / EXIF / JFIF の解像度情報を並べて表示します。")
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
    }

    private var footer: some View {
        HStack {
            Text(model.statusMessage)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.72))
            Spacer()
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Color.black.opacity(0.72))
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
}
