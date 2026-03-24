# git-film

Git操作の状態遷移をエミュレートし、prev/nextスナップショットで可視化するCLIツール。

## テスト方針

- **スナップショットテストを優先する**: `inspect(value, content="...")` + `moon test --update` を標準とする
- `assert_eq` / `assert_true` はループ内など inspect が適さない場合のみ使用
- テストはシナリオ型で書く: 操作チェーン全体の最終状態をスナップショットとして記録する
- 新しいテストを書く際は、まず `inspect(value, content="")` で空にしておき、`moon test --update` で自動生成する
- **インライン `inspect` を使う**: `@test.T::snapshot` によるファイルベーススナップショットは使わない。ファイルが増えず管理がシンプル

## ビルド・テスト

```bash
moon check          # 型チェック
moon test           # テスト実行
moon test --update  # スナップショット更新
moon build --target native  # ネイティブビルド
moon fmt            # フォーマット
moon info           # .mbti 更新
```

## パッケージ構成

- `model/` — データ型（FileContent, GitState, Operation等）
- `parser/` — CLI引数・操作文字列のパース
- `emulator/` — git操作の状態遷移ロジック
- `renderer/` — 3領域モデルの出力フォーマット
- `cmd/main/` — エントリーポイント
