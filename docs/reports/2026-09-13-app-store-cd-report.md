# 作業報告書

## 作業日時

2026年09月13日 23時22分55秒

## 作業対象

Dayline最小iOS App target、App Store向けMakefileコマンド、App Store Connect
Python CLI、タグ起点CD、セキュリティCI。

## 作業目的

`useful_map`で実績のあるApple配信方式をDaylineへ責務分離して再現し、
`v*`タグで意図的にデプロイできる基盤を作る。公開リポジトリへ認証情報を残さない。

## 変更内容

- XcodeGen管理の最小Dayline iOS App targetを追加した。
- iOS Appの署名なし生成・ビルドCIを独立workflowとして追加した。
- App Store Connect APIクライアントを認証、HTTP、app、profile、buildへ分割した。
- Makefileにprofile取得、archive、export、検証、upload、build紐付けを追加した。
- `v*`タグでupload、手動実行ではdry-run既定となるCDを追加した。
- Team ID、bundle ID、profile名をGitHub Repository Variablesへ登録した。
- 証明書、パスワード、API key関連をGitHub Secrets専用とした。
- Team IDをソースとexport plistから除外し、実行時に設定を生成するようにした。
- Git履歴全体のGitleaks検査とRust／Python依存監査を追加した。
- 公開Actions artifactへ署名済みIPAを保存しない方針にした。

## 変更したファイル

- `App/DaylineApp.swift`、`App/RootView.swift`、`App/Info.plist`
- `project.yml`、`Makefile`
- `.github/actions/select-toolchain/action.yml`
- `.github/workflows/{ci-app,ci-release-tools,release,security}.yml`
- `.github/workflows/ci-swift.yml`
- `scripts/asc.py`、`scripts/render_export_options.py`
- `scripts/app_store_connect/*.py`
- `scripts/tests/*.py`、`scripts/requirements-*.txt`
- `README.md`、`docs/release.md`、`docs/TODO.md`
- `docs/adr/0002-tag-based-app-store-delivery.md`

## 変更意図

ローカルとCDで同じMakefile入口を使い、GitHub Actions固有の処理を証明書の一時投入と
イベント制御に限定する。App Store Connect API処理を単一巨大スクリプトにせず、
外部I/O境界とユースケースを個別にテストできるようにする。

## 設計上の意図

- 通常の`main` pushとApple uploadを分離する。
- release処理は順番を固定し、並列実行によるupload前のbuild紐付けを防ぐ。
- Team IDなど非機密識別子はVariables、秘密鍵と証明書はSecretsへ分類する。
- ExportOptionsは実行時生成し、account固有Team IDをGit履歴へ残さない。
- API keyと証明書は一時パス／一時keychainに置き、終了時に削除する。

## 影響範囲

iOSのcomposition root、開発CI、release automation、GitHub Repository Variables。
録音・Context Engineなどの製品機能、DB、CloudKitには影響しない。App Storeへのlive
uploadは実行していない。

## 追加・更新したテスト

- App Store設定の必須値・default値: 2件
- provisioning profileのactive profile取得・保存: 1件
- latest VALID buildのversion紐付け: 1件
- ExportOptionsのTeam ID必須化と動的生成: 2件
- 最小iOS Appの署名なしbuild CI
- Gitleaksによる全Git履歴の秘密情報検査
- RustSecとpip-auditによる依存監査

## 実行した確認コマンド

- `make release-tools-format release-tools-ci`: 成功
- `make ci`: 成功
- `make app-build`: 成功（Xcode 26.6、iOS Simulator SDK 26.5）
- ダミーTeam IDを使った`make export-options`: 成功
- `make -n release-dry-run ...`: 実行順と引数を確認
- `make -n release-upload ...`: 実行順と引数を確認
- `git diff --check`: 成功
- 全GitHub Actions YAMLのparser読み込み: 成功
- Git履歴・作業ツリーの秘密情報パターン検査: 実値の検出なし
- `.p8`、`.p12`、`.mobileprovision`、`.cer`、`.env`探索: 検出なし
- GitHub Actions: Release Tools、Architecture、Rust、重複検査は成功
- Security初回: GitleaksとPython監査は成功。Rust監査のtoken不足を修正済み

## CIで確認される内容

- Rust: format、Clippy、typecheck、unit test、release build
- Swift: format、SwiftLint、typecheck、unit test、release build
- Apple App: XcodeGen生成、iOS署名なしbuild
- Release Tools: Ruff format/lint、mypy、6 unit tests、compileall
- Architecture: 禁止依存
- Cross-cutting: jscpd重複レポート（非blocking）
- Security: Git履歴secret scan、RustSec、pip-audit

## 未解決の課題

- Apple DeveloperとApp Store Connectで`com.dayline.Dayline`の登録確認が必要。
- GitHub Secrets 5件は未登録。
- App icon、App Store metadata、screenshotsが未作成。
- 実認証を伴うarchive、Apple validation、uploadは未実行。
- `altool`廃止・変更時は配信adapterの見直しが必要。

## 次にやること

製品機能の最初として、v1 `ContextEvent` contractとRust domain modelを正常系・異常系・
境界値テスト付きで実装する。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/adr/0002-tag-based-app-store-delivery.md`
- `docs/release.md`
- `Makefile`
- `.github/workflows/release.yml`
- `rust/crates/context-domain/src/lib.rs`

## 引き継ぎ事項

- 次回最初のコマンドは`make ci`。
- release前に`gh secret list`で必要Secret名だけを確認する。値はログへ出さない。
- 秘密鍵ファイルをリポジトリ内へ置かない。
- `main` pushではAppleへ送らず、タグまたは明示的な手動uploadだけを使う。
- `release-upload`のprofile、archive、export、upload、attach順を崩さない。
- `com.dayline.Dayline`が未登録ならタグをpushしない。
