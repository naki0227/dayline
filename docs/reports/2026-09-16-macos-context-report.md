# 作業報告書

## 作業日時

2026年09月16日 14時23分34秒 JST

## 作業対象

ContextCoreKit、ContextCoreFFIKit、MacContextKit、MacContextAgent、Issue #11のmacOS context。

## 作業目的

TerminalとChromeの選択済みmetadataを、既定OFF・local-only・content-safeな経路でv1
ContextEventへ変換し、Rust-owned SQLiteへ保存できるようにする。

## 変更内容

- typed `ShellCommandContextEventDocument` / `BrowserVisitContextEventDocument`を追加した。
- Coreにraw versioned event data persistence port、FFIKitにRust実装を追加した。
- MacContextKitに既定OFF policy、event factory、collector、Chrome SQLite readerを追加した。
- Chromeを`visits JOIN urls`でread-only取得し、timestamp + visit ID cursorを実装した。
- headless CLI、stdin-only zsh hook、configure/status/collect commandsを追加した。
- Integration/FFI workflowとMakefileへmacOS collector検証を追加した。

## 変更したファイル

- `packages/ContextCoreKit/Sources/ContextCoreKit/*ContextEventDocument.swift`
- `packages/ContextCoreKit/Sources/ContextCoreKit/ContextEventPersisting.swift`
- `packages/ContextCoreFFIKit/Sources/ContextCoreFFIKit/RustContextStore.swift`
- `packages/*/Tests/`のmac event/FFIテスト
- `integrations/MacContextKit/`
- `apps/MacContextAgent/`
- `scripts/dayline-zsh-hook.zsh`
- `Makefile`、`.swiftlint.yml`、`.github/workflows/ci-*.yml`
- `README.md`、`docs/architecture.md`、`docs/privacy.md`、`docs/mac-context.md`
- `docs/adr/0006-macos-context-collection.md`、`docs/TODO.md`

## 変更意図

Accessibility監視やraw shell outputを避け、完了した最小metadataのみを明示的なローカルhookと
read-only browser DBから取得するため。

## 設計上の意図

MacContextKitはsource adapterとtyped mapping、Agentはplatform composition、Coreは契約、Rustは
validation/redaction/persistenceを所有する。無効時はsourceを読む前に終了する。CLIの引数・出力・
エラーへ収集内容を含めない。Chrome cursorは成功後だけ進め、同時刻visitを欠落させない。

## 影響範囲

macOS local collector、Swift contract DTO、FFI store port、CI。iOS capture、Notion、schema version、
DB migration、CD signing設定には変更なし。

## 追加・更新したテスト

- source既定OFFと無効時no-persist。
- shell/browser strict payload mappingとstdout/stderr不存在。
- Chrome cursor以後だけを取得するSQLite fixture。
- shell commandがRust永続化前にsecret redactionされるFFI integration。

## 実行した確認コマンド

- Xcode toolchain `swift-format`: 成功。
- `git diff --check`: 成功。
- `scripts/check-architecture.sh`: 成功。
- `zsh -n scripts/dayline-zsh-hook.zsh`: 成功。
- Command Line Tools `swift build --package-path integrations/MacContextKit -c release`: 成功。
- Command Line Tools `swift build --package-path apps/MacContextAgent -c release`: 成功。
- 隔離directoryでshell synthetic eventをCLI -> Rust SQLiteへ保存: 成功。
- synthetic Chrome HistoryをCLI -> Rust SQLiteへ保存: 成功。
- 同一Chrome cursor再実行: `persisted=0`、重複なし。
- browser無効 + missing History path: `persisted=0`、source openなし。
- synthetic `TOKEN=fixture-value` shell commandはSQLite上で`TOKEN=***`を確認。

## CIで確認される内容

Integrations workflowがMacContextKit format/typecheck/unit test/release buildを独立jobで確認する。
FFI workflowがXCFramework生成、FFI tests、MacContextAgent linkを確認する。全体`make ci`にも
Mac agent buildを追加した。重複検知は引き続きwarning-only。

## 未解決の課題

- ローカルXcode 26.5更新後のlicenseが未同意のため、Xcode依存のunit/UI/full CIはこの時点では
  再実行できていない。production sourceはCommand Line Toolsでbuild済み、最終判定はGitHub CI。
- 実ユーザーのChrome DBはプライバシー保護のため読み取っていない。
- signed macOS UI/LaunchAgent installerはPhase 1外。手動設定手順は`docs/mac-context.md`。

## 次にやること

push後の全workflowを確認し、Issue #11のacceptance checkboxを実装・テスト・runtime evidenceで監査する。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/mac-context.md`
- `docs/adr/0006-macos-context-collection.md`
- `integrations/MacContextKit/Sources/MacContextKit/`
- `apps/MacContextAgent/Sources/DaylineMacContext/main.swift`

## 引き継ぎ事項

次回最初のコマンドは`gh run list --branch main`。実Contextや実Chrome Historyをテストに使わない。
Terminal stdout/stderr/keystrokesを追加しない。mac sourceは既定OFFを維持し、Rust redactionを迂回しない。
