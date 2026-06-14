# PixelLens Ver1 実装タスク

## 目的

`AGETNS.md` の Ver1 要件を、実装順に落としたタスクリストである。

Ver1 の MVP は `JPEG read-only 構造可視化ツール` とし、
まずは以下を成立させる。

* JPEG を開ける
* 構造一覧を見られる
* バイト列を見られる
* 構造選択で対応範囲をハイライトできる
* 選択ノードの詳細を見られる

現時点で最小版はすでに実装済みであり、
ここからは以下の改善を優先する。

* byte viewer の軽量化
* Inspector の raw info 強化
* `APP0 / APP1` の子ノード生成
* `EXIF / TIFF` tag parser 追加

進捗メモ:

* `APP0 / APP1` の子ノード生成は実装済み
* `IFD0` に加えて `Exif IFD` の展開を開始済み
* `Edit Mode` と `pending changes` の UI 土台は実装済み
* `Save As` の最小経路は実装済み
* 現在の保存対応は `JFIF / TIFF / EXIF` の既知 tag に対する固定長上書きのみ

その次の段階として、
`read-only viewer` から `構造化メタデータ編集` へ進める。

編集機能の初期方針:

* 直接バイト編集は行わない
* `Inspector` ベースで既知の値だけ編集する
* `Edit Mode` と通常閲覧モードを分ける
* 初期は `Save As` のみ
* 保存前に変更点を確認できるようにする
* 初期保存は `可変長再配置なし` の固定長書き換えに限定する

---

## Phase 1: コア整備

### 1-1. C++ parser を app 本体へ移植する

内容:

* `poc/app` の JPEG read-only parser を `app` 側へ移す
* `Swift <-> C++` の橋渡し方法を本実装向けに整理する
* PoC 用 CLI 実装と本アプリ実装を分離する

完了条件:

* `app` から JPEG 構造解析結果を取得できる
* `offset / length / payload range` が Swift 側で扱える

### 1-2. ノードモデルを定義する

内容:

* `SegmentNode` もしくは同等の内部モデルを定義する
* SwiftUI が扱いやすいラッパモデルを作る
* `Identifiable` や選択状態を考慮した構造にする

完了条件:

* 構造一覧 UI にそのまま流せるモデルがある

### 1-3. 読み込みエラー処理を整理する

内容:

* 非 JPEG 読み込み時のエラー
* 壊れた JPEG のエラー
* parser failure のエラー
* UI に出すメッセージ方針

完了条件:

* 最低限、`開けない理由` をユーザーに見せられる

---

## Phase 2: ファイル読み込みとプレビュー

### 2-1. JPEG ファイル読み込みを Ver1 用に整理する

内容:

* ファイル選択ダイアログ
* ドラッグ＆ドロップ
* 単一ファイルのみ許可

完了条件:

* JPEG を開いたらアプリ状態が更新される

### 2-2. 画像プレビュー表示を残す

内容:

* Ver0 のプレビューを再利用または整理
* 画像サイズとファイル名の表示

完了条件:

* 構造確認中に元画像を見られる

---

## Phase 3: 構造一覧 UI

### 3-1. 構造一覧表示を作る

内容:

* 左ペインまたは上部で構造一覧を表示
* 最初はツリーでなくフラットリストでも可
* 項目として `name / marker / offset / length` を表示

完了条件:

* `SOI / APP0 / APP1 / DQT / DHT / SOS / EOI` を目視確認できる

### 3-2. 選択状態を持たせる

内容:

* 一覧で 1 ノードを選択できる
* 選択ノードを AppModel で保持する

完了条件:

* UI で現在選んでいる構造要素が明確になる

### 3-3. `APP0 / APP1` の子ノードを生成する

内容:

* `APP0` を JFIF として分解する
* `APP1` を EXIF として分解する
* flat list から 1 段深いツリーへ移行できる形にする

表示候補:

* `APP0`
  * identifier
  * version
  * density unit
  * X density
  * Y density
* `APP1`
  * Exif header
  * TIFF header
  * IFD0
  * Exif IFD

完了条件:

* `APP0 / APP1` を選ぶだけでなく、その内部要素も一覧に出せる
* `ExifIFDPointer` を辿って `Exif IFD` を表示できる

---

## Phase 4: Hex / Byte Viewer

### 4-1. バイト列表示の最小版を作る

内容:

* 16進表示
* ASCII 表示
* オフセット列表示

方針:

* 最初は read-only のみ
* 全文表示が重ければ行単位データ化を検討

完了条件:

* JPEG ファイルのバイト列を閲覧できる

### 4-2. 表示モデルを分ける

内容:

* raw bytes と描画用行モデルを分ける
* 1行16バイトなどの表示単位を決める

完了条件:

* ハイライトや将来の逆引きに拡張しやすい構造になる

### 4-3. byte viewer を仮想化する

内容:

* `可視範囲 + 前後1行` だけ描画する
* 1バイト1View を避け、可能な限り `1行単位で描画` する
* スクロールに合わせて表示行を差し替える

方針:

* 先頭だけ固定表示する暫定実装から卒業する
* 大きい JPEG でもスクロール不能にならないことを優先する

完了条件:

* 大きめの JPEG でもスクロール時に固まりにくい

### 4-4. ハイライト更新を表示中の行だけに限定する

内容:

* 選択時ハイライトは `全行再生成` ではなく `表示中の行だけ更新` する
* byte range の再計算と描画更新を分ける

完了条件:

* セグメント選択時の UI 応答が重くならない

---

## Phase 5: 構造選択ハイライト

### 5-1. ノード選択時の範囲計算

内容:

* `offset` と `length` から byte range を計算する
* marker を含めてハイライトするか、payload のみも出せるようにするか決める

完了条件:

* ノード選択時に対象 byte range が一意に決まる

### 5-2. Hex Viewer 上のハイライト表示

内容:

* 選択範囲の色付け
* 行をまたぐ範囲でも崩れない描画

完了条件:

* `APP0` などを選ぶと対応バイトが視覚的にわかる

---

## Phase 6: Inspector

### 6-1. 選択ノードの詳細表示

内容:

* name
* marker
* offset
* length
* payloadOffset
* payloadLength

完了条件:

* 選択ノードの基本情報を確認できる

### 6-2. 補足説明を入れる

内容:

* `APP0` は JFIF の可能性
* `APP1` は EXIF の可能性
* `DQT`, `DHT`, `SOS` の簡単な説明

完了条件:

* ただの数値一覧ではなく、構造理解の補助になる

### 6-3. raw info を追加する

内容:

* 選択ノードの raw bytes を表示する
* 先頭数バイトを 16進で見せる
* payload のサイズと範囲を明示する

完了条件:

* Inspector だけでも `このノードが何を指しているか` を追いやすい

### 6-4. decoded value を段階的に追加する

内容:

* `APP0` では JFIF version / density unit / density 値
* `APP1` では Exif header の有無
* 将来的に TIFF tag の decoded value を表示

完了条件:

* `APP` 系ノードで具体的な意味値を確認できる

---

## Phase 1 拡張: EXIF / TIFF Parser

### 1-X-1. `APP1` 内の TIFF header を解析する

内容:

* endian を判定する
* first IFD offset を読む
* IFD エントリ列を走査する

完了条件:

* `APP1` の中から TIFF header と IFD0 情報を取り出せる

### 1-X-2. TIFF tag parser を追加する

内容:

* tag id
* type
* count
* value / valueOffset
* known tag 名称

優先対象:

* `XResolution`
* `YResolution`
* `ResolutionUnit`
* そのほか PoC で見える主要タグ

完了条件:

* EXIF / TIFF の主要 tag をノードまたは Inspector 値として表示できる

---

## Phase 7: アプリ構成整理

### 7-1. Ver0 の DPI UI を整理する

内容:

* Ver1 で不要になった DPI 入力や保存 UI を外す
* 旧ロジックを残すなら分離する

完了条件:

* 画面の主目的が `構造可視化` に揃う

### 7-2. 名前と文言を Ver1 に合わせる

内容:

* README
* UI タイトル
* 補助文言

完了条件:

* アプリ説明が `DPI変更ツール` のまま残っていない

---

## Phase 8: 品質確認

### 8-1. 複数 JPEG で parser 確認

内容:

* PoC 生成 JPEG 以外でも確認
* APP セグメント構成が異なる JPEG を試す

完了条件:

* 少なくとも数種類の JPEG で UI が破綻しない

---

## Phase 9: 編集機能MVP

### 9-1. 編集モードを追加する

内容:

* 通常閲覧モードと `Edit Mode` を分ける
* `Edit` ボタンで編集開始
* `Cancel` で編集破棄

完了条件:

* 閲覧時と編集時の UI が明確に分かれる

### 9-2. 編集可能ノードを限定する

内容:

* 初期は既知のメタデータ値のみ編集対象にする
* 具体例:
  * `JFIF DensityUnit`
  * `JFIF XDensity`
  * `JFIF YDensity`
  * `TIFF XResolution`
  * `TIFF YResolution`
  * `ResolutionUnit`

完了条件:

* すべてのノードが編集可能ではなく、対象が明確に制限される

### 9-3. Inspector 内編集 UI を作る

内容:

* 選択ノードが編集対象なら入力欄を出す
* 数値、列挙値など型に応じた入力方式にする
* `Apply` で一時反映する

完了条件:

* 選択ノードの値を Inspector から変更できる

### 9-4. pending changes を保持する

内容:

* 元の値と変更後の値を別管理する
* どのノードが変更済みかを持つ
* dirty state を持つ

完了条件:

* 未保存変更の有無を判断できる

### 9-5. バリデーションを追加する

内容:

* 数値範囲チェック
* 不正な列挙値の防止
* 保存不能時のエラー表示

完了条件:

* 不正な編集内容で保存処理に入らない

### 9-6. Save As ベースの保存を実装する

内容:

* 上書き保存ではなく別名保存を基本とする
* 保存先を選べるようにする
* 編集内容を serializer へ渡して再構築する

完了条件:

* 元ファイルを壊さずに編集結果を書き出せる

### 9-7. 変更前後の確認 UI を作る

内容:

* どのノードがどう変わるかを一覧表示する
* 可能なら byte range も出す
* 将来的には diff 表示へ拡張できる形にする

完了条件:

* 保存前に変更内容を人間が確認できる

---

## 編集対象の優先順位

初期に編集対象として向いているもの:

* `JFIF DensityUnit`
* `JFIF XDensity`
* `JFIF YDensity`
* `TIFF XResolution`
* `TIFF YResolution`
* `ResolutionUnit`

後回しにするもの:

* 任意バイト編集
* セグメント追加削除
* `APP1` の大規模再配置
* 圧縮データ本体の編集
* DHT / DQT の編集

---

## 編集機能の設計原則

* `parser` と `serializer` は分ける
* 編集対象は `decoded value` ベースにする
* UI は `Inspector` 中心にする
* 保存は最初から `Save As`
* 初期は `read-only viewer` の安全性を壊さない

### 8-2. 大きめファイルで表示確認

内容:

* 表示速度
* スクロールの重さ
* メモリ使用感

完了条件:

* MVP として耐えないボトルネックが見えている

---

## MVP 完了条件

以下が揃えば Ver1 MVP とみなす。

* JPEG を開ける
* 画像プレビューが出る
* 構造一覧が出る
* バイト列表示が出る
* 構造選択で対応範囲がハイライトされる
* Inspector で選択ノード詳細を確認できる

---

## 着手順の推奨

1. `Phase 4-3` byte viewer を仮想化する
2. `Phase 4-4` ハイライト更新を表示中の行だけに限定する
3. `Phase 6-3` Inspector に raw info を追加する
4. `Phase 3-3` `APP0 / APP1` の子ノードを生成する
5. `Phase 1-X-1` `APP1` 内の TIFF header を解析する
6. `Phase 1-X-2` TIFF tag parser を追加する
7. `Phase 6-4` decoded value を Inspector に表示する

---

## 今すぐの次タスク

直近で着手するべきなのはこれである。

* `可視範囲 + 前後1行` だけ描画する byte viewer に切り替える
* `1行単位で描画` する構造へ寄せる
* `選択時ハイライト` を表示中の行だけ更新する
* `APP0 / APP1` の内部値を出すための子ノード設計を始める

編集機能フェーズに入る直前の次タスク:

* `ExifIFDPointer` を辿って `Exif IFD` を展開する
* 編集対象ノードを `kind` または tag id で識別できるようにする
* serializer 導入前提の内部変更モデルを設計する
