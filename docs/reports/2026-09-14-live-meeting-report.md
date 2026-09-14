# 作業報告書

## 作業日時

2026年09月14日 21時38分45秒 JST

## 作業対象

ContextCaptureKit、DaylineProductKit、iOS App、Live Meeting profile、Issue #11。

## 作業目的

Phase 1受け入れ条件の「incremental transcript-backed meeting state」を、Dailyの完成済み
file transcriptionと混ぜず、on-device streamingからUIまで縦に接続する。

## 変更内容

- `LiveSpeechStreaming` portとsession-scoped `LiveMeetingCoordinator`を追加した。
- iOS 26 AVAudioEngine bufferをbest available formatへ変換し、SpeechAnalyzerへ流した。
- Speech permission、locale、asset準備をfile/live adapterで共有した。
- volatile結果は表示だけ、final結果はsession ID付きContextEventとして保存した。
- Live profileの30秒間隔でRust storeをqueryし、生成Artifactを保存するservice/modelを追加した。
- Daily/Liveのaudio session所有をApp modelで排他制御した。
- Live indicator、transcript/state表示、start/stop UIとXCUITestを追加した。

## 変更したファイル

- `packages/ContextCaptureKit/Sources/ContextCaptureKit/AppleLiveSpeechStream.swift`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/AppleSpeechSupport.swift`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/LiveMeetingCoordinator.swift`
- `packages/ContextCaptureKit/Tests/ContextCaptureKitTests/LiveMeetingCoordinatorTests.swift`
- `packages/DaylineProductKit/Sources/DaylineProductKit/LiveMeeting*.swift`
- `packages/DaylineProductKit/Tests/DaylineProductKitTests/LiveMeeting*.swift`
- `App/AppEnvironment.swift`、`App/AppCaptureEnvironment.swift`
- `App/DaylineAppModel.swift`、`App/RootView.swift`、`AppUITests/DaylineCaptureUITests.swift`
- `README.md`、`docs/architecture.md`、`docs/capture.md`、`docs/product-profiles.md`、
  `docs/TODO.md`

## 変更意図

Live低遅延処理とDaily長時間recordingを別portにしながら、どちらも同じContextEvent/storeへ
収束させ、Context EngineとApple runtimeを再利用するため。

## 設計上の意図

CaptureKitはaudio/speech/session evidence、ProductKitはprofile/query/update state、Appは
audio mode排他とcomposition、SwiftUIは表示に限定した。外部送信はなく、SpeechとFoundation
Modelsはいずれも端末上で動作する。error/logへtranscriptやpathを含めない。

## 影響範囲

iOS 26 Live microphone capture、local SQLite ContextEvent/SemanticArtifact、Live画面。
iOS 18-25では明示的unavailableとなり、Daily recording/storageは引き続き使用できる。
DB migration、CloudKit、Notion、Calendar、CD signing値には変更なし。

## 追加・更新したテスト

- Live start/stop、volatile/final分離、session provenance、stream failure cleanup。
- Live session query、invalid/empty session、runtime生成、artifact persistence。
- profileの30秒scheduleとready/empty/unavailable presentation state。
- permission-free Live indicator start/stop XCUITest。

## 実行した確認コマンド

- ContextCaptureKit tests: 16件成功。
- DaylineProductKit tests: 10件成功。
- `make swift-format-check`、`make swift-lint`: 成功、違反0。
- `make app-build app-test`: 実Rust FFI link build成功、XCUITest 3件成功。
- `git diff --check`: 成功。

## CIで確認される内容

Swift workflowがformat/lint/typecheck/unit test/release build、Apple App workflowがiOS SDKで
Speech availability境界、実Rust FFI link、3件のdeterministic UI testを確認する。FFI、Rust、
Contracts、Architecture、Security、Qualityは責務別workflowのまま維持する。

## 未解決の課題

- 実端末での長時間Live transcription、Bluetooth、割り込み、asset download検証。
- structured decisions/TODO/ideas/questionsの生成schemaとカード表示。
- Notion明示出力、macOS Terminal/Chrome collector、privacy/source controls。
- retention cleanup、file protection、background retry。

## 次にやること

Foundation Modelsのstructured outputをPhase 1各sectionへ拡張し、source event provenanceを
保持したpresentation modelとカードUIを追加する。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `packages/AppleIntelligenceKit/Sources/AppleIntelligenceKit/AppleFoundationModelRuntime.swift`
- `packages/AppleIntelligenceKit/Sources/AppleIntelligenceKit/ArtifactDocumentFactory.swift`
- `packages/DaylineProductKit/Sources/DaylineProductKit/LiveMeetingService.swift`
- `App/RootView.swift`

## 引き継ぎ事項

Issue #11以外へscopeを広げない。Daily file transcriptionとLive streamingを再統合しない。
同時に二つのaudio ownerを動かさない。volatile speechを保存しない。Team ID、credential、
transcript本文、database pathをログへ出さない。
