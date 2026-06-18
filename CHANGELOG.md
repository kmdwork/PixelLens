# Changelog

## 日本語

### v1.1.0

Ver1 後半の実装。

追加・改善:

* `IFD entry + pointed value` の複数ハイライトを追加
* `Inspector` に `Entry Range / Value Range / Referenced Offset` を追加
* `MPF` を含む複数画像 JPEG の検出を追加
* 副画像 JPEG の位置把握と切り出しを追加
* `Preview` パネルから副画像を書き出せるようにした
* `Bytes` ビューを複数ハイライト対応に更新
* `Not a JPEG file` のときに `これは JPEG ではありません。` と表示するように修正
* `Preview` パネルを固定高 + 内部スクロール対応に調整

制限:

* 編集保存は既知の `JFIF / TIFF / EXIF` tag に対する固定長上書きのみ
* `GPS IFD / ICC / XMP / APP2` の一般解析は未対応

### v1.0.0

Ver1 前半の実装。

追加・改善:

* アプリの方向性を `DPI変更ツール` から `JPEG 内部構造ビューア` へ変更
* JPEG の構造一覧表示を追加
* `APP0 / APP1` の子ノード表示を追加
* `IFD0` と `Exif IFD` の表示を追加
* `Bytes` ビューのページ表示を追加
* 構造選択時のハイライト表示を追加
* `Inspector` に `decoded value / raw bytes / payload bytes` を追加
* `Edit Mode`
* `pending changes`
* `Save As`
  を備えた限定的な構造化編集を追加
* `XResolution / YResolution / ResolutionUnit / DateTimeOriginal` など主要 tag の表示を追加

制限:

* 対応形式は `JPEG` のみ
* 可変長再配置や任意バイト編集は未対応

### v0.1.0

Ver0 の初期実装。

追加・改善:

* JPEG の読み込み
* 画像サイズ表示
* `TIFF / EXIF / JFIF` の解像度情報表示
* `DPI X / DPI Y` 編集
* 印刷サイズ表示
* 別名保存
* `TIFF / EXIF` 系解像度の更新
* `JFIF` は表示のみで更新しない方針
* SwiftUI ベースのシンプルな macOS アプリとして整備

---

## English

### v1.1.0

Second half of Ver1 implementation.

Added / Improved:

* Added multiple highlight support for `IFD entry + pointed value`
* Added `Entry Range / Value Range / Referenced Offset` to the `Inspector`
* Added detection for multi-picture JPEGs containing `MPF`
* Added secondary JPEG location discovery and extraction
* Added export actions for embedded secondary JPEGs from the `Preview` panel
* Updated the `Bytes` viewer to support multiple highlighted ranges
* Fixed the non-JPEG error case to show `This is not a JPEG.`
* Adjusted the `Preview` panel to use a fixed height with internal scrolling

Current limitations:

* Editing and saving still supports only fixed-length overwrite for known `JFIF / TIFF / EXIF` tags
* General parsing for `GPS IFD / ICC / XMP / APP2` is not implemented yet

### v1.0.0

First half of Ver1 implementation.

Added / Improved:

* Changed the app direction from a `DPI editing tool` to a `JPEG internal structure viewer`
* Added JPEG structure list rendering
* Added child node rendering for `APP0 / APP1`
* Added `IFD0` and `Exif IFD` rendering
* Added page-based `Bytes` viewer
* Added highlight support for selected structure nodes
* Added `decoded value / raw bytes / payload bytes` to the `Inspector`
* Added limited structured editing with
  * `Edit Mode`
  * `pending changes`
  * `Save As`
* Added display for major tags such as `XResolution / YResolution / ResolutionUnit / DateTimeOriginal`

Current limitations:

* Supported format is `JPEG` only
* Variable-length relocation and arbitrary byte editing are not supported

### v0.1.0

Initial Ver0 implementation.

Added / Improved:

* JPEG loading
* Image size display
* Resolution metadata display for `TIFF / EXIF / JFIF`
* `DPI X / DPI Y` editing
* Print size display
* Save as a new file
* `TIFF / EXIF`-side resolution updates
* `JFIF` display without updating it
* Basic SwiftUI-based macOS app setup
