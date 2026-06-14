# PixelLens

## 日本語

`PixelLens` は macOS 向けの `JPEG 内部構造ビューア` です。  
一般的な画像編集ソフトではなく、JPEG ファイルのセグメント構造、EXIF / TIFF / JFIF 情報、対応するバイト範囲を可視化するための軽量なインスペクタです。

Ver1 では、`DPI変更ツール` から方針を切り替え、`画像ファイルをデータレベルで観察するツール` として再設計しています。

### Ver1 の現在機能

* JPEG の読み込み
* 画像プレビュー表示
* JPEG 構造一覧の表示
  * `SOI`
  * `APP0`
  * `APP1`
  * `DQT`
  * `DHT`
  * `SOF`
  * `SOS`
  * `EOI`
* `APP0 / APP1` の内部要素表示
  * `JFIF`
  * `TIFF Header`
  * `IFD0`
  * `Exif IFD`
* `Bytes` ビューでのページ単位表示
* 構造選択時の対応バイト範囲ハイライト
* `Inspector` での詳細表示
  * `name`
  * `marker / kind`
  * `offset / length`
  * `payload range`
  * `decoded value`
  * `raw bytes / payload bytes`
* 限定的な構造化編集
  * `Edit Mode`
  * `pending changes`
  * `Save As`

### 現在の編集対象

Ver1 の保存機能は、既知のメタデータ項目に対する `固定長上書き` のみ対応しています。

対象例:

* `JFIF`
  * `DensityUnit`
  * `XDensity`
  * `YDensity`
* `TIFF / EXIF`
  * `XResolution`
  * `YResolution`
  * `ResolutionUnit`
  * 一部 ASCII tag
    * `Make`
    * `Model`
    * `Software`
    * `DateTime`
    * `DateTimeOriginal`

未対応:

* 任意バイト編集
* 可変長データの再配置
* セグメント追加 / 削除
* PNG / TIFF ファイル本体の対応

### 技術スタック

* UI: `SwiftUI`
* アプリケーション層: `Swift`
* 構造解析コア: `C++`
* 画像プレビュー補助: `ImageIO`
* プロジェクト管理: `Xcode`, `XcodeGen`

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

* Ver1 は `JPEG` のみ対応です
* 保存機能はまだ限定的で、構造を再配置する高度な編集は行いません
* 表示される `decoded value` は、現在対応している tag に限られます

---

## English

`PixelLens` is a macOS `JPEG structure viewer`.  
It is not a general-purpose image editor. It is a lightweight inspector for exploring JPEG segment structure, EXIF / TIFF / JFIF metadata, and the matching byte ranges inside the file.

In Ver1, the project has been redesigned from a `DPI editing tool` into a `data-level image file inspection tool`.

### Current Ver1 Features

* Open JPEG images
* Show image preview
* Display JPEG structure nodes
  * `SOI`
  * `APP0`
  * `APP1`
  * `DQT`
  * `DHT`
  * `SOF`
  * `SOS`
  * `EOI`
* Expand internal `APP0 / APP1` nodes
  * `JFIF`
  * `TIFF Header`
  * `IFD0`
  * `Exif IFD`
* Page-based `Bytes` viewer
* Highlight byte ranges that correspond to the selected structure node
* Detailed `Inspector` view
  * `name`
  * `marker / kind`
  * `offset / length`
  * `payload range`
  * `decoded value`
  * `raw bytes / payload bytes`
* Limited structured editing
  * `Edit Mode`
  * `pending changes`
  * `Save As`

### Current Editable Fields

Ver1 saving currently supports only `fixed-length overwrite` for known metadata fields.

Examples:

* `JFIF`
  * `DensityUnit`
  * `XDensity`
  * `YDensity`
* `TIFF / EXIF`
  * `XResolution`
  * `YResolution`
  * `ResolutionUnit`
  * Some ASCII tags
    * `Make`
    * `Model`
    * `Software`
    * `DateTime`
    * `DateTimeOriginal`

Not supported yet:

* Arbitrary byte editing
* Variable-length relocation
* Segment insertion / deletion
* Full PNG / TIFF file support

### Tech Stack

* UI: `SwiftUI`
* Application layer: `Swift`
* Structure parsing core: `C++`
* Image preview helper: `ImageIO`
* Project management: `Xcode`, `XcodeGen`

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

### Notes

* Ver1 supports `JPEG` only
* Saving is still limited and does not perform advanced structural relocation
* `decoded value` display is limited to currently supported tags
