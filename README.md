# PixelLens

## 日本語

`PixelLens` は macOS 向けの軽量な JPEG 解像度確認・変更ツールです。一般的な画像編集ソフトではなく、`DPI確認`、`DPI変更`、`印刷サイズ確認` に特化しています。

### 現在の機能

* JPEG の読み込み
* 画像サイズの表示
* 解像度情報の個別表示
  * `TIFF`
  * `EXIF`
  * `JFIF`
* `DPI X / DPI Y` の変更
* 別名保存
* 印刷サイズの計算表示

### 現在の仕様

* MVP では `JPEG` のみ対応
* 保存時に更新するのは `TIFF / EXIF系` 解像度
* `JFIF` は表示対象だが更新対象外
* リサンプリングは行わない
* ピクセル数・ピクセルデータ・画質は変更しない方針

### 技術スタック

* UI: `SwiftUI`
* アプリ層 / 画像I/O: `Swift`
* コア計算: `C++`
* JPEG メタデータ処理: `ImageIO`
* プロジェクト管理: `XcodeGen`, `Xcode`

### ビルド

Xcode プロジェクトを開く:

```bash
open app/PixelLens.xcodeproj
```

`project.yml` を変更した場合は再生成:

```bash
cd app
xcodegen
```

詳細は [BUILD.md](BUILD.md) を参照してください。

### 注意

一部アプリは `JFIF` 解像度を優先表示するため、他アプリ上の DPI 表示と `PixelLens` の表示が一致しない場合があります。

---

## English

`PixelLens` is a lightweight macOS utility for inspecting and changing JPEG resolution metadata. It is not a general image editor. It focuses on `DPI inspection`, `DPI editing`, and `print size preview`.

### Current Features

* Open JPEG images
* Show image dimensions
* Display resolution metadata separately
  * `TIFF`
  * `EXIF`
  * `JFIF`
* Edit `DPI X / DPI Y`
* Save as a new file
* Show calculated print size

### Current Behavior

* MVP currently supports `JPEG` only
* Saving updates `TIFF / EXIF-side` resolution metadata only
* `JFIF` is displayed but not updated
* No resampling
* Pixel count, pixel data, and intended image quality are not changed

### Tech Stack

* UI: `SwiftUI`
* App layer / image I/O: `Swift`
* Core calculation: `C++`
* JPEG metadata handling: `ImageIO`
* Project management: `XcodeGen`, `Xcode`

### Build

Open the Xcode project:

```bash
open app/PixelLens.xcodeproj
```

Regenerate the project after editing `project.yml`:

```bash
cd app
xcodegen
```

See [BUILD.md](BUILD.md) for details.

### Note

Some apps prioritize `JFIF` resolution metadata, so DPI values shown in other apps may differ from what `PixelLens` shows.
