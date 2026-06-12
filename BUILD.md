# PixelLens Build Guide

## 目的

このファイルは `PixelLens` を `.app` としてビルドし、GitHub 配布用の成果物を作るための手順をまとめたものです。

---

## 現在の構成

実アプリ本体:

* `app/PixelLens.xcodeproj`

プロジェクト定義ファイル:

* `app/project.yml`

注意:

* `app/PixelLens.xcodeproj` は手で直接編集しない
* 設定変更は `app/project.yml` を更新し、`xcodegen` を再実行する

---

## Xcode で開く

```bash
open app/PixelLens.xcodeproj
```

Xcode 上では以下を使います。

* 実行確認: `Product > Run`
* Release ビルド確認: `Product > Build For > Running`
* 配布向けアーカイブ: `Product > Archive`

---

## project.yml を変更した後

```bash
cd app
xcodegen
```

これで `PixelLens.xcodeproj` が再生成されます。

---

## CLI で Release ビルド

```bash
cd app
xcodebuild \
  -project PixelLens.xcodeproj \
  -scheme PixelLens \
  -configuration Release \
  -derivedDataPath .derivedData \
  build
```

成果物の出力先:

* `app/.derivedData/Build/Products/Release/PixelLens.app`

---

## GitHub 配布用 zip 作成

```bash
cd app/.derivedData/Build/Products/Release
ditto -c -k --sequesterRsrc --keepParent "PixelLens.app" "PixelLens-macOS.zip"
```

出力物:

* `app/.derivedData/Build/Products/Release/PixelLens-macOS.zip`

この zip を GitHub Releases に添付して配布します。

---

## 現時点の配布上の注意

* 現在は `Sign to Run Locally` で署名される
* App Store 配布や notarization はまだ行っていない
* 他の Mac では初回起動時に Gatekeeper の警告が出る可能性がある

---

## 次にやる候補

* アプリアイコン追加
* `Archive` 手順の確認
* GitHub Releases 用のバージョン運用
* 必要なら Developer ID 署名と notarization 対応

---

## 個人アプリのビルド

自分の Mac で使うだけなら、毎回 `Archive` までは不要です。

基本フロー:

1. コードを修正する
2. `app/project.yml` を変更した場合のみ `xcodegen` を実行する
3. Release ビルドを行う
4. 生成された `.app` をローカル利用場所へコピーする
5. 必要なら ad-hoc で再署名する

### `xcodegen` が必要なケース

以下を変更したときは `xcodegen` が必要です。

* `app/project.yml`
* target 名
* scheme 名
* Bundle Identifier
* ビルド設定
* Assets や Resources のプロジェクト登録方法

実行コマンド:

```bash
cd app
xcodegen
```

### Release ビルド

```bash
cd app
xcodebuild \
  -project PixelLens.xcodeproj \
  -scheme PixelLens \
  -configuration Release \
  -derivedDataPath .derivedData \
  build
```

### ローカルで使う `.app` の配置

現在の運用では、最終的に使う `.app` はリポジトリ外のローカル配置先に置く。

例:

* `<local-app-dir>/PixelLens.app`

### `.app` を更新する手順

```bash
mkdir -p <local-app-dir>
rm -rf <local-app-dir>/PixelLens.app
ditto \
  app/.derivedData/Build/Products/Release/PixelLens.app \
  <local-app-dir>/PixelLens.app
codesign --force --deep --sign - <local-app-dir>/PixelLens.app
```

補足:

* `.derivedData` の中身は Xcode の内部生成物なので、普段使いの場所としては扱わない
* Finder から開くのは `<local-app-dir>/PixelLens.app` を使う
* コード変更後は、再ビルドしてこの `.app` を置き換える
