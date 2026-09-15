# 作業報告書

## 作業日時

2026年09月15日 10時38分34秒 JST

## 作業対象

DaylineProductKit、iOS composition/UI、Issue #11のprivacy/source controls。

## 作業目的

ユーザーが収集元を明示的に制御でき、無効化がcaptureとContext queryの双方へ確実に反映される
local-first境界を実装する。

## 変更内容

- typed `DaylineSourcePolicy`とactor storeを追加した。
- Daily queryをprofile宣言とuser allowlistの積集合へ制限した。
- Live生成はaudio無効時にfail closedするようにした。
- audio無効化時にDaily/Liveを停止し、設定をUserDefaultsへ保存した。
- audio/browser/shell/calendar Toggleと「端末内のみ」表示を追加した。

## 変更したファイル

- `packages/DaylineProductKit/Sources/DaylineProductKit/DaylineSourcePolicy.swift`
- `packages/DaylineProductKit/Sources/DaylineProductKit/DailySummary*.swift`
- `packages/DaylineProductKit/Sources/DaylineProductKit/LiveMeeting*.swift`
- `packages/DaylineProductKit/Tests/DaylineProductKitTests/*SourcePolicy*Tests.swift`
- `packages/DaylineProductKit/Tests/DaylineProductKitTests/*Summary*Tests.swift`
- `packages/DaylineProductKit/Tests/DaylineProductKitTests/LiveMeeting*Tests.swift`
- `App/AppEnvironment.swift`、`App/AppSourcePolicyPersistence.swift`
- `App/DaylineAppModel.swift`、`App/PrivacySourcesView.swift`、`App/RootView.swift`
- `AppUITests/DaylineCaptureUITests.swift`
- `README.md`、`docs/architecture.md`、`docs/product-profiles.md`、`docs/privacy.md`、
  `docs/TODO.md`

## 変更意図

表示上の設定だけでなく、収集開始・実行中の停止・Rust queryの全箇所で同じpolicyを強制するため。

## 設計上の意図

ProductKitがsource policyとfail-closed判定、Appが永続化とcomposition、SwiftUIが表示を所有する。
空source配列はRustで全件を意味するため、ProductKit境界で拒否する。設定にはsource ID以外の個人情報や
credentialを保存しない。

## 影響範囲

Daily/Live capture、Daily/Live Context query、iOS設定表示。DB migration、FFI contract、CD、
外部送信には変更なし。

## 追加・更新したテスト

- policyのimmutable update、actor snapshot、audio-only default。
- profile/user allowlist積集合、全source無効、Live audio無効のfail-closed。
- Product modelのsource-disabled state。
- local-only表示、audio Toggle、capture button無効化のXCUITest。

## 実行した確認コマンド

- `make swift-format-check`: 成功。
- `make swift-lint`: 成功、違反0。
- `swift test --package-path packages/DaylineProductKit --parallel`: 16件成功。
- `make app-build app-test`: iOS build成功、XCUITest 4件成功。
- `git diff --check`: 成功。

## CIで確認される内容

Swift workflowがformat/lint/typecheck/unit test/release build、Apple App workflowが実Rust FFI
linkと4件のUI testを確認する。他の責務別workflow構成は維持する。

## 未解決の課題

- Notion明示出力とconfirmation UI。
- macOS Terminal/Chrome collectorが同じpolicyを読むcomposition。
- source設定の端末間同期は未実装。SQLiteそのものは同期しない。
- 実端末での録音停止競合と権限変更検証。

## 次にやること

SemanticArtifactをNotion write ActionProposalへ変換し、Rust policy評価と明示confirmationを通す。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/privacy.md`
- `contracts/action-proposal.schema.json`
- `rust/crates/context-policy/src/lib.rs`
- `packages/DaylineProductKit/Sources/DaylineProductKit/ArtifactPresentation.swift`

## 引き継ぎ事項

Issue #11のPhase 1だけを進める。profileはcapability上限、user policyはallowlistであり、どちらかを
省略しない。空source listをRust queryへ渡さない。Notion writeはmodel出力から直接実行せず、必ず
ActionProposalとdeterministic policyを通す。次回最初のコマンドは`make ci`。
