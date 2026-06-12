# PixelLens Ver0

## 概要

`PixelLens` は macOS 向けの JPEG 解像度確認・変更ツールである。

一般的な画像編集ではなく、以下に特化している。

* JPEG の解像度情報確認
* TIFF / EXIF系解像度の変更
* 印刷サイズ確認

---

## 現時点の機能

### 1. JPEG 読み込み

* JPEG のみ対応
* ファイル選択ダイアログ対応
* ドラッグ＆ドロップ対応

### 2. 画像情報表示

* ファイル名
* 画像幅
* 画像高さ
* 基準DPI
* 印刷サイズ

### 3. 解像度情報の個別表示

アプリ内では解像度情報を以下の単位で分けて表示する。

* TIFF
* EXIF
* JFIF

複数の解像度情報が一致しない場合でも、そのまま個別表示する。

### 4. DPI 変更

* DPI X / DPI Y を入力可能
* 別名保存で出力
* TIFF / EXIF系解像度のみ更新
* JFIF は更新しない

### 5. 保存ポリシー

* リサンプリングなし
* ピクセル数は変更しない
* ピクセルデータは変更しない
* 画質は変更しない方針
* 出力ファイル名は `_300dpi` などの suffix を付与

### 6. UI

* SwiftUI ベース
* 入力欄は灰色背景
* 文字色は黒基調
* 情報量が増えても縦スクロール可能
* アプリアイコン設定済み

---

## 技術スタック

### アプリ層

* Swift
* SwiftUI
* AppKit

### 画像I/O / メタデータ処理

* ImageIO
* UniformTypeIdentifiers

### コア処理

* C++
* `DPIEngine`

現在の C++ は主に印刷サイズ計算を担当している。

### プロジェクト管理

* Xcode
* XcodeGen
* `project.yml` を正本として `.xcodeproj` を生成

---

## 現時点のアーキテクチャ

構成は以下である。

* UI: SwiftUI
* アプリロジック / 画像I/O: Swift
* コア計算: C++

層の流れ:

* SwiftUI
* AppModel / AppCore
* DPIEngine

---

## 実装上の重要仕様

* JPEG の DPI 表示は単一値ではなく TIFF / EXIF / JFIF を分離表示する
* 保存時に変更するのは TIFF / EXIF系解像度のみ
* JFIF は表示対象だが更新対象外
* 他アプリでは JFIF を優先して表示する可能性がある

---

## ビルド / 実行状態

現時点で以下を確認済み。

* Xcode から起動可能
* Release ビルド可能
* `.app` として出力可能
* ローカル用に `PixelLens.app` を配置して起動可能

ローカル配置先:

* `<local-app-dir>/PixelLens.app`

---

## 今後の候補

* UI の細部改善
* JPEG 以外の形式対応
* 配布手順の簡略化
* GitHub 配布向け zip 作成手順の固定
* 必要に応じた署名 / notarization 対応
