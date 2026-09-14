# 作業報告書

## 作業日時

2026年09月14日 18時10分37秒 JST

## 作業対象

ContextCaptureKit、Dayline録音画面、iOS UI test、Apple App CI。

## 作業目的

iOS 18以降でApple Intelligenceの可否と独立して長時間録音を開始・停止でき、通話等の
割り込みでもOne Dayを終了しない最小capture機能を作る。

## 変更内容

- DailyとAudioを分離したcapture状態機械を追加した。
- AVAudioRecorderによるAAC-LC/mono/16 kHz/32 kbps録音を追加した。
- Application Support配下の日別保存と5分chunk rotationを追加した。
- AVAudioSession interruptionを状態機械へ接続し、再開時は新chunkにした。
- SwiftUIの開始/停止画面、失敗表示、accessibility identifierを追加した。
- `--ui-testing`時だけfake recorderを注入するcomposition rootを追加した。
- UI test target、`make app-test`、Apple App workflowの実行を追加した。
- App deployment targetをiOS 18へ戻した。

## 変更したファイル

- `packages/ContextCaptureKit/`
- `App/`、`AppUITests/`
- `project.yml`、`Makefile`、`.swiftlint.yml`
- `.github/workflows/ci-app.yml`
- `scripts/check-architecture.sh`
- `README.md`、`docs/architecture.md`、`docs/capture.md`、`docs/TODO.md`

## 変更意図

録音状態、AVFAudio、SwiftUI、テスト環境を分離し、モデルが利用できない端末でも収集を
継続する製品方針をコードとdeployment targetへ反映するため。

## 設計上の意図

- capture packageはUI、Foundation Models、FFI、CloudKitを知らない。
- platform adapterの失敗を有限な`CaptureFailure`へ変換し、pathや内部errorを表示しない。
- 割り込み後は壊れたcontainerへ追記せず新しいchunkを開始する。
- UI testはsystem permissionと実マイクから独立させる。

## 影響範囲

iPhone app、background audio entitlement相当のInfo設定、Swift package/CI graph。Rust、
contract、SQLite schema、Apple model runtime、release secretsには変更なし。

## 追加・更新したテスト

- Capture開始/停止、permission拒否、chunk rotation、割り込み中Daily継続、自動event接続。
- UIからfake録音を開始・停止し、表示状態が変化するXCUITest。

## 実行した確認コマンド

- `swift test --package-path packages/ContextCaptureKit --parallel`: 5件成功。
- `swift format lint --recursive --strict ...`: 成功。
- `swiftlint lint --strict --no-cache`: 違反0。
- `scripts/check-architecture.sh`: 成功。
- `xcodebuild build ... generic/platform=iOS Simulator`: iOS 18 targetで成功。
- `make app-test`: 実Simulatorで1件成功。

## CIで確認される内容

Swift workflowでContextCaptureKitのtypecheck/test/release buildを実行する。Apple App
workflowでproject生成、unsigned build、deterministic XCUITestを役割別に実行する。

## 未解決の課題

- SpeechAnalyzer/SpeechTranscriberとContextEvent変換は未実装。
- 実機で長時間、background、着信、Bluetooth、容量不足のPoCが必要。
- 音声ファイルのdata-protection levelとretention削除処理は次工程で追加する。

## 次にやること

Speech adapterをprotocol分離し、finalized segmentのbuffer/event変換をunit testする。
その後Daily/Live product profileと一覧画面へ進む。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/capture.md`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/CaptureCoordinator.swift`
- `packages/ContextCaptureKit/Sources/ContextCaptureKit/AVAudioRecorderAdapter.swift`

## 引き継ぎ事項

Audio interruptionでDailyをstoppedへしない。Raw audioをCloudKitへ同期しない。UI testの
fake分岐をproduction動作へ混ぜない。実機PoC前に録音品質を確定扱いしない。
