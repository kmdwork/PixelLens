# PixelLens - Ver1要件定義

## 概要

`PixelLens` は macOS 向けの画像ファイル内部構造ビューアを開発するためのプロジェクトである。

Ver0 では `DPI確認 / DPI変更 / 印刷サイズ確認` に特化したツールだったが、
Ver1 では方針を変更し、画像ファイルをデータレベルで観察し、
内部構造を理解できるツールへ発展させる。

目的は一般的な画像編集ソフトの代替ではなく、
以下に特化した軽量なインスペクタを作ること。

* 画像ファイル構造の可視化
* バイナリと意味情報の対応表示
* 構造要素とバイト範囲の相互参照
* 将来的な安全な部分編集の土台作り

将来的な Windows 版展開を見据え、構造解析コアは可能な限り `C++` に集約する。

---

# 技術方針

## 構成

UI層

* `SwiftUI`

アプリケーション層

* `Swift`

コア処理

* `C++`

画像プレビュー補助

* `ImageIO`

ファイル読込

* `Data`
* `FileHandle`
* 必要に応じて `mmap`

---

## レイヤー構成

UI (`SwiftUI`)

↓

Swift Bridge

↓

Structure Parser / Model (`C++`)

↓

Raw File Bytes

---

## クロスプラットフォーム戦略

UI は各 OS ごとに実装する。

ファイル構造解析、ノードモデル、offset 計算、将来の serializer は
可能な限り `C++` に集約する。

将来的に

* `macOS`
* `Windows`

へ展開可能な構造とする。

---

# Ver1の方向性

Ver1 は `DPI変更ツールの機能追加` ではなく、
実質的に以下への再設計とする。

* 画像ファイル内部構造ビューア
* 画像メタデータインスペクタ
* 将来的に軽いバイナリエディタ的要素を持つアプリ

そのため Ver1 の MVP では、まず `read-only` で成立させる。

---

# MVP機能

## 1. ファイル読み込み

MVP対応形式

* `JPEG`

読み込み方法

* ドラッグ＆ドロップ
* ファイル選択ダイアログ

MVPでは単一ファイルのみ対応する。

---

## 2. 画像プレビュー表示

表示項目

* ファイル名
* 画像幅(px)
* 画像高さ(px)
* 画像プレビュー

注記

* 画像プレビューは構造確認の補助用途である
* 画像自体の編集機能は持たない

---

## 3. ファイル構造ツリー表示

MVPでは JPEG の主要構造要素をツリーまたはリストで表示する。

対象例

* `SOI`
* `APP0`
* `APP1`
* `DQT`
* `DHT`
* `SOF`
* `SOS`
* `EOI`

表示項目

* name
* marker
* offset
* length

PoC Ver1 で確認できた `JPEG read-only parser` を基礎実装とする。

---

## 4. バイナリ表示

MVPでは対象ファイルのバイト列を表示できるようにする。

表示内容

* 16進表示
* ASCII 表示
* オフセット表示

MVPでは編集機能は持たず、閲覧専用とする。

---

## 5. 構造選択時のハイライト

ユーザーが構造ツリー上の要素を選択したとき、
対応するバイト範囲をバイナリ表示上でハイライトする。

例

* `APP0` を選択
* `offset 2` から `length 18` の範囲がハイライトされる

この機能のために、各ノードは以下を保持する。

* `offset`
* `length`
* `payloadOffset`
* `payloadLength`

---

## 6. インスペクタ表示

選択中ノードについて、以下を表示する。

* ノード名
* marker / kind
* offset
* length
* payload range
* decoded value
* 補足説明

MVPでは decoded value は取得できる範囲でよく、
まずは marker / length 中心でもよい。

---

## 7. 解析結果の内部モデル化

UI 表示の前提として、各構造要素をノードモデルとして扱う。

想定構造

* FileNode
* SegmentNode
* ChunkNode
* TagNode

MVPの JPEG では少なくとも以下を持つ。

* name
* kind
* offset
* length
* payloadOffset
* payloadLength
* children

---

# MVP対象外

以下は将来機能とする。

* PNG 対応
* TIFF 対応
* バイト範囲からノードへの逆引き
* 特定タグの編集
* メタデータ書き換え
* ファイル再保存
* 変更前後 diff 表示
* AIアップスケール
* ICCプロファイル編集
* CMYK変換
* PDF解析
* 一括変換
* フォルダ監視

---

# 重要方針

## 1. Ver1のMVPは read-only

Ver1 の初期段階では編集保存を行わない。

理由

* まず構造解析と可視化を成立させることが優先
* バイナリ編集は破損リスクが高い
* parser と serializer は分けて設計する必要がある

## 2. ImageIO は補助用途

`ImageIO` は以下に限定して使う。

* 画像プレビュー
* 補助的な画像情報取得

内部構造解析の中心は `C++ parser` とする。

## 3. まずは JPEG

最初から複数形式に広げず、
まずは JPEG で構造可視化の UX とアーキテクチャを固める。

---

# Core Engine API案

## SegmentNode

```cpp
struct SegmentNode
{
    std::string name;
    std::string kind;
    uint64_t offset;
    uint64_t length;
    uint64_t payloadOffset;
    uint64_t payloadLength;
    std::vector<SegmentNode> children;
};
```

---

## Parse Result

```cpp
struct ParseResult
{
    bool ok;
    std::string errorMessage;
    uint64_t fileLength;
    std::vector<SegmentNode> nodes;
};
```

---

## 読み込み

```cpp
ParseResult parseJPEG(
    const uint8_t* bytes,
    size_t length
);
```

MVPでは `read-only parser` とする。

---

## 将来の拡張

```cpp
ParseResult parsePNG(
    const uint8_t* bytes,
    size_t length
);

ParseResult parseTIFF(
    const uint8_t* bytes,
    size_t length
);
```

---

# UI構成案

画面の基本構成は以下とする。

* 左: 構造ツリー
* 中央: 画像プレビュー
* 右: hex / byte viewer
* 右下または下部: inspector

MVP ではこの構成を簡略化してもよいが、
少なくとも

* 構造一覧
* 画像プレビュー
* バイト表示
* 選択ノードの詳細

の 4 要素は持つ。

---

# 非機能要件

対応OS

* `macOS 13以降`

CPU

* `Apple Silicon優先`

メモリ使用量

* `300MB以下` を目標

パフォーマンス方針

* 少なくとも一般的な JPEG 1枚でストレスなく表示できること
* 大きいファイルに備え、将来的に遅延表示や部分読込を検討する

---

# PoC結果の反映

PoC Ver1 により、少なくとも以下は成立することを確認済み。

* `Data` + `C++ parser` で JPEG を解析できる
* `SOI / APP0 / APP1 / DHT / DQT / SOS / EOI` を列挙できる
* `offset / length / payload range` を取得できる
* `SOS` 以降の圧縮データを含む JPEG でも `EOI` まで追跡できる

したがって Ver1 の MVP は、`JPEG read-only 構造可視化ツール` として成立可能である。
