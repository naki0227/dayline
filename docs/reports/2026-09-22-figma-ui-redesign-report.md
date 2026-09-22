# 作業報告書

## 作業日時

2026年09月22日 11時44分51秒 JST

## 作業対象

Issue #22、iOS App、AppleIntelligenceKit、Live Meeting診断、権限・利用条件UI。

## 作業目的

Figma MakeのDayline案を実データへ接続したSwiftUIとして再現し、ユーザーが現在の
録音・文字起こし・AI利用状態と、利用できない理由を判断できるようにする。

## 変更内容

- Today / Timeline / Meetings / Settingsの4タブへ再構成した。
- Navy `#0F1E3D` とSky `#4A9FD4` のApp層デザイントークンを追加した。
- Daily録音状態、文字起こし、要約をFigma案の情報階層へ接続した。
- Live文字起こしとApple Intelligence整理を別能力として表示した。
- 汎用的な端末非対応表示を、有限な`TranscriptionFailure`別の案内へ変更した。
- マイク、音声認識、Apple Intelligence、通知、Calendar、background audioの
  状態確認・初回許可・iOS設定導線を追加した。
- OS権限、外部接続、Context Source allowlistを別画面・別状態のまま維持した。
- Notion接続状態をSettings配下のIntegrationsへ表示し、未実装連携を準備中と明記した。

## 変更したファイル

- `App/RootView.swift`、`App/TodayView.swift`、`App/TimelineView.swift`
- `App/LiveMeetingView.swift`、`App/SettingsView.swift`
- `App/CapabilitiesView.swift`、`App/AppCapabilityModel.swift`
- `App/ContextSourcesSettingsView.swift`、`App/IntegrationsView.swift`
- `App/DaylineTheme.swift`、`App/DailySummaryCard.swift`
- `App/Info.plist`、`project.yml`、`AppUITests/DaylineCaptureUITests.swift`
- `packages/AppleIntelligenceKit/Sources/AppleIntelligenceKit/SystemIntelligenceAvailability.swift`
- `packages/AppleIntelligenceKit/Tests/AppleIntelligenceKitTests/IntelligenceRuntimeTests.swift`
- `docs/capture.md`、`docs/architecture.md`、`docs/TODO.md`

## 変更意図

Figma内のダミーデータを製品へコピーせず、既存のObservation modelと責務境界を
表示へ接続した。iOS 26というだけではApple Intelligenceの端末適格性、設定、モデル
準備状態を保証しないため、利用可否を一つの包括エラーへ潰さない。

## 設計上の意図

Theme、platform permission inspection、SwiftUI navigationはApp層に限定した。
Apple model availabilityはAppleIntelligenceKitが型付きread-only queryとして所有する。
CaptureKitの失敗型、ProductKitの状態、Rust Context EngineにはUI都合を追加していない。

## 影響範囲

iOSの情報設計、権限要求、Live Meetingエラー表示、XCUITest導線。Contract、Rust schema、
SQLite、Notion write policy、OAuth broker、CD署名処理には変更なし。

## 追加・更新したテスト

- system model availability queryとruntimeの一致を確認するunit testを追加した。
- 既存6本のXCUITestを新しいタブ・Settings導線とscroll構造へ更新した。

## 実行した確認コマンド

- `swift-format format/lint`（Xcode toolchain直接指定）: 成功。
- `swiftc -frontend -parse ...`: 成功。
- `git diff --check`: 成功。
- `xcodegen generate`: 成功。
- ローカルのSwift package/app buildはXcode license未承認によりcompiler起動前に停止。
- GitHub `CI / Swift`: format、lint、typecheck、unit test、release build成功。
- GitHub `CI / Apple App`: 実FFI linkとapp build成功。初回XCUITestは7本中5本成功し、
  再設計前の文言を期待していた2本を新仕様へ更新して再実行する。

## CIで確認される内容

Contracts、Rust、Swift、Rust-Swift FFI、Apple App、Integrations、OAuth broker、Release tools、
Architecture、cross-cutting duplication warning、Security。

## 未解決の課題

- 実iOS 26端末でLive Meetingを再実行し、表示される正確な失敗理由を確認する。
- Timelineの永続event query、onboarding、Google Calendar、Mac Companionは別Issueの実装。
- TestFlight配布は本作業のCI成功後に別途行う。

## 次にやること

1. 全責務CI完了を確認する。
2. 必要ならCIログに基づく修正を行う。
3. Issue #22へ実装範囲と未実装範囲を記録する。
4. TestFlight配布後、iOS 26実機で権限センターとLive Meetingを確認する。

## 次回最初に見るべきファイル

- `App/LiveMeetingView.swift`
- `App/AppCapabilityModel.swift`
- `App/RootView.swift`
- `docs/TODO.md`

## 引き継ぎ事項

Figma zipは参照資料でありReact成果物を製品依存へ追加していない。Apple Intelligenceの
利用不可とSpeechAnalyzerの利用不可を再び同じ表示へ統合しない。権限を許可しただけで
Context Sourceを自動的にONにしない。ローカルXcode検証にはlicense承認が必要。
