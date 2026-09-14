# 作業報告書

## 作業日時

2026年09月14日 17時15分33秒 JST

## 作業対象

Rust/Swift FFI、ContextCoreKit DTO、AppleIntelligenceKit stub runtime、垂直統合テスト。

## 作業目的

Issue #1が先行条件とした
`ContextEvent -> ContextBundle -> Swift runtime -> SemanticArtifact -> persistence`
を、mock transportではなく実XCFramework経由で動作させる。

## 変更内容

- Rustにversioned JSONのUniFFI bridge 3関数とcontent-safe errorを追加した。
- iOS device、universal Simulator、universal macOSのXCFramework生成を追加した。
- ContextCoreKitにContextBundle/SemanticArtifact DTOとcodecを追加した。
- ContextCoreFFIKitにgenerated bindingを隔離し、Swift facadeを追加した。
- AppleIntelligenceKitに構造化`IntelligenceRuntime`と決定的stubを追加した。
- Event保存、Bundle生成、stub Artifact生成、Artifact保存を一続きでテストした。
- FFI CIを独立workflowにし、通常Swift CIで巨大生成物を重複buildしないようにした。

## 変更したファイル

- `rust/crates/context-ffi/`
- `rust/tools/uniffi-bindgen/`
- `fixtures/vertical-slice-request-v1.json`
- `scripts/build-context-xcframework.sh`
- `packages/ContextCoreKit/`
- `packages/ContextCoreFFIKit/`
- `packages/AppleIntelligenceKit/`
- `Makefile`、`.gitignore`、`.swiftlint.yml`
- `.github/workflows/ci-ffi.yml`、`.github/workflows/ci-swift.yml`
- `docs/adr/0005-uniffi-json-boundary.md`、`docs/ffi.md`、`docs/TODO.md`

## 変更意図

Rust domain型をFFI型として二重管理せず、既存JSON Schemaを唯一の互換契約にする。
生成コードとbinary linkageをContextCoreKitから隔離し、Apple runtimeを差し替え可能にする。

## 設計上の意図

- UniFFI 0.31.2をpinし、upgrade driftを防ぐ。
- FFI errorへraw input、secret、database pathを含めない。
- generated source/XCFrameworkはcommitせず、lockfileから再現する。
- model-specific token計測は引き続きAppleIntelligenceKitの責務にする。
- stubも`SemanticArtifactDocument`を返し、実runtimeと同じ構造化境界を通す。

## 影響範囲

Rust workspace、Swift package graph、macOS/iOS FFI build、専用CI。Dayline app targetは
まだContextCoreFFIKitへ直接依存せず、既存unsigned buildへの影響を避けている。

## 追加・更新したテスト

- Rust FFI request version、ContextBundle生成、Event→Artifact保存。
- Swift contract fixture decode/round-trip/version validation。
- stub runtimeのprovenance、sensitivity、language、empty context。
- generated bindingによるBundle生成とEvent保存。
- 実XCFrameworkでのEvent→Bundle→stub→Artifact→SQLite垂直スライス。

## 実行した確認コマンド

- Rust `fmt`、`clippy -D warnings`、全workspace test、release build: 成功。
- `cargo audit --file rust/Cargo.lock --no-fetch`: 脆弱性なし。
- `scripts/build-context-xcframework.sh`: 3 platform variant生成成功。
- `swift test --package-path packages/ContextCoreKit --parallel`: 3件成功。
- `swift test --package-path packages/AppleIntelligenceKit --parallel`: 3件成功。
- `swift test --package-path packages/ContextCoreFFIKit --parallel`: 3件成功。
- `swift format lint --recursive --strict ...`: 成功。
- `swiftlint lint --strict --no-cache`: 違反0。
- `scripts/check-architecture.sh`、`git diff --check`: 成功。

## CIで確認される内容

新しい`CI / Rust-Swift FFI`がlocked dependenciesから全Apple sliceを生成し、実link
integration testを実行する。既存Rust、Swift、App、Contracts、Architecture、Release
Tools、Security、warn-only Qualityは責務別workflowのまま維持する。

## 未解決の課題

- 実Foundation Models runtime、availability、実token測定、shrink retryが未実装。
- iOS appからContextCoreFFIKitをcompositionする段階は未着手。
- XCFrameworkは約143MBで、App組み込み前にsize測定・最適化が必要。
- UniFFIのXcode 26/27 module-map workaroundはupstream修正後に削除する。

## 次にやること

Foundation Modelsをavailabilityで隔離したruntime adapterと、model計測結果に応じて
Rustへ縮小要求を返すloopを実装する。その後iOS capture/UIの最小縦切りへ進む。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/adr/0005-uniffi-json-boundary.md`
- `docs/ffi.md`
- `packages/AppleIntelligenceKit/Sources/AppleIntelligenceKit/IntelligenceRuntime.swift`
- `packages/ContextCoreFFIKit/Tests/ContextCoreFFIKitTests/RustContextBridgeTests.swift`

## 引き継ぎ事項

最初にIssue #1とGitHub Actionsを確認する。生成物は編集・commitしない。FFI処理と
SQLite処理をMainActorで実行しない。RustへApple model token semanticsを導入しない。
