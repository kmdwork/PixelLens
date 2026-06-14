# PoC Ver1

## 目的

`PixelLens` を `DPI変更ツール` から `画像ファイル内部構造ビューア` へ発展させる前提として、
`JPEG read-only 構造解析` が成立するかを確認する。

今回の確認対象:

* JPEG をバイト列として読めるか
* 主要セグメントを順に解析できるか
* 各セグメントの `offset / length / payload range` を取得できるか
* 将来の `構造選択 -> バイト範囲ハイライト` に使える形のデータを作れるか

---

## 実装場所

* `poc/app/Package.swift`
* `poc/app/Sources/app/app.swift`
* `poc/app/Sources/JPEGStructureParser/include/JPEGStructureParser.h`
* `poc/app/Sources/JPEGStructureParser/JPEGStructureParser.cpp`

---

## 実装内容

`poc/app` を Ver1 向けに組み替えた。

構成:

* `Swift`
  * CLI
  * ファイル読込
  * JSON 出力
* `C++`
  * JPEG セグメント解析
  * `offset / length / payload range` 算出

### 追加したコマンド

* `inspect-jpeg-structure <input.jpg>`
  * JPEG の構造情報を JSON で表示する

既存の PoC コマンドは維持した。

* `make-sample <output.jpg>`
* `inspect <input.jpg>`
* `set-dpi <input.jpg> <output.jpg> <dpi> [dpiY]`

### パーサの方針

今回の C++ parser は `read-only` で、以下を順に走査する。

* `SOI`
* `APPn`
* `SOF`
* `DHT`
* `DQT`
* `DRI`
* `SOS`
* `EOI`

`SOS` 以降は通常の length 付きセグメント列ではないため、
圧縮データ中の byte stuffing と restart marker を避けつつ `EOI` を探す実装にした。

---

## 実行コマンド

```bash
cd poc/app
CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build
./.build/debug/app make-sample sample.jpg
./.build/debug/app inspect-jpeg-structure sample.jpg
./.build/debug/app set-dpi sample.jpg sample_300dpi.jpg 300
./.build/debug/app inspect-jpeg-structure sample_300dpi.jpg
```

補助確認:

```bash
cd poc/app
xxd -g 1 -l 96 sample.jpg
```

---

## 観測結果

### 1. `sample.jpg`

構造解析結果:

```json
{
  "fileLength" : 919,
  "ok" : true,
  "segmentCount" : 14,
  "segments" : [
    { "name" : "SOI", "markerHex" : "0xFFD8", "offset" : 0, "length" : 2, "payloadOffset" : 2, "payloadLength" : 0 },
    { "name" : "APP0", "markerHex" : "0xFFE0", "offset" : 2, "length" : 18, "payloadOffset" : 6, "payloadLength" : 14 },
    { "name" : "APP1", "markerHex" : "0xFFE1", "offset" : 20, "length" : 188, "payloadOffset" : 24, "payloadLength" : 184 },
    { "name" : "APP13", "markerHex" : "0xFFED", "offset" : 208, "length" : 58, "payloadOffset" : 212, "payloadLength" : 54 },
    { "name" : "SOF0", "markerHex" : "0xFFC0", "offset" : 266, "length" : 19, "payloadOffset" : 270, "payloadLength" : 15 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 285, "length" : 33, "payloadOffset" : 289, "payloadLength" : 29 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 318, "length" : 183, "payloadOffset" : 322, "payloadLength" : 179 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 501, "length" : 33, "payloadOffset" : 505, "payloadLength" : 29 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 534, "length" : 183, "payloadOffset" : 538, "payloadLength" : 179 },
    { "name" : "DQT", "markerHex" : "0xFFDB", "offset" : 717, "length" : 69, "payloadOffset" : 721, "payloadLength" : 65 },
    { "name" : "DQT", "markerHex" : "0xFFDB", "offset" : 786, "length" : 69, "payloadOffset" : 790, "payloadLength" : 65 },
    { "name" : "DRI", "markerHex" : "0xFFDD", "offset" : 855, "length" : 6, "payloadOffset" : 859, "payloadLength" : 2 },
    { "name" : "SOS", "markerHex" : "0xFFDA", "offset" : 861, "length" : 56, "payloadOffset" : 865, "payloadLength" : 52 },
    { "name" : "EOI", "markerHex" : "0xFFD9", "offset" : 917, "length" : 2, "payloadOffset" : 919, "payloadLength" : 0 }
  ]
}
```

先頭バイト確認:

```text
00000000: ff d8 ff e0 00 10 4a 46 49 46 00 01 01 00 00 48
00000010: 00 48 00 00 ff e1 00 ba 45 78 69 66 00 00 4d 4d
```

対応関係:

* `SOI` は offset `0`
* `APP0` は offset `2`
* `APP1` は offset `20`

これは `xxd` で見える実ファイル位置と一致した。

### 2. `sample_300dpi.jpg`

構造解析結果:

```json
{
  "fileLength" : 969,
  "ok" : true,
  "segmentCount" : 14,
  "segments" : [
    { "name" : "SOI", "markerHex" : "0xFFD8", "offset" : 0, "length" : 2, "payloadOffset" : 2, "payloadLength" : 0 },
    { "name" : "APP0", "markerHex" : "0xFFE0", "offset" : 2, "length" : 18, "payloadOffset" : 6, "payloadLength" : 14 },
    { "name" : "APP1", "markerHex" : "0xFFE1", "offset" : 20, "length" : 200, "payloadOffset" : 24, "payloadLength" : 196 },
    { "name" : "APP13", "markerHex" : "0xFFED", "offset" : 220, "length" : 98, "payloadOffset" : 224, "payloadLength" : 94 },
    { "name" : "SOF0", "markerHex" : "0xFFC0", "offset" : 318, "length" : 19, "payloadOffset" : 322, "payloadLength" : 15 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 337, "length" : 33, "payloadOffset" : 341, "payloadLength" : 29 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 370, "length" : 183, "payloadOffset" : 374, "payloadLength" : 179 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 553, "length" : 33, "payloadOffset" : 557, "payloadLength" : 29 },
    { "name" : "DHT", "markerHex" : "0xFFC4", "offset" : 586, "length" : 183, "payloadOffset" : 590, "payloadLength" : 179 },
    { "name" : "DQT", "markerHex" : "0xFFDB", "offset" : 769, "length" : 69, "payloadOffset" : 773, "payloadLength" : 65 },
    { "name" : "DQT", "markerHex" : "0xFFDB", "offset" : 838, "length" : 69, "payloadOffset" : 842, "payloadLength" : 65 },
    { "name" : "DRI", "markerHex" : "0xFFDD", "offset" : 907, "length" : 6, "payloadOffset" : 911, "payloadLength" : 2 },
    { "name" : "SOS", "markerHex" : "0xFFDA", "offset" : 913, "length" : 54, "payloadOffset" : 917, "payloadLength" : 50 },
    { "name" : "EOI", "markerHex" : "0xFFD9", "offset" : 967, "length" : 2, "payloadOffset" : 969, "payloadLength" : 0 }
  ]
}
```

確認できたこと:

* `APP1` 長が `188 -> 200` に変化しても走査は破綻しない
* `APP13` 長も変化しているが問題なく追跡できる
* 後続セグメントの offset がずれても最後まで正しく列挙できる
* `SOS` と `EOI` も取得できている

---

## 結論

PoC Ver1 の第1段階として、`JPEG read-only parser` は成立した。

成立したこと:

* `Data` と `C++ parser` で JPEG を解析できる
* 主要セグメントを順に列挙できる
* 各セグメントの `offset / length / payloadOffset / payloadLength` を取得できる
* `SOS` 以降の圧縮データを含む JPEG でも `EOI` まで追跡できる
* 将来の `構造選択 -> バイト範囲ハイライト` に必要な基礎情報が取れる

今回まだやっていないこと:

* UI 表示
* 構造ツリー化
* バイト範囲からノードへの逆引き
* PNG / TIFF 対応
* 編集保存

---

## 次の候補

1.
構造結果を SwiftUI で扱いやすいノードモデルへ変換する

2.
`offset-range` を使って、hex viewer 用の選択範囲モデルを作る

3.
JPEG の `APP0 / APP1` 内部もさらに分解する

4.
別 JPEG ファイルでも parser の頑健性を確認する
