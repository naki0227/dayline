# 作業報告書

## 作業日時

2026年09月15日 11時08分05秒 JST

## 作業対象

ActionProposal policy、DaylineProductKit、NotionKit、iOS Notion出力UI、Issue #11。

## 作業目的

選択したSemanticArtifactだけを、決定的policyと利用者の明示確認を経てNotionへ出力できる
Phase 1の外部出力境界を完成させる。

## 変更内容

- Rust FFIからActionProposal v1の検証・policy評価を公開した。
- Swiftのtyped ActionProposal DTOとFFI adapterを追加した。
- ProductKitにMarkdown renderer、proposal生成、二重policy評価、表示状態を追加した。
- NotionKitにKeychain credential storeとCreate Page adapterを追加した。
- iOSにtoken/parent設定、送信内容表示、confirmation、結果表示を追加した。
- Integrations専用CIを追加し、App UI testで確認なし送信を防ぐ導線を検証した。

## 変更したファイル

- `rust/crates/context-ffi/`
- `packages/ContextCoreKit/`、`packages/ContextCoreFFIKit/`
- `packages/DaylineProductKit/Sources/DaylineProductKit/Notion*`
- `integrations/NotionKit/`
- `App/AppActionPolicyAdapter.swift`、`App/AppNotionConfiguration.swift`
- `App/NotionExportView.swift`、`App/DailySummaryCard.swift`
- `App/AppEnvironment.swift`、`App/DaylineAppModel.swift`、`App/RootView.swift`
- `AppUITests/DaylineCaptureUITests.swift`、`project.yml`
- `.github/workflows/integrations.yml`、`Makefile`、architecture checks
- `README.md`、`docs/architecture.md`、`docs/privacy.md`、`docs/product-profiles.md`
- `docs/notion.md`、`docs/TODO.md`

## 変更意図

モデル生成物から外部APIを直接呼ばず、提案・policy・利用者確認・adapter実行を分離するため。

## 設計上の意図

ProductKitは外部出力use case、Rustは決定的認可、NotionKitはKeychain/HTTP、Appはcomposition、
SwiftUIは表示だけを所有する。実行直前にもpolicyを再評価し、integration側でもproposal shapeを
再検証する。credentialやAPI response本文をエラー・ログへ含めない。

## 影響範囲

Daily Summaryからの明示Notion出力とApp依存構成。v1 schema、SQLite migration、capture、
Apple signing/CD値には破壊的変更なし。出力失敗時もローカルartifactは維持される。

## 追加・更新したテスト

- Rust FFI ActionProposal検証/policy評価。
- Swift DTO fixture round-tripとFFI policy integration。
- Product proposal provenance、confirmation、deny、observable state。
- Notion request/version/body、credential前validation、remote failure mapping。
- iOSのprepare、confirmation Alert、明示送信、成功表示。

## 実行した確認コマンド

- `make swift-format-check`: 成功。
- `make swift-lint`: 83ファイル、違反0。
- `swift test --package-path packages/DaylineProductKit --parallel`: 19件成功。
- `swift test --package-path integrations/NotionKit --parallel`: 3件成功。
- `make app-build`: 成功。
- `make app-test`: 初回1件失敗を再現しAlert state競合を修正。
- focused `xcodebuild test ... testNotionExportRequiresExplicitConfirmation`: 1件成功。
- `make ci`: 全blocking gate成功、XCUITest 5件成功。

## CIで確認される内容

Rust、Swift、FFI、Apple App、Integrations、Architecture、Contracts、Quality、Securityの責務別
workflowを維持する。Integrationsはformat/lint/typecheck/unit test/release build、Apple Appは
実Rust XCFramework linkと5件のUI testを確認する。重複検知はwarning-only。

## 未解決の課題

- macOS Terminal/Chrome collectorとenable/disable composition。
- 実Notion workspaceでの手動疎通確認。CIでは意図的に外部送信しない。
- Live Activity/App Intent/Control Center、Calendar adapter、CloudKit allowlist同期。

## 次にやること

macOS Terminal/Chrome collector境界を追加し、raw stdout/stderrやkeystrokeを保存せず、共有
source policyに従うnormalized ContextEventだけをRust storeへ渡す。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/privacy.md`
- `docs/notion.md`
- `packages/DaylineProductKit/Sources/DaylineProductKit/DaylineSourcePolicy.swift`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/TranscriptEventMapper.swift`

## 引き継ぎ事項

次回最初のコマンドは`make ci`。Issue #11のPhase 1のみを進める。Notion token、Apple Team ID、
signing material、個人Contextをfixtureやログへ追加しない。外部writeはActionProposalを迂回させない。
