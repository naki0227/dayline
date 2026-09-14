# 作業報告書

## 作業日時

2026年09月14日 20時49分47秒 JST

## 作業対象

ContextCaptureKitの音声文字起こし、ContextCoreKitのContextEvent DTO、Dayline表示。

## 作業目的

録音済みchunkをAppleのオンデバイス音声認識へ渡し、確定した発話だけを追跡可能な
ContextEvent v1へ変換できる境界を作る。

## 変更内容

- iOS 26 SpeechAnalyzer/SpeechTranscriber adapterとasset準備を追加した。
- volatile/finalizedを分離し、空文字と重複finalを除外するbufferを追加した。
- chunk完了後の文字起こしをCaptureCoordinatorへ接続した。
- 確定発話をtimezone、retention、provenance付きContextEventへ変換した。
- 最新の仮説または確定発話をDayline画面へ表示した。

## 変更したファイル

- `packages/ContextCaptureKit/Sources/ContextCaptureKit/`
- `packages/ContextCaptureKit/Tests/ContextCaptureKitTests/`
- `packages/ContextCoreKit/Sources/ContextCoreKit/ContextEventDocument.swift`
- `packages/ContextCoreKit/Tests/ContextCoreKitTests/ContextCoreKitTests.swift`
- `App/AppCaptureEnvironment.swift`、`App/RootView.swift`
- `README.md`、`docs/architecture.md`、`docs/capture.md`、`docs/TODO.md`

## 変更意図

音声framework、録音状態、証拠buffer、contract変換を別責務にし、OSやassetが非対応でも
録音を継続できるようにするため。

## 設計上の意図

CaptureKitはFFIやSQLiteを知らず、CoreKitのlanguage-neutral DTOまでを生成する。暫定仮説は
表示専用とし、確定発話だけを永続化候補にする。失敗型には音声内容やpathを含めない。

## 影響範囲

iOS 26以降の録音chunk後処理と文字起こし表示。iOS 18-25の録音、Rust schema、SQLite
migration、CD、GitHub Variables/Secretsには変更なし。

## 追加・更新したテスト

- volatile/finalized分離、空文字・重複final拒否。
- chunk処理から確定発話が公開される正常系。
- 音声認識失敗時にもDaily captureを継続する異常系。
- timezone付きContextEvent変換とvolatile拒否。
- ContextEvent DTOのv1 JSON key形状。

## 実行した確認コマンド

- `swift test --package-path packages/ContextCoreKit --parallel`: 4件成功。
- `swift test --package-path packages/ContextCaptureKit --parallel`: 11件成功。
- `make swift-format-check swift-lint app-build`: format、lint違反0、iOS 18
  Simulator向けunsigned build成功。

## CIで確認される内容

Swift workflowがpackage typecheck/test/release buildを、Apple App workflowがXcode project
生成とunsigned app build/UI testを、Architecture workflowが依存方向を確認する。

## 未解決の課題

- 生成したContextEventをRust-owned SQLiteへ保存するcomposition接続が未実装。
- 実機でSpeech asset download、長時間処理、background復帰、複数localeを確認する必要がある。
- audio/transcript retentionの期限削除処理とdata protection levelが未実装。

## 次にやること

ContextCaptureKitにFFIを逆流させず、App compositionからContextCoreFFIKitの永続化adapterへ
finalized eventを渡す。実artifactを使うintegration testを追加する。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/CaptureCoordinator.swift`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/TranscriptEventMapper.swift`
- `packages/ContextCoreFFIKit/Sources/ContextCoreFFIKit/RustContextBridge.swift`

## 引き継ぎ事項

volatile speechを永続化しない。音声内容やfile pathをerror/logへ出さない。CaptureKitをFFI、
SQLite、Foundation Modelsへ依存させない。実機確認前にSpeech品質を確定扱いしない。
