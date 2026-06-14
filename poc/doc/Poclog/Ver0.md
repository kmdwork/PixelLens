# PoC Var0.1.0

## 目的

Swift + ImageIO で JPEG 保存時に以下が可能かを確認する。

* JFIF の解像度情報を更新できるか
* TIFF / EXIF 系の解像度情報を更新できるか
* 既存 EXIF 情報を保持できるか

---

## 実装場所

* [poc/app/Package.swift](/mac-app/img_editor/poc/app/Package.swift)
* [poc/app/Sources/app/app.swift](/mac-app/img_editor/poc/app/Sources/app/app.swift)

---

## 実装内容

`poc/app` に Swift Package ベースの CLI PoC を作成した。

コマンド:

* `make-sample <output.jpg>`
  * 72dpi のサンプル JPEG を生成する
  * EXIF に `DateTimeOriginal` を入れる
* `inspect <input.jpg>`
  * JPEG のメタデータを読み取り JSON で表示する
* `set-dpi <input.jpg> <output.jpg> <dpi> [dpiY]`
  * JPEG を保存し直し、解像度情報を更新する

確認対象:

* JFIF
  * `XDensity`
  * `YDensity`
  * `DensityUnit`
* TIFF
  * `XResolution`
  * `YResolution`
  * `ResolutionUnit`
* EXIF
  * `DateTimeOriginal`

---

## 実行コマンド

```bash
cd poc/app
CLANG_MODULE_CACHE_PATH=$PWD/.build/ModuleCache swift build
./.build/debug/app make-sample sample.jpg
./.build/debug/app set-dpi sample.jpg sample_300dpi.jpg 300
./.build/debug/app inspect sample_300dpi.jpg
```

---

## 観測結果

### 1. サンプル生成直後

```json
{
  "exifDateTimeOriginal" : "2024:01:02 03:04:05",
  "height" : 24,
  "jfifDensityUnit" : 0,
  "jfifXDensity" : 72,
  "jfifYDensity" : 72,
  "tiffResolutionUnit" : 2,
  "tiffXResolution" : 72,
  "tiffYResolution" : 72,
  "width" : 32
}
```

確認できたこと:

* `TIFF XResolution/YResolution` は 72
* `EXIF DateTimeOriginal` は保持されている
* `JFIF XDensity/YDensity` は 72
* ただし `JFIF DensityUnit` は 1 を指定しても 0 で出力された

### 2. 300dpi 更新後

```json
{
  "exifDateTimeOriginal" : "2024:01:02 03:04:05",
  "height" : 24,
  "jfifDensityUnit" : 0,
  "jfifXDensity" : 72,
  "jfifYDensity" : 72,
  "tiffResolutionUnit" : 2,
  "tiffXResolution" : 300,
  "tiffYResolution" : 300,
  "width" : 32
}
```

確認できたこと:

* `TIFF XResolution/YResolution` は 300 に更新された
* `EXIF DateTimeOriginal` は保持された
* `JFIF XDensity/YDensity` は 72 のままで更新されなかった
* `JFIF DensityUnit` も 0 のままだった

---

## 実装上の試行

`set-dpi` 実装では以下を試した。

* `CGImageDestinationCopyImageSource`
  * メタデータ更新用途としてはそのまま使えず失敗した
* `CGImageDestinationAddImageFromSource`
  * TIFF 解像度は更新できた
  * JFIF は更新されなかった
* `CGImageDestinationAddImage`
  * 再エンコード経路でも JFIF は更新されなかった

---

## 結論

PoC Var1 の範囲では、`Swift + ImageIO` のみで JPEG の `JFIF` と `TIFF / EXIF 系解像度` を同時に期待通り更新することはできなかった。

成立したこと:

* JPEG の読込
* TIFF 解像度更新
* EXIF の一部保持

成立しなかったこと:

* JFIF `XDensity / YDensity / DensityUnit` の期待通りの更新

---

## 次の判断候補

* MVP は `TIFF / EXIF 系解像度の更新` を正式仕様にする
* `JFIF` まで必須なら、ImageIO 以外の方法で JPEG メタデータを直接編集する

---

# PoC Var0.1.1

## 目的

PoC Var1 では `JFIF` が更新できないことは確認できたが、以下の切り分けは未確定だった。

* 読込時に JFIF が失われているのか
* 保存時に JFIF 指定が無視されているのか
* `CGImageDestinationFinalize` 後の最終ファイルで JFIF が変化しているのか

このため、JPEG の先頭バイト列を直接確認し、`JFIF APP0` セグメントの実体を追跡した。

---

## 実施内容

以下を確認した。

1. `make-sample` 直後の `sample.jpg`
2. `inspect sample.jpg` の読取結果
3. `set-dpi` 実行後の `sample_300dpi.jpg`
4. `inspect sample_300dpi.jpg` の読取結果
5. 両ファイルの先頭 32 バイト

実行コマンド:

```bash
cd poc/app
./.build/debug/app make-sample sample.jpg
xxd -g 1 -l 32 sample.jpg
./.build/debug/app inspect sample.jpg

./.build/debug/app set-dpi sample.jpg sample_300dpi.jpg 300
xxd -g 1 -l 32 sample_300dpi.jpg
./.build/debug/app inspect sample_300dpi.jpg
```

---

## 観測結果

### 1. `sample.jpg` の先頭バイト

```text
00000000: ff d8 ff e0 00 10 4a 46 49 46 00 01 01 00 00 48
00000010: 00 48 00 00 ff e1 00 ba 45 78 69 66 00 00 4d 4d
```

読み取り方:

* `ff e0` : APP0
* `4a 46 49 46 00` : `JFIF\0`
* `01 01` : version 1.01
* `00` : density unit
* `00 48` : XDensity = 72
* `00 48` : YDensity = 72

これは `inspect sample.jpg` の結果と一致した。

結論:

* `read` 側が値を取り違えているわけではない
* `make-sample` の保存結果の時点で、実ファイルに `unit=0, density=72/72` が書かれている

### 2. `sample_300dpi.jpg` の先頭バイト

```text
00000000: ff d8 ff e0 00 10 4a 46 49 46 00 01 01 00 00 48
00000010: 00 48 00 00 ff e1 00 c6 45 78 69 66 00 00 4d 4d
```

確認できたこと:

* `JFIF APP0` セグメントは残っている
* しかし `DensityUnit` は `00` のまま
* `XDensity/YDensity` も `72/72` のまま
* 一方で APP1 長は `00 ba -> 00 c6` に変化しており、EXIF / TIFF 側のメタデータ更新は実施されていると考えられる

`inspect sample_300dpi.jpg` の結果も以下で一致した。

* `JFIF DensityUnit = 0`
* `JFIF XDensity = 72`
* `JFIF YDensity = 72`
* `TIFF XResolution = 300`
* `TIFF YResolution = 300`

---

## Var2 の結論

PoC Var2 の時点で、以下まではかなり明確に言える。

* `JFIF` は読込時に失われていない
* `JFIF` は保存後ファイルにも存在している
* ただし `ImageIO` 経由の保存では、`JFIF XDensity / YDensity / DensityUnit` の変更指定が最終ファイルに反映されていない
* `TIFF / EXIF 系` の更新は保存後ファイルに反映されている

つまり、現時点の問題は「JFIF が消えている」のではなく、

* `保存パイプラインで JFIF 更新指定が無視されている`

と表現する方が正確である。

---

## 次の示唆

`JFIF` まで必須とするなら、次のどちらかが必要になる可能性が高い。

* ImageIO 以外のライブラリを使う
* JPEG の APP0 / APP1 セグメントを直接編集する

少なくとも PoC Var2 の結果からは、`Swift + ImageIO` の標準的な保存経路だけで `JFIF` を期待通り更新できる見込みは低い。
