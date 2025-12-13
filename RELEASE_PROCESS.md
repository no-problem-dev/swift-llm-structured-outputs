# リリースプロセス

swift-llm-structured-outputs のリリースプロセスについて説明します。

## バージョニング

このプロジェクトは [セマンティックバージョニング](https://semver.org/spec/v2.0.0.html) に従います:

- **MAJOR** バージョン: 互換性のない API 変更
- **MINOR** バージョン: 後方互換性のある新機能
- **PATCH** バージョン: 後方互換性のあるバグ修正

## リリースフロー

### 1. リリースブランチの準備

```bash
# main からリリースブランチを作成
git checkout main
git pull origin main
git checkout -b release/v1.0.5
```

### 2. CHANGELOG の更新

1. `[未リリース]` セクションの項目を新しいバージョンセクションに移動
2. `YYYY-MM-DD` 形式でリリース日を追加
3. 下部の比較リンクを更新

例:
```markdown
## [未リリース]

## [1.0.5] - 2025-12-14

### 追加
- 新機能の説明

### 修正
- バグ修正の説明
```

### 3. テストの実行

```bash
# すべてのテストを実行
swift test

# 詳細出力でテストを実行
swift test --verbose
```

### 4. プルリクエストの作成

1. リリースブランチをプッシュ
2. `main` に対して `Release v1.0.5` というタイトルで PR を作成
3. PR の説明に CHANGELOG の更新内容を含める
4. 必要に応じてレビューをリクエスト

### 5. マージとリリース

PR が `main` にマージされると、GitHub Action が自動的に以下を実行します:

1. ブランチ名からバージョンを検出（`release/v1.0.5` → `v1.0.5`）
2. git タグを作成（例: `v1.0.5`）
3. GitHub Release を作成:
   - CHANGELOG からのリリースノート
   - ソースコードアーカイブ
4. 次のリリースブランチを自動作成
5. 次のリリース用のドラフト PR を作成

## 手動リリース（必要な場合）

自動リリースが失敗した場合は、手動でリリースを作成できます:

```bash
# リリースをタグ付け
git checkout main
git pull origin main
git tag v1.0.5

# タグをプッシュ
git push origin v1.0.5
```

その後、GitHub でリリースを作成:
1. Releases → New Release に移動
2. タグを選択
3. CHANGELOG.md からリリースノートをコピー
4. リリースを公開

## プレリリースバージョン

プレリリースバージョンにはサフィックスを使用:

- アルファ: `1.0.5-alpha.1`
- ベータ: `1.0.5-beta.1`
- リリース候補: `1.0.5-rc.1`

## チェックリスト

リリース前に確認:

- [ ] すべてのテストが通過
- [ ] CHANGELOG.md が更新済み
- [ ] ドキュメントが最新
- [ ] 破壊的変更がドキュメント化されている
- [ ] バージョン番号が semver に従っている

## ドキュメントの更新

リリース後:

1. DocC ドキュメントは GitHub Actions で自動生成されます
2. ドキュメントの確認: https://no-problem-dev.github.io/swift-llm-structured-outputs/

## ロールバック

リリースを取り消す必要がある場合:

```bash
# ローカルとリモートでタグを削除
git tag -d v1.0.5
git push origin :refs/tags/v1.0.5

# GitHub Release は Web インターフェースから手動で削除
```
