# 作業報告書

## 作業日時

2026年09月13日 23時31分47秒

## 作業対象

`ContextEvent` v1 JSON contract、Rust `context-domain` model、contract CI。

## 作業目的

収集Source、Context Engine、Swift FFIが共有する最初の観測Event規格を確定し、
不正な識別子・空データ・保持期間をdomain境界で拒否する。

## 変更内容

- `ContextEvent`、`EventId`、`SessionId`、`DayId`を追加した。
- Source、Kind、Payload、Sensitivity、Retention、Provenanceを型で表現した。
- UUID、timezone、payload、provenance、retentionの不変条件を追加した。
- RFC 3339日時とschema version 1のJSON表現を固定した。
- v1 JSON Schemaとshell command fixtureを追加した。
- Rust出力とfixtureの完全一致テストを追加した。
- JSON Schema metaschema／fixture検証を独立CIに追加した。

## 変更したファイル

- `rust/Cargo.toml`、`rust/Cargo.lock`
- `rust/crates/context-domain/Cargo.toml`
- `rust/crates/context-domain/src/{lib,error,identifiers,event}.rs`
- `contracts/context-event.schema.json`
- `contracts/fixtures/context-event-v1.json`
- `contracts/requirements.txt`、`contracts/README.md`
- `.github/workflows/ci-contracts.yml`
- `.github/workflows/security.yml`
- `.gitignore`、`Makefile`、`docs/TODO.md`

## 変更意図

自由形式JSONを各Sourceから直接保存すると検証とFFI互換性が崩れるため、観測データを
version付き共通型へ正規化する。時刻・日付・UUID表現もcontractで固定する。

## 設計上の意図

domainはserde、time、uuidなどplatform-neutralな依存だけを持つ。DB、HTTP、UniFFI、
Apple frameworkには依存しない。Eventは観測事実だけを表し、AI生成Artifactは含めない。

## 影響範囲

Rust domainとcross-language contract。既存Swift API、DB、UI、App Store CDには影響しない。

## 追加・更新したテスト

- 不正Event UUID拒否
- 空timezone拒否
- 空shell command拒否
- 0日retention拒否
- ContextEvent v1 fixtureとのJSON完全一致
- JSON Schema metaschema検証
- fixtureのJSON Schema適合性検証

## 実行した確認コマンド

- `make rust-format rust-lint rust-check rust-test rust-build`: 成功、5 tests
- `make contracts-venv contracts-check`: 成功
- `make architecture`: 成功
- `make release-tools-ci`: 成功、6 tests
- `git diff --check`: 成功
- GitHub RustSec監査で`time 0.3.45`のRUSTSEC-2026-0009を検出し、
  `time 0.3.55`とRust MSRV 1.88へ更新後に再検証した。
- GitHub Actions（Rust、Swift、Apple App、Contracts、Architecture、Quality、
  Release Tools、Security）: 全て成功。

## CIで確認される内容

- Rust workflowがformat、Clippy、typecheck、unit test、release buildを確認する。
- Contracts workflowがDraft 2020-12 metaschemaとfixture適合性を確認する。
- Architecture workflowがdomainのframework／DB／FFI依存を拒否する。
- Security workflowがRust依存とcontract validator依存を監査する。
- Rust依存監査はprebuilt `cargo-audit`を導入し、監査のための長時間compileを避ける。

## 未解決の課題

- JSON SchemaからRust／Swift型を自動生成する方式は未決定。
- SourceとKind／Payloadの組み合わせ整合性は正規化層の設計と合わせて追加する。
- IANA timezone文字列の実在性検証は未実装。
- SemanticArtifact、ContextBundle、ActionProposal contractは未実装。

## 次にやること

`SemanticArtifact` v1を追加し、必ず1件以上のsource eventを参照する不変条件と、
生成モデル情報・prompt versionのprovenanceを設計する。

## 次回最初に見るべきファイル

- `rust/crates/context-domain/src/event.rs`
- `rust/crates/context-domain/src/identifiers.rs`
- `contracts/context-event.schema.json`
- `contracts/fixtures/context-event-v1.json`
- `docs/architecture.md`

## 引き継ぎ事項

- 次回最初のコマンドは`make ci`と`make contracts-check`。
- Eventに要約・決定・TodoなどAI生成結果を追加しない。
- schemaの破壊的変更はversion 1を直接書き換えずmigration方針を先に決める。
- `session_id`はoptionalだが`day_id`は必須のまま保つ。
- raw Terminal stdout／stderrやkey inputをPayloadへ追加しない。
