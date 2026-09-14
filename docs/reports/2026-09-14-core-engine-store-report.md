# 作業報告書

## 作業日時

2026年09月14日 10時05分43秒 JST

## 作業対象

Core contract整合性、Rust domain/engine/policy、One Day境界、ローカルSQLite
永続化、Issue #1の設計指摘。

## 作業目的

Swift/Apple Intelligence接続前に、観測・生成物・モデル入力・外部操作提案を
安全に扱うRust基盤と保存境界を完成させる。Issue #1の5項目を契約とコードへ反映し、
App Store登録より先に垂直スライスへ進める状態にする。

## 変更内容

- 4つのv1 contractに対応するvalidated domain modelを実装した。
- JSON deserializeでもconstructor invariantを迂回できないようにした。
- Event kind/payloadの組、Artifact由来Artifact、EventのみのActionProposalを契約化した。
- ContextBundleのRust予算をモデルtokenから抽象estimate unitへ変更した。
- secret redaction、filter、ranking、deduplication、policy、bundle assemblyを実装した。
- IANA timezoneからOne Dayを導出・照合する`context-time`を追加した。
- 保存前redaction、immutable ID、evidence FK、cycle検査を持つ`context-store`を追加した。
- SQLite migrationとデータ削除を伴う明示的rollbackを追加した。
- App Store登録を垂直スライス完了後まで保留へ移した。

## 変更したファイル

- `contracts/*.schema.json`と`contracts/fixtures/`
- `rust/crates/context-domain/`
- `rust/crates/context-normalize/`
- `rust/crates/context-redact/`
- `rust/crates/context-query/`
- `rust/crates/context-ranking/`
- `rust/crates/context-policy/`
- `rust/crates/context-engine/`
- `rust/crates/context-time/`
- `rust/crates/context-store/`
- `rust/Cargo.toml`、`rust/Cargo.lock`
- `README.md`、`contracts/README.md`、`docs/architecture.md`
- `docs/adr/0003-core-contracts-v1.md`
- `docs/adr/0004-local-store-and-day-boundaries.md`
- `docs/storage.md`、`docs/TODO.md`

## 変更意図

Rustを「必要なContextを安全かつ決定的に組み立てる」責務で止め、Apple modelの
availability、実token計測、prompt、structured outputはSwiftへ残すため。保存時点で
秘密と不正なprovenanceを拒否し、読み出し時の後付け対策に依存しないため。

## 設計上の意図

- raw observationとgenerated meaningは別recordのまま維持する。
- `context-domain`はSQLite、FFI、Apple frameworkを知らない。
- `context-time`はcalendar day解決、`context-redact`は秘密除去、`context-store`は
  transactionと参照整合性に限定する。
- duplicate IDは暗黙上書きせずtyped errorにする。
- Artifact provenanceはEvent/Artifactの双方を許可するが循環を許可しない。
- 外部writeはActionProposalと決定的policyを通し、AI出力から直接実行しない。

## 影響範囲

Rust/Swift境界に渡すv1 JSONとRust workspace。Swift marker API、Dayline UI、CDの
実行契約は未変更。`ContextBundle` consumerは旧token fieldではなく
`quarter_character_estimate` unitを読む必要がある。

## 追加・更新したテスト

- 各domain modelの正常系、invalid decode、重複、空値、範囲、時刻順序。
- Event kind/payload、Artifact provenance、ActionProposal evidenceの境界条件。
- redaction pattern、query half-open window、ranking bounds、policy allow/ask/deny。
- bundleのredaction、deduplication、budget omission、unit合計。
- Tokyo/New Yorkの日付差、未知timezone、false local day。
- SQLite保存前redaction、duplicate、missing evidence、day不一致、migration再実行、
  provenance cycle、day query。

## 実行した確認コマンド

- `make contracts-check`: 成功。
- `cargo fmt --all`: 成功。
- `cargo clippy --workspace --all-targets -- -D warnings`: 成功。
- `cargo test --workspace`: 全テスト成功。
- `cargo build --workspace --release`: 成功。
- `cargo audit --file rust/Cargo.lock --no-fetch`: 既存1243 advisoryで脆弱性なし。
- `git diff --check`: 成功。

## CIで確認される内容

Contracts schema/fixtures、Rust format/clippy/check/test/release build、Swift
format/lint/check/test/build、iOS unsigned build、architecture dependency rules、release CLI、
Gitleaks、Rust/Python dependency audit。重複検査はwarn-only。

## 未解決の課題

- Rust/Swift FFI方式と再現可能なXCFramework生成が未実装。
- Apple runtimeのavailability、実token計測、shrink retry、structured outputが未実装。
- iPhone capture、speech、Daily/Live UI、integration、Live Activity、macOS collector、
  CloudKit同期は未実装。
- Apple Developer/App Store登録と配布Secretsは垂直スライス後まで保留。
- bundled SQLite/IANA timezoneのApple binary sizeを未計測。

## 次にやること

UniFFIを第一候補としてADRを作り、fixture EventからRust ContextBundleを構築して
Swift stub runtimeへ渡し、SemanticArtifactをSQLiteへ戻す最小垂直スライスを作る。

## 次回最初に見るべきファイル

- `docs/TODO.md`
- `docs/adr/0001-context-platform-boundaries.md`
- `docs/adr/0004-local-store-and-day-boundaries.md`
- `rust/crates/context-engine/src/lib.rs`
- `rust/crates/context-store/src/lib.rs`
- `packages/ContextCoreKit/Package.swift`
- `packages/AppleIntelligenceKit/Package.swift`

## 引き継ぎ事項

最初にIssue #1と`make ci`の結果を確認する。RustにApple model tokenやFoundation
Models型を入れない。SQLiteファイルをiCloud同期しない。Storeは同期APIなのでSwiftの
MainActorから直接呼ばない。App Store登録作業とUI拡張は垂直スライスより先に戻さない。
