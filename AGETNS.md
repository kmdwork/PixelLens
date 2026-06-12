# DPI Inspector - MVP要件定義 v0.1

## 概要

macOS向けの画像メタデータ編集ツールを開発する。

一般的な画像編集ソフト（Photoshop、Preview等）の代替ではなく、

* DPI確認
* DPI変更
* 印刷サイズ確認

に特化した軽量ユーティリティを目指す。

将来的なWindows版展開を想定し、業務ロジックはC++で実装する。

---

# 技術方針

## 構成

UI層

* SwiftUI

アプリケーション層

* Swift

コア処理

* C++

画像I/O

* Swift

---

## レイヤー構成

UI (SwiftUI)

↓

Swift Bridge

↓

Core Engine (C++)

---

## クロスプラットフォーム戦略

画像I/Oは各OSネイティブ実装を利用し、業務ロジックは可能な限りC++へ集約する。

将来的に

* macOS
* Windows

へ展開可能な構造とする。

UIは各OSごとに実装する。

---

# MVP機能

## 1. 画像読み込み

MVP対応形式

* JPEG

ドラッグ＆ドロップ対応

または

ファイル選択ダイアログ対応

---

## 2. 画像情報表示

表示項目

* ファイル名
* 画像幅(px)
* 画像高さ(px)
* 解像度情報
* DPI(X)
* DPI(Y)

解像度情報はメタデータの種類ごとに分けて表示する

表示例

* TIFF : 300dpi
* EXIF : 300dpi
* JFIF : 72dpi

注記

* UI上の EXIF 表示は、JPEG の EXIF APP1 セグメント内に格納される TIFF 解像度タグを指す
* 複数の解像度情報が一致しない場合でも、それぞれの値をそのまま表示する

---

## 3. 印刷サイズ表示

計算式

width_inch = width_px / dpiX

height_inch = height_px / dpiY

インチをcmへ変換

表示例

* 3337 × 2421 px
* 300 dpi × 300 dpi

↓

* 28.3 cm × 20.5 cm

---

## 4. DPI変更

ユーザーが新しいDPIを入力

例

96

↓

300

保存時に解像度メタデータのみ更新する

JPEG保存時は以下の解像度情報を更新対象とする

* TIFF
* EXIF

JPEG保存時は JFIF を変更対象外とする

---

## 重要

MVPではリサンプリングを行わない

変更対象

* TIFF / EXIF系の解像度メタデータ

変更しないもの

* ピクセル数
* ピクセルデータ
* 画像品質
* JFIF解像度情報

---

## 5. 保存

別名保存方式 (sample.png -> sample_300dpi.png のように拡張子は元形式維持する)

入力

sample.jpg

出力

sample_300dpi.jpg

---

# MVP対象外

以下は将来機能とする

* AIアップスケール
* リサンプリング
* ICCプロファイル編集
* CMYK変換
* PDF解析
* 一括変換
* EXIF削除
* フォルダ監視

注記

* MVPでは JPEG の解像度の正とする情報を TIFF / EXIF系解像度とする
* JFIF は表示対象ではあるが更新対象外とする
* 一部アプリでは JFIF を優先して表示する可能性があるため、他アプリ上の表示結果が本アプリと一致しない場合がある

---

# Core Engine API案

## ImageInfo

struct ImageInfo
{
int width;
int height;
double tiffDpiX;
double tiffDpiY;
double exifDpiX;
double exifDpiY;
double jfifDpiX;
double jfifDpiY;
};

---

## 読み込み

ImageInfo getImageInfo(
const std::string& path
);

---

## DPI変更

bool changeDpi(
const std::string& inputPath,
const std::string& outputPath,
double dpiX,
double dpiY
);

changeDpi は TIFF / EXIF系解像度のみ更新し、JFIF は更新しない

---

# 非機能要件

対応OS

* macOS 13以降

CPU

* Apple Silicon優先

メモリ使用量

* 200MB以下を目標

起動時間

* 2秒以内

---

# 将来ロードマップ

v0.2

* EXIF確認
* EXIF削除

v0.3

* ICCプロファイル確認
* 印刷適性診断

v0.4

* 一括変換

v0.5

* PDF内画像DPI解析

v1.0

* Windows版
* 共通C++ライブラリ化
* インストーラ配布
