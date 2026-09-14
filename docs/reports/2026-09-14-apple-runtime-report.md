# 作業報告書

## 作業日時

2026年09月14日 17時40分43秒 JST

## 作業対象

Rust ContextBundle縮小境界、UniFFI、ContextCoreFFIKit、AppleIntelligenceKit。

## 作業目的

モデル固有token semanticsをRustへ漏らさず、Foundation Modelsのavailability、
実token計測、構造化出力、縮小retry、content-safe errorを完成させる。

## 変更内容

- Rustに順位順を維持する決定的`ContextBundle::shrink_to`を追加した。
- UniFFIとSwift bridgeへ縮小APIを公開した。
- iOS/macOS 26 availabilityと利用不可理由を型へ変換した。
- 26.4+でinstructions、prompt、schemaを実token計測する処理を追加した。
- 超過時に安全係数付きbudgetでRust reducerを呼ぶbounded retryを追加した。
- 26.0〜26.3向けにcontext-window error起点の75%縮小fallbackを追加した。
- `@Generable`構造化結果をversioned SemanticArtifactへ変換した。
- Issue #1へ検証根拠を記録し、completedとして閉じた。

## 変更したファイル

- `rust/crates/context-domain/src/bundle.rs`とテスト
- `rust/crates/context-ffi/src/lib.rs`とテスト
- `packages/ContextCoreFFIKit/`のbridgeとテスト
- `packages/AppleIntelligenceKit/Sources/AppleIntelligenceKit/`
- `packages/AppleIntelligenceKit/Tests/AppleIntelligenceKitTests/`
- `README.md`、`docs/architecture.md`、`docs/apple-intelligence.md`、`docs/TODO.md`

## 変更意図

実token数を把握できるApple層だけがcontext fitを判断し、再利用可能なRust Coreには
抽象budgetと決定的な縮小だけを持たせるため。

## 設計上の意図

- Foundation Models availabilityを低いdeployment targetから完全に隔離する。
- reducerを注入し、AppleIntelligenceKitからFFI implementationへ依存しない。
- retry回数を制限し、空bundleや縮小不能時はfail closedにする。
- model errorのdebug descriptionや入力内容を外へ出さない。

## 影響範囲

ContextBundleの非破壊縮小API、Rust/Swift FFI、Apple runtime。既存v1 JSON contract、
収集、SQLite schema、CD、外部integrationには変更なし。

## 追加・更新したテスト

- Rustの縮小順序、omission、zero budget。
- Rust FFIと実XCFramework越しの縮小。
- 実測比率、安全係数、旧OS fallback、prompt citation/language、reducer委譲。
- 既存stub provenance/sensitivityテストを共通factoryへ移行後も維持。

## 実行した確認コマンド

- `cargo test --manifest-path rust/Cargo.toml -p context-domain -p context-ffi`: 成功。
- `scripts/build-context-xcframework.sh`: 全Apple slice生成成功。
- `swift test --package-path packages/ContextCoreFFIKit --parallel`: 4件成功。
- `swift test --package-path packages/AppleIntelligenceKit --parallel`: 7件成功。
- `swift build --package-path packages/AppleIntelligenceKit -c release`: 成功。
- `swift format lint --recursive --strict ...`: 成功。
- `swiftlint lint --strict --no-cache`: 違反0。
- `scripts/check-architecture.sh`、`git diff --check`: 成功。
- `make app-build`: iOS Simulator向けbuild成功。

## CIで確認される内容

Rust、Swift、FFI、Apple App、Contracts、Architecture、Release Tools、Securityを
責務別workflowで確認する。重複検出はQuality workflowでwarn-onlyを維持する。

## 未解決の課題

- Foundation Models実生成は対応実機と有効なApple IntelligenceでPoCが必要。
- Dayline appのcomposition rootから実Rust reducerを注入する作業が未着手。
- iPhone audio、Speech、Daily/Live UI、外部連携、macOS collector、CloudKitは未実装。

## 次にやること

capture状態機械をpure Swiftで定義し、deterministic fakeでunit testした後、AVFAudioと
Speech adapterを追加する。並行してiOS targetへUI test harnessを入れる。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/apple-intelligence.md`
- `packages/AppleIntelligenceKit/Sources/AppleIntelligenceKit/AppleFoundationModelRuntime.swift`
- `packages/ContextCoreFFIKit/Sources/ContextCoreFFIKit/RustContextBridge.swift`

## 引き継ぎ事項

RustへApple tokenizerの値や上限を保存しない。Foundation Modelsが利用不可でもcapture、
保存、同期は継続する。実model入力やエラー詳細をログへ出さない。App Store登録は保留。
