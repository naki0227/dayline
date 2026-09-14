# 作業報告書

## 作業日時

2026年09月14日 20時59分11秒 JST

## 作業対象

ContextEvent contract、ContextCaptureKit pipeline、ContextCoreFFIKit、App composition、
Apple App CI。

## 作業目的

確定文字起こしをversioned ContextEventへ変換し、CaptureKitへFFI/SQLite依存を漏らさず、
実Rust-owned storeへ保存するproduction経路を完成させる。

## 変更内容

- Core-owned `ContextEventPersisting` portと型付きRust adapterを追加した。
- optional `session_id`を必ずJSON nullとして出すstrict contract encodingへ修正した。
- finalized segmentだけをmapper/storeへ渡すpipelineをCoordinatorへ接続した。
- chunk開始時刻をrotation/割り込み単位で保持し、event時刻へ反映した。
- 重複キーへchunk identityを含め、別chunkの同一発話を失わないようにした。
- Appがper-install provenance IDとApplication Support内SQLiteをcompositionした。
- App build/test/archiveが実XCFramework生成・linkを必須とするようにした。

## 変更したファイル

- `packages/ContextCoreKit/Sources/ContextCoreKit/ContextEvent*.swift`
- `packages/ContextCoreKit/Tests/ContextCoreKitTests/ContextCoreKitTests.swift`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/`
- `packages/ContextCaptureKit/Tests/ContextCaptureKitTests/`
- `packages/ContextCoreFFIKit/Sources/ContextCoreFFIKit/RustContextEventStore.swift`
- `packages/ContextCoreFFIKit/Tests/ContextCoreFFIKitTests/RustContextBridgeTests.swift`
- `App/AppCaptureEnvironment.swift`、`project.yml`、`Makefile`
- `.github/workflows/ci-app.yml`
- `README.md`、`docs/architecture.md`、`docs/capture.md`、`docs/ffi.md`、`docs/TODO.md`

## 変更意図

実アプリでもテスト済みのRust redaction/domain invariant/SQLiteを唯一の詳細context storeとして
使い、生成artifact欠落をbuild時に確実に検出するため。

## 設計上の意図

CoreKitは永続化port、CaptureKitはsource normalization/pipeline、FFIKitはinfrastructure、Appは
compositionだけを所有する。contentやpathをerrorへ含めず、Speech失敗とPersistence失敗を
別の有限型として扱う。

## 影響範囲

iOS app build時間、completed audio chunkの後処理、Application Support内のlocal SQLite。
Rust schema/migration、CloudKit、外部送信、CD credentials、GitHub Variablesには変更なし。

## 追加・更新したテスト

- Text ContextEventのnullを含むv1 encode/decode/version検証。
- 型付きSwift eventを実Rust FFI経由でSQLiteへ保存するintegration test。
- finalized transcript pipelineの保存正常系とcontent-free失敗変換。
- 同一chunkの重複拒否と、別chunkの同一発話受け入れ。

## 実行した確認コマンド

- ContextCoreKit test: 4件成功。
- ContextCaptureKit test: 14件成功。
- ContextCoreFFIKit test: 5件成功（実Rust static libraryをlink）。
- `swift format lint --recursive --strict ...`: 成功。
- `swiftlint lint --strict --no-cache`: 違反0。
- `scripts/check-architecture.sh`: 成功。
- `make app-build`: 実Rust XCFrameworkをlinkしたiOS 18 unsigned build成功。
- `make app-build app-test`: build成功、XCUITest 1件成功。

## CIで確認される内容

FFI workflowが全slice生成とbridge integrationを担当する。Apple App workflowはRust toolchainを
準備し、実XCFrameworkをlinkしたunsigned buildとdeterministic UI testを担当する。他の
Rust/Swift/Contract/Architecture/Security/Quality workflowは従来どおり分離される。

## 未解決の課題

- Daily/Live profileとRust store queryを使うproduct presentationが未実装。
- background処理終了前の電源断を考慮したjob queue/retryが未実装。
- audio/transcript retention cleanupとfile data protectionの実機検証が未実装。
- App CIでXCFrameworkを再生成する分、実行時間とcache容量が増える。

## 次にやること

Daily/Live profileをversioned dataとして定義し、まずDaily timelineをRust queryから表示する。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `profiles/`
- `rust/crates/context-ffi/src/lib.rs`
- `packages/ContextCoreFFIKit/Sources/ContextCoreFFIKit/RustContextEventStore.swift`
- `App/RootView.swift`

## 引き継ぎ事項

CaptureKitへFFI/SQLiteをimportしない。volatile発話を保存しない。別chunkの同一発話を重複と
みなさない。generated XCFramework/Swift bindingはcommitせず、buildで再生成する。ログや
errorへtranscript、database path、Team ID、credentialを出さない。
