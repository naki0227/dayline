# 作業報告書

## 作業日時

2026年09月13日 23時48分03秒

## 作業対象

`SemanticArtifact`、`ContextBundle`、`ActionProposal`を含む4つのv1 core contract。

## 作業目的

Rust Context Engine、Swift adapter、model runtime、integration間のデータ境界を、
機能実装より先にlanguage-neutralなschemaとして固定する。

## 変更内容

- `SemanticArtifact`にsource Event参照と生成provenanceを必須化した。
- `ContextBundle`にtask、profile、time window、model-ready item、token budget、
  processing location、tool候補、除外理由、assembly provenanceを定義した。
- `ActionProposal`を未実行状態に限定し、tool引数schema、risk、permission、
  idempotency、proposerを定義した。
- destructive proposalの明示確認をJSON Schema条件として必須化した。
- 4 schemaそれぞれに正常・異常fixture検証を追加した。
- Contract分離、versioning、自己完結schemaの判断をADR 0003へ記録した。

## 変更したファイル

- `contracts/{semantic-artifact,context-bundle,action-proposal}.schema.json`
- `contracts/fixtures/{semantic-artifact,context-bundle,action-proposal}-v1.json`
- `contracts/fixtures/invalid/*-v1.json`
- `contracts/README.md`
- `Makefile`
- `docs/adr/0003-core-contracts-v1.md`
- `docs/TODO.md`

## 変更意図

観測事実、生成された意味、model入力、外部副作用の提案を別recordにし、AI生成結果を
観測事実や実行許可として扱う経路を型境界で防ぐ。

## 設計上の意図

Canonical Event／ArtifactはBundleへ複製せずIDで参照し、Bundleにはpolicy適用後の
model-ready contentだけを含める。ActionProposalは実行結果やcredentialを保持しない。
v1 schemaは単体配布できるよう自己完結させ、少量の共通定義重複は意図的に許容する。

## 影響範囲

Cross-language contractとfixtureのみ。既存Rust `ContextEvent`、Swift package、UI、DB、
App Store CDの公開APIや挙動は変更していない。

## 追加・更新したテスト

- 4つの正常fixtureが各schemaに適合すること。
- retention 0のContextEventを拒否すること。
- source Eventが空のSemanticArtifactを拒否すること。
- input token上限0のContextBundleを拒否すること。
- 明示確認のないdestructive ActionProposalを拒否すること。

## 実行した確認コマンド

- `make contracts-check`: 成功（4 metaschema、4正常、4期待失敗）。
- `make ci`: 権限付き再実行で成功。
- `make release-tools-ci`: 成功（Ruff、mypy、6 unit tests、compileall）。
- `git diff --check`: 成功。
- 秘密情報pattern scan: 値の検出なし。GitHub Secret参照名のみ検出。

最初の`make ci`はSwiftPMの入れ子sandbox作成が実行環境に拒否されたため停止した。
同一コマンドを権限付きで再実行し、Swift typecheck／test／release buildとiOS unsigned
buildまで成功を確認した。

## CIで確認される内容

- Contracts: Draft 2020-12 metaschema、正常fixture、異常fixture。
- Rust: format、Clippy、typecheck、unit test、release build。
- Swift／Apple App: format、lint、typecheck、unit test、release build、unsigned app build。
- Architecture／Quality: 依存方向をblocking、重複検出をwarningとして確認。
- Security: Gitleaks、Rust `cargo audit`、Python `pip-audit`。

## 未解決の課題

- sensitivity継承、時刻順序、token budget算術、Bundle内record ID一意性はRust invariant
  が未実装。
- SchemaからRust／Swift bindingsを再現可能に生成する方式は未決定。
- Tool Registry固有のargument schemaと実行policyは未実装。

## 次にやること

Rust `SemanticArtifact` modelを追加し、source Event 1件以上、重複ID拒否、生成情報、
retention、空contentのinvariantとfixture serialization testを実装する。

## 次回最初に見るべきファイル

- `contracts/semantic-artifact.schema.json`
- `contracts/fixtures/semantic-artifact-v1.json`
- `rust/crates/context-domain/src/event.rs`
- `rust/crates/context-domain/src/identifiers.rs`
- `docs/adr/0003-core-contracts-v1.md`

## 引き継ぎ事項

- 次回最初のコマンドは`make ci`と`make contracts-check`。
- EventとArtifactを同一record型へ統合しない。
- ActionProposalからintegrationを直接実行しない。
- JSON Schemaで表現できない相関制約はvalidated Rust constructorへ置く。
- Apple Intelligence availabilityはSwift adapter内へ隔離し、deployment targetは維持する。
